-- Spectrum — user lists
--
-- The feature Letterboxd is actually known for. A rating is a private verdict; a list is
-- something a person makes on purpose and wants other people to see — "best albums of 2026",
-- "records for driving at night". It is the only thing in the app somebody has a reason to
-- link to from outside it.
--
-- Two tables. `lists` is the thing itself; `list_items` is its contents, ordered. Items are
-- polymorphic the same way `review_likes` is: songs and albums are keyed by their numeric
-- Apple id, artists by name (there is no artist id column anywhere in this schema), so
-- `content_ref` is text and carries no foreign key.
--
-- Run this in Supabase → SQL Editor. Safe to re-run: every statement is idempotent.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.lists (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    title       text not null,
    description text,
    -- Private by default. A list is a draft until its author decides otherwise, and the
    -- safe default for anything user-written is "nobody else can see it".
    is_public   boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

alter table public.lists
    drop constraint if exists lists_title_length;
alter table public.lists
    add constraint lists_title_length
    check (char_length(trim(title)) between 1 and 80);

alter table public.lists
    drop constraint if exists lists_description_length;
alter table public.lists
    add constraint lists_description_length
    check (description is null or char_length(description) <= 500);

create index if not exists lists_user_idx
    on public.lists (user_id, updated_at desc);
-- Browsing other people's lists only ever looks at public ones.
create index if not exists lists_public_idx
    on public.lists (is_public, updated_at desc)
    where is_public;

create table if not exists public.list_items (
    id           uuid primary key default gen_random_uuid(),
    list_id      uuid not null references public.lists (id) on delete cascade,
    -- 'song' | 'album' | 'artist'
    content_type text not null,
    -- Apple numeric id for songs and albums, the artist's name for artists.
    content_ref  text not null,
    -- Why it's on the list. This is the part that makes a list worth reading.
    note         text,
    -- Manual ordering. A list is curated: "my top ten" means nothing sorted by date.
    position     integer not null default 0,
    created_at   timestamptz not null default now()
);

alter table public.list_items
    drop constraint if exists list_items_type_valid;
alter table public.list_items
    add constraint list_items_type_valid
    check (content_type in ('song', 'album', 'artist'));

alter table public.list_items
    drop constraint if exists list_items_note_length;
alter table public.list_items
    add constraint list_items_note_length
    check (note is null or char_length(note) <= 300);

-- The same record twice in one list is a mistake, not an opinion.
create unique index if not exists list_items_unique_per_list
    on public.list_items (list_id, content_type, content_ref);

create index if not exists list_items_order_idx
    on public.list_items (list_id, position, created_at);

-- ---------------------------------------------------------------------------
-- 2. Row level security
-- ---------------------------------------------------------------------------

alter table public.lists enable row level security;
alter table public.list_items enable row level security;

-- A list is visible if it is public, or if you wrote it.
drop policy if exists "public lists are readable" on public.lists;
create policy "public lists are readable"
    on public.lists for select
    using (is_public or auth.uid() = user_id);

drop policy if exists "users create their own lists" on public.lists;
create policy "users create their own lists"
    on public.lists for insert
    with check (auth.uid() = user_id);

drop policy if exists "users edit their own lists" on public.lists;
create policy "users edit their own lists"
    on public.lists for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "users delete their own lists" on public.lists;
create policy "users delete their own lists"
    on public.lists for delete
    using (auth.uid() = user_id);

-- Items inherit their parent's visibility. Without the `exists` check an item row would be
-- readable on its own even when the list it belongs to is private — the client could walk
-- `list_items` directly and reconstruct somebody's unpublished list.
drop policy if exists "list items follow their list" on public.list_items;
create policy "list items follow their list"
    on public.list_items for select
    using (
        exists (
            select 1 from public.lists l
            where l.id = list_id
              and (l.is_public or l.user_id = auth.uid())
        )
    );

drop policy if exists "users add to their own lists" on public.list_items;
create policy "users add to their own lists"
    on public.list_items for insert
    with check (
        exists (select 1 from public.lists l where l.id = list_id and l.user_id = auth.uid())
    );

drop policy if exists "users edit items in their own lists" on public.list_items;
create policy "users edit items in their own lists"
    on public.list_items for update
    using (
        exists (select 1 from public.lists l where l.id = list_id and l.user_id = auth.uid())
    )
    with check (
        exists (select 1 from public.lists l where l.id = list_id and l.user_id = auth.uid())
    );

drop policy if exists "users remove items from their own lists" on public.list_items;
create policy "users remove items from their own lists"
    on public.list_items for delete
    using (
        exists (select 1 from public.lists l where l.id = list_id and l.user_id = auth.uid())
    );

-- ---------------------------------------------------------------------------
-- 3. Item counts
-- ---------------------------------------------------------------------------

-- Same reason as `review_like_counts`: PostgREST can't group, and a profile showing ten
-- lists would otherwise download every item of all ten just to print "12 records".
create or replace function public.list_item_counts(p_list_ids uuid[])
returns table (list_id uuid, item_count bigint)
language sql
stable
as $$
    select i.list_id, count(*)::bigint
    from public.list_items i
    where i.list_id = any (p_list_ids)
    group by i.list_id;
$$;

grant execute on function public.list_item_counts(uuid[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Keeping `updated_at` honest
-- ---------------------------------------------------------------------------

-- Lists are ordered by `updated_at` on the profile, and "recently updated" has to include
-- adding a record to it — not just renaming the list.
create or replace function public.touch_list_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.lists
    set updated_at = now()
    where id = coalesce(new.list_id, old.list_id);
    return coalesce(new, old);
end;
$$;

drop trigger if exists list_items_touch_list on public.list_items;
create trigger list_items_touch_list
    after insert or update or delete on public.list_items
    for each row execute function public.touch_list_updated_at();

-- ---------------------------------------------------------------------------
-- 5. Check it
-- ---------------------------------------------------------------------------
--
--   select policyname, cmd from pg_policies where tablename in ('lists', 'list_items');
--   select public.list_item_counts(array[]::uuid[]);
