-- Spectrum — likes on comments
--
-- Comments reuse `review_likes`: the table is already polymorphic (content_type +
-- content_id), its RLS already says "like only as yourself, unlike only your own", and the
-- count RPC already groups by content_id. Only the allowed types and the cleanup trigger
-- need to learn about comments.
--
-- Run in Supabase → SQL Editor. Safe to re-run.

alter table public.review_likes drop constraint if exists review_likes_type_valid;
alter table public.review_likes add constraint review_likes_type_valid
    check (content_type in ('song_review', 'album_review', 'artist_review', 'comment'));

drop trigger if exists review_comments_delete_likes on public.review_comments;
create trigger review_comments_delete_likes
    after delete on public.review_comments
    for each row execute function public.delete_orphaned_review_likes('comment');
