-- Ratings in tenths: 4.3 stars is stored as 8.6 on the existing 0–10 scale.
-- Existing whole numbers (8 = 4 stars) keep their meaning; nothing is rescaled.
-- The check constraints (0..10) carry over unchanged. top_rated_* only average the column,
-- so they work on numeric as they did on integer.
begin;
alter table public.reviews        alter column rating type numeric(3,1) using rating::numeric(3,1);
alter table public.album_reviews  alter column rating type numeric(3,1) using rating::numeric(3,1);
alter table public.artist_reviews alter column rating type numeric(3,1) using rating::numeric(3,1);
commit;
