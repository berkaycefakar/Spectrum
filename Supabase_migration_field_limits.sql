-- Spectrum — bounds found while auditing the live policies after the 20 Nov 2026 scan
--
-- lists.cover_url had the same hole as avatar_url had: any https URL, fetched by everyone who
-- opens a public list (so the owner could log viewers' IPs). A few free-text columns had no
-- bound at all. Every existing row already satisfies these (checked 20 Nov 2026).
--
-- NOT APPLIED YET: waiting for approval. Run in Supabase → SQL Editor. Safe to re-run.

alter table public.lists drop constraint if exists lists_cover_url_shape;
alter table public.lists add constraint lists_cover_url_shape
    check (
        cover_url is null
        or (char_length(cover_url) <= 500
            and lower(cover_url) like lower('https://ysgbqlltzdhgsezukxxm.supabase.co/storage/v1/object/public/list-covers/' || user_id::text) || '/%')
    );

alter table public.reviews drop constraint if exists reviews_vibe_color_hex;
alter table public.reviews add constraint reviews_vibe_color_hex
    check (vibe_color is null or vibe_color ~ '^#[0-9A-Fa-f]{6}$');
alter table public.album_reviews drop constraint if exists album_reviews_vibe_color_hex;
alter table public.album_reviews add constraint album_reviews_vibe_color_hex
    check (vibe_color is null or vibe_color ~ '^#[0-9A-Fa-f]{6}$');
alter table public.artist_reviews drop constraint if exists artist_reviews_vibe_color_hex;
alter table public.artist_reviews add constraint artist_reviews_vibe_color_hex
    check (vibe_color is null or vibe_color ~ '^#[0-9A-Fa-f]{6}$');

alter table public.artist_reviews drop constraint if exists artist_reviews_artist_name_length;
alter table public.artist_reviews add constraint artist_reviews_artist_name_length
    check (char_length(artist_name) between 1 and 200);
alter table public.list_items drop constraint if exists list_items_content_ref_length;
alter table public.list_items add constraint list_items_content_ref_length
    check (char_length(content_ref) between 1 and 200);
alter table public.reviews drop constraint if exists reviews_spotify_track_id_length;
alter table public.reviews add constraint reviews_spotify_track_id_length
    check (spotify_track_id is null or char_length(spotify_track_id) <= 64);
