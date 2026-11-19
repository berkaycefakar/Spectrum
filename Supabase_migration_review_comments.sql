-- Spectrum — comments on logs
--
-- A like was the only reply a log could get. This adds short written replies under a log.
-- Same polymorphic shape as `review_likes` (content_type + content_id, no foreign key);
-- only song logs show comments in the app for now, but the check admits all three kinds so
-- album and artist logs can follow without another migration.
--
-- Moderation follows the rest of the UGC rules: comments can be reported (content_type
-- 'comment'), blocked users' comments are filtered out on read, the client masks profanity,
-- and the person whose log it is can delete any comment under it.
--
-- Run in Supabase → SQL Editor. Safe to re-run.

create table if not exists public.review_comments (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users (id) on delete cascade,
    content_type text not null,
    content_id   uuid not null,
    body         text not null,
    created_at   timestamptz not null default now()
);

alter table public.review_comments drop constraint if exists review_comments_type_valid;
alter table public.review_comments add constraint review_comments_type_valid
    check (content_type in ('song_review', 'album_review', 'artist_review'));

alter table public.review_comments drop constraint if exists review_comments_body_length;
alter table public.review_comments add constraint review_comments_body_length
    check (char_length(btrim(body)) between 1 and 500);

create index if not exists review_comments_content_idx
    on public.review_comments (content_type, content_id, created_at);

alter table public.review_comments enable row level security;

drop policy if exists "review_comments are readable by everyone" on public.review_comments;
create policy "review_comments are readable by everyone"
    on public.review_comments for select
    using (true);

drop policy if exists "users comment as themselves" on public.review_comments;
create policy "users comment as themselves"
    on public.review_comments for insert
    with check (auth.uid() = user_id);

-- Your own comment, or any comment on your own log.
drop policy if exists "authors and log owners delete comments" on public.review_comments;
create policy "authors and log owners delete comments"
    on public.review_comments for delete
    using (
        auth.uid() = user_id
        or (content_type = 'song_review' and exists (
            select 1 from public.reviews r where r.id = content_id and r.user_id = auth.uid()))
        or (content_type = 'album_review' and exists (
            select 1 from public.album_reviews r where r.id = content_id and r.user_id = auth.uid()))
        or (content_type = 'artist_review' and exists (
            select 1 from public.artist_reviews r where r.id = content_id and r.user_id = auth.uid()))
    );

-- No UPDATE: a comment is deleted and rewritten, not edited.

-- Reports can now point at a comment.
alter table public.content_reports drop constraint if exists content_reports_type_valid;
alter table public.content_reports add constraint content_reports_type_valid
    check (content_type in ('song_review', 'album_review', 'artist_review', 'profile', 'comment'));

-- Deleting a log takes its comments with it (there is no FK to cascade from).
create or replace function public.delete_comments_for_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.review_comments
    where content_id = old.id
      and content_type = tg_argv[0];
    return old;
end;
$$;

drop trigger if exists reviews_delete_comments on public.reviews;
create trigger reviews_delete_comments after delete on public.reviews
    for each row execute function public.delete_comments_for_review('song_review');
drop trigger if exists album_reviews_delete_comments on public.album_reviews;
create trigger album_reviews_delete_comments after delete on public.album_reviews
    for each row execute function public.delete_comments_for_review('album_review');
drop trigger if exists artist_reviews_delete_comments on public.artist_reviews;
create trigger artist_reviews_delete_comments after delete on public.artist_reviews
    for each row execute function public.delete_comments_for_review('artist_review');
