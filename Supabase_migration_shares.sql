-- Spectrum — send a song or album to a friend, with a short note
--
-- Not a chat: one record plus an optional line of text, between two people who follow each
-- other. That keeps spam and harassment surface small (no strangers, no threads) while still
-- giving the app a reason to open when a friend sends something.
--
-- Rules, all enforced here because the anon key ships in the IPA:
--   * only between mutual followers, and never across a block in either direction
--   * the note is optional, at most 140 characters
--   * at most 30 shares per sender per 24 hours
--   * sender and recipient can read a share; only the recipient can mark it seen; either
--     can delete it from their side (deleting removes the row for both, which is fine for
--     something this small)
--
-- Run in Supabase → SQL Editor. Safe to re-run.

create table if not exists public.shares (
    id           uuid primary key default gen_random_uuid(),
    sender_id    uuid not null references auth.users (id) on delete cascade,
    recipient_id uuid not null references auth.users (id) on delete cascade,
    -- 'song' | 'album'
    kind         text not null,
    -- Apple catalog id, digits only.
    content_ref  text not null,
    note         text,
    created_at   timestamptz not null default now(),
    seen_at      timestamptz
);

alter table public.shares drop constraint if exists shares_kind_valid;
alter table public.shares add constraint shares_kind_valid check (kind in ('song', 'album'));

alter table public.shares drop constraint if exists shares_ref_shape;
alter table public.shares add constraint shares_ref_shape check (content_ref ~ '^[0-9]{1,20}$');

alter table public.shares drop constraint if exists shares_note_length;
alter table public.shares add constraint shares_note_length
    check (note is null or char_length(note) <= 140);

alter table public.shares drop constraint if exists shares_no_self;
alter table public.shares add constraint shares_no_self check (sender_id <> recipient_id);

create index if not exists shares_recipient_idx on public.shares (recipient_id, created_at desc);
create index if not exists shares_sender_idx on public.shares (sender_id, created_at desc);

-- Mutual follow and no block either way. SECURITY DEFINER because the block table only lets
-- you see your own blocks, and the insert check needs to know whether the recipient blocked
-- the sender without ever telling the sender so (the insert just fails).
create or replace function public.can_share_with(p_recipient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select auth.uid() is not null
       and auth.uid() <> p_recipient
       and exists (select 1 from follows where follower_id = auth.uid() and following_id = p_recipient)
       and exists (select 1 from follows where follower_id = p_recipient and following_id = auth.uid())
       and not exists (
           select 1 from user_blocks
           where (blocker_id = auth.uid() and blocked_id = p_recipient)
              or (blocker_id = p_recipient and blocked_id = auth.uid())
       );
$$;

revoke all on function public.can_share_with(uuid) from public;
grant execute on function public.can_share_with(uuid) to authenticated;

-- 30 a day per sender.
create or replace function public.shares_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if (select count(*) from shares
        where sender_id = new.sender_id and created_at > now() - interval '24 hours') >= 30 then
        raise exception 'share limit reached' using errcode = 'P0001';
    end if;
    return new;
end;
$$;

drop trigger if exists shares_rate_limit on public.shares;
create trigger shares_rate_limit before insert on public.shares
    for each row execute function public.shares_rate_limit();

alter table public.shares enable row level security;

drop policy if exists "shares: parties read" on public.shares;
create policy "shares: parties read"
    on public.shares for select
    to authenticated
    using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists "shares: send to friends" on public.shares;
create policy "shares: send to friends"
    on public.shares for insert
    to authenticated
    with check (auth.uid() = sender_id and seen_at is null and public.can_share_with(recipient_id));

drop policy if exists "shares: recipient marks seen" on public.shares;
create policy "shares: recipient marks seen"
    on public.shares for update
    to authenticated
    using (auth.uid() = recipient_id)
    with check (auth.uid() = recipient_id);

drop policy if exists "shares: parties delete" on public.shares;
create policy "shares: parties delete"
    on public.shares for delete
    to authenticated
    using (auth.uid() = sender_id or auth.uid() = recipient_id);

-- The recipient may only touch seen_at; everything else stays as sent.
revoke update on public.shares from anon, authenticated;
grant update (seen_at) on public.shares to authenticated;
revoke all on public.shares from anon;

-- Shares can be reported like comments.
alter table public.content_reports drop constraint if exists content_reports_type_valid;
alter table public.content_reports add constraint content_reports_type_valid
    check (content_type in ('song_review', 'album_review', 'artist_review', 'profile', 'comment', 'share'));
