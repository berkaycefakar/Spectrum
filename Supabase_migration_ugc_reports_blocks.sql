-- Spectrum — user-generated content moderation (App Store Guideline 1.2)
--
-- Adds the two tables the app needs to satisfy Apple's UGC requirements:
--   content_reports — a user reporting offensive content, with a reason
--   user_blocks     — a user blocking another user
--
-- Run this in Supabase → SQL Editor. Safe to re-run: every statement is idempotent.

-- ---------------------------------------------------------------------------
-- 1. Reports
-- ---------------------------------------------------------------------------

create table if not exists public.content_reports (
    id           uuid primary key default gen_random_uuid(),
    reporter_id  uuid not null references auth.users (id) on delete cascade,
    -- Who wrote the reported thing. Nullable so a report survives the author deleting
    -- their account (we still want the moderation record).
    reported_user_id uuid references auth.users (id) on delete set null,
    -- 'song_review' | 'album_review' | 'artist_review' | 'profile'
    content_type text not null,
    -- The reported row's id, or the profile id for a profile report. Kept as text because
    -- the three review tables have their own id spaces.
    content_ref  text,
    -- 'offensive' | 'harassment' | 'spam' | 'sexual' | 'violence' | 'other'
    reason       text not null,
    details      text,
    -- Snapshot of the text as reported: the author can edit or delete the row afterwards,
    -- and then the report becomes unreviewable.
    reported_text text,
    -- 'pending' | 'reviewed' | 'dismissed'
    status       text not null default 'pending',
    created_at   timestamptz not null default now()
);

create index if not exists content_reports_status_idx
    on public.content_reports (status, created_at desc);
create index if not exists content_reports_reporter_idx
    on public.content_reports (reporter_id);

-- One report per user per piece of content: tapping Report twice shouldn't inflate the queue.
create unique index if not exists content_reports_unique_per_reporter
    on public.content_reports (reporter_id, content_type, coalesce(content_ref, ''));

alter table public.content_reports enable row level security;

-- A user may file a report as themselves, and read only their own. Nobody can update or
-- delete through the anon key — moderation happens in the dashboard with the service role.
drop policy if exists "reports: insert own" on public.content_reports;
create policy "reports: insert own"
    on public.content_reports for insert
    to authenticated
    with check (auth.uid() = reporter_id);

drop policy if exists "reports: read own" on public.content_reports;
create policy "reports: read own"
    on public.content_reports for select
    to authenticated
    using (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------------
-- 2. Blocks
-- ---------------------------------------------------------------------------

create table if not exists public.user_blocks (
    blocker_id uuid not null references auth.users (id) on delete cascade,
    blocked_id uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocker_idx on public.user_blocks (blocker_id);

alter table public.user_blocks enable row level security;

-- Each user owns their own block list, and can only ever see their own. Deliberately no read
-- access to rows where you are the *blocked* party: telling someone they've been blocked is
-- how a block turns back into harassment.
drop policy if exists "blocks: read own" on public.user_blocks;
create policy "blocks: read own"
    on public.user_blocks for select
    to authenticated
    using (auth.uid() = blocker_id);

drop policy if exists "blocks: insert own" on public.user_blocks;
create policy "blocks: insert own"
    on public.user_blocks for insert
    to authenticated
    with check (auth.uid() = blocker_id);

drop policy if exists "blocks: delete own" on public.user_blocks;
create policy "blocks: delete own"
    on public.user_blocks for delete
    to authenticated
    using (auth.uid() = blocker_id);

-- ---------------------------------------------------------------------------
-- 3. Blocking must break the follow graph both ways
-- ---------------------------------------------------------------------------
-- Doing this in a trigger rather than in the app: the app can crash or lose connectivity
-- between the two statements, and a block that leaves the follow intact isn't a block.

create or replace function public.unfollow_on_block()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.follows
     where (follower_id = new.blocker_id and following_id = new.blocked_id)
        or (follower_id = new.blocked_id and following_id = new.blocker_id);
    return new;
end;
$$;

drop trigger if exists user_blocks_unfollow on public.user_blocks;
create trigger user_blocks_unfollow
    after insert on public.user_blocks
    for each row execute function public.unfollow_on_block();

-- ---------------------------------------------------------------------------
-- 4. Verify
-- ---------------------------------------------------------------------------
-- Expect rowsecurity = true for both tables.
select tablename, rowsecurity
  from pg_tables
 where schemaname = 'public'
   and tablename in ('content_reports', 'user_blocks');
