-- Spectrum — likes on logs
--
-- Until now the feed was one-directional: you could see what somebody logged and follow
-- them, and that was the entire set of things you could do. A like is the cheapest possible
-- reply, and it is the signal the rest of the app can be built on later (most-liked logs,
-- notifications, a "liked" tab).
--
-- One table covers all three review kinds. `content_id` is a uuid because every review
-- table's primary key is one; `content_type` says which table it points at. There is no
-- foreign key for that reason — polymorphic references can't have one — so a deleted review
-- leaves its likes behind. They are harmless (nothing joins back to them) and the delete
-- paths below clean them up.
--
-- Run this in Supabase → SQL Editor. Safe to re-run: every statement is idempotent.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table if not exists public.review_likes (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users (id) on delete cascade,
    -- 'song_review' | 'album_review' | 'artist_review'
    content_type text not null,
    content_id   uuid not null,
    created_at   timestamptz not null default now()
);

-- The anon key ships inside the IPA, so anything the client sends has to be constrained
-- here rather than in Swift.
alter table public.review_likes
    drop constraint if exists review_likes_type_valid;
alter table public.review_likes
    add constraint review_likes_type_valid
    check (content_type in ('song_review', 'album_review', 'artist_review'));

-- One like per user per log. This is also what makes a double-tap idempotent: the second
-- insert fails with 23505 and the client reads that as "already liked" rather than an error.
create unique index if not exists review_likes_unique_per_user
    on public.review_likes (user_id, content_type, content_id);

-- Counting likes for a screenful of logs is the hot path.
create index if not exists review_likes_content_idx
    on public.review_likes (content_type, content_id);

-- ---------------------------------------------------------------------------
-- 2. Row level security
-- ---------------------------------------------------------------------------

alter table public.review_likes enable row level security;

-- Counts are public: everyone sees how many likes a log has, the same way they see the log.
drop policy if exists "review_likes are readable by everyone" on public.review_likes;
create policy "review_likes are readable by everyone"
    on public.review_likes for select
    using (true);

-- You can only like as yourself. Without this the client could forge likes from any user id.
drop policy if exists "users like as themselves" on public.review_likes;
create policy "users like as themselves"
    on public.review_likes for insert
    with check (auth.uid() = user_id);

-- Unliking is deleting your own row, and only your own.
drop policy if exists "users remove their own likes" on public.review_likes;
create policy "users remove their own likes"
    on public.review_likes for delete
    using (auth.uid() = user_id);

-- Deliberately no UPDATE policy: a like has nothing to change.

-- ---------------------------------------------------------------------------
-- 3. Counting
-- ---------------------------------------------------------------------------

-- PostgREST can't express "group by content_id" over a filtered set, and fetching every
-- like row for a page of logs would mean downloading one row per like — fine for ten, not
-- for a log that does well. This returns one row per id instead.
--
-- `stable` so the planner can cache it within a statement; `security invoker` (the default)
-- so the SELECT policy above still applies.
create or replace function public.review_like_counts(
    p_content_type text,
    p_content_ids  uuid[]
)
returns table (content_id uuid, like_count bigint)
language sql
stable
as $$
    select l.content_id, count(*)::bigint
    from public.review_likes l
    where l.content_type = p_content_type
      and l.content_id = any (p_content_ids)
    group by l.content_id;
$$;

grant execute on function public.review_like_counts(text, uuid[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Cleaning up after a deleted log
-- ---------------------------------------------------------------------------

-- Polymorphic `content_id` can't be a foreign key, so deleting a review would otherwise
-- leave its likes orphaned forever. One trigger function, three triggers.
create or replace function public.delete_orphaned_review_likes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.review_likes
    where content_type = tg_argv[0]
      and content_id = old.id;
    return old;
end;
$$;

drop trigger if exists reviews_delete_likes on public.reviews;
create trigger reviews_delete_likes
    after delete on public.reviews
    for each row execute function public.delete_orphaned_review_likes('song_review');

drop trigger if exists album_reviews_delete_likes on public.album_reviews;
create trigger album_reviews_delete_likes
    after delete on public.album_reviews
    for each row execute function public.delete_orphaned_review_likes('album_review');

drop trigger if exists artist_reviews_delete_likes on public.artist_reviews;
create trigger artist_reviews_delete_likes
    after delete on public.artist_reviews
    for each row execute function public.delete_orphaned_review_likes('artist_review');

-- ---------------------------------------------------------------------------
-- 5. Check it
-- ---------------------------------------------------------------------------
--
--   select policyname, cmd from pg_policies where tablename = 'review_likes';
--   select public.review_like_counts('song_review', array[]::uuid[]);
