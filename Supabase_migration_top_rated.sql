-- Spectrum — highest rated on Spectrum (songs, albums, artists)
--
-- One RPC per kind ranks items by a Bayesian average, so one 5★ from a single person
-- doesn't outrank 40 ratings averaging 4.6:
--
--     score = (n * avg + m * C) / (n + m)
--
-- n = ratings for the item, avg = its mean, C = the mean across the whole table and
-- m = `prior_weight` (how many "average" votes every item starts with). Items with fewer
-- than `min_ratings` are left out.
--
-- With few users the list is noise, so the app hides the section until the RPC returns at
-- least `TopRated.minItemsToShow` rows (see TopRatedSection.swift). Raising the bar later
-- is a client constant, not a migration.
--
-- Ratings are stored 0-10 (half stars); the app divides by 2.
-- Blocked users aren't excluded here: one person's ratings are a small share of an
-- aggregate, and filtering per viewer would make the query uncacheable.
--
-- Run in Supabase → SQL Editor. Safe to re-run.

create or replace function public.top_rated_tracks(
    min_ratings int default 3, prior_weight int default 5, lim int default 20
)
returns table (item_id bigint, avg_rating numeric, rating_count bigint, score numeric)
language sql stable
set search_path = public
as $$
    with c as (select avg(rating)::numeric as mean from reviews where rating > 0)
    select itunes_track_id, round(avg(rating)::numeric, 2), count(*),
           (count(*) * avg(rating) + prior_weight * (select mean from c)) / (count(*) + prior_weight)
    from reviews
    where rating > 0
    group by itunes_track_id
    having count(*) >= min_ratings
    order by 4 desc, 3 desc
    limit least(lim, 50);
$$;

create or replace function public.top_rated_albums(
    min_ratings int default 3, prior_weight int default 5, lim int default 20
)
returns table (item_id bigint, avg_rating numeric, rating_count bigint, score numeric)
language sql stable
set search_path = public
as $$
    with c as (select avg(rating)::numeric as mean from album_reviews where rating > 0)
    select itunes_collection_id, round(avg(rating)::numeric, 2), count(*),
           (count(*) * avg(rating) + prior_weight * (select mean from c)) / (count(*) + prior_weight)
    from album_reviews
    where rating > 0
    group by itunes_collection_id
    having count(*) >= min_ratings
    order by 4 desc, 3 desc
    limit least(lim, 50);
$$;

create or replace function public.top_rated_artists(
    min_ratings int default 3, prior_weight int default 5, lim int default 20
)
returns table (artist_name text, avg_rating numeric, rating_count bigint, score numeric)
language sql stable
set search_path = public
as $$
    with c as (select avg(rating)::numeric as mean from artist_reviews where rating > 0)
    select artist_name, round(avg(rating)::numeric, 2), count(*),
           (count(*) * avg(rating) + prior_weight * (select mean from c)) / (count(*) + prior_weight)
    from artist_reviews
    where rating > 0
    group by artist_name
    having count(*) >= min_ratings
    order by 4 desc, 3 desc
    limit least(lim, 50);
$$;

grant execute on function public.top_rated_tracks(int, int, int) to anon, authenticated;
grant execute on function public.top_rated_albums(int, int, int) to anon, authenticated;
grant execute on function public.top_rated_artists(int, int, int) to anon, authenticated;
