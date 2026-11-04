-- Spectrum — security hardening (2026-11-04 review)
--
-- 1. Avatars. Two leftover storage policies let any signed-in user write ANY path in the
--    `avatars` bucket. Policies are OR'ed, so they cancelled out the per-user folder rule and
--    anyone could overwrite someone else's avatar. Only the folder-scoped ones stay.
--    The bucket also had no size or type limit, so it could be used to host arbitrary files
--    (an HTML page, a 5 GB upload) under this project's domain.
-- 2. Text columns had no length limit; a client could store megabytes in a review or bio.
--    Limits sit far above anything the app's own forms produce.
-- 3. Duplicate policies from earlier migrations, removed so the set reads as what it means.
--
-- Run this in Supabase → SQL Editor. Safe to re-run.

-- 1. Avatars --------------------------------------------------------------------------
drop policy if exists "Users can upload their own avatar" on storage.objects;
drop policy if exists "Users can update their own avatar" on storage.objects;
drop policy if exists "Avatar images are publicly readable" on storage.objects; -- duplicate of "...accessible"

update storage.buckets
set file_size_limit = 5242880, -- 5 MB; the app uploads a compressed JPEG
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
where id = 'avatars';

-- 2. Lengths -----------------------------------------------------------------------------
alter table public.reviews drop constraint if exists reviews_text_length;
alter table public.reviews add constraint reviews_text_length
    check (review_text is null or char_length(review_text) <= 5000);
alter table public.album_reviews drop constraint if exists album_reviews_text_length;
alter table public.album_reviews add constraint album_reviews_text_length
    check (review_text is null or char_length(review_text) <= 5000);
alter table public.artist_reviews drop constraint if exists artist_reviews_text_length;
alter table public.artist_reviews add constraint artist_reviews_text_length
    check (review_text is null or char_length(review_text) <= 5000);
alter table public.profiles drop constraint if exists profiles_username_length;
alter table public.profiles add constraint profiles_username_length
    check (username is null or char_length(username) between 1 and 40);
alter table public.profiles drop constraint if exists profiles_bio_length;
alter table public.profiles add constraint profiles_bio_length
    check (bio is null or char_length(bio) <= 500);

-- 3. Duplicates ---------------------------------------------------------------------------
-- Each dropped policy is identical to, or a subset of, the one kept beside it.
drop policy if exists "follows_delete_self_follower" on public.follows;
drop policy if exists "Users can unfollow (delete own)." on public.follows;
drop policy if exists "follows_insert_self_follower" on public.follows;
drop policy if exists "Users can follow (insert own)." on public.follows;
drop policy if exists "Follows are viewable by everyone." on public.follows;
drop policy if exists "follows_select_related" on public.follows;

drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Profiles are viewable by everyone." on public.profiles;
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can update their own profile." on public.profiles;
drop policy if exists "Users can update own profile." on public.profiles;

drop policy if exists "Users can delete own reviews." on public.reviews;
drop policy if exists "Users can delete their own reviews." on public.reviews;
drop policy if exists "Users can create their own reviews." on public.reviews;
drop policy if exists "Users can create reviews." on public.reviews;
drop policy if exists "Reviews are viewable by everyone." on public.reviews;
drop policy if exists "Users can update their own reviews." on public.reviews;
