-- ============================================================
-- Sadece EKSİK olanı ekleyen migration (profiles, reviews, follows ZATEN VAR)
-- Supabase SQL Editor'da bu dosyayı çalıştır.
-- ============================================================

-- 1) album_reviews tablosu yoksa oluştur
create table if not exists public.album_reviews (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,

  itunes_collection_id bigint not null,

  rating integer check (rating >= 0 and rating <= 10),
  review_text text,
  vibe_color text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()),

  unique (user_id, itunes_collection_id)
);

-- 2) RLS aç
alter table public.album_reviews enable row level security;

-- 3) Eski policy varsa sil, yeniden oluştur (tekrar çalıştırılabilir)
drop policy if exists "Album reviews are viewable by everyone." on public.album_reviews;
create policy "Album reviews are viewable by everyone."
  on public.album_reviews for select
  using ( true );

drop policy if exists "Users can create album reviews." on public.album_reviews;
create policy "Users can create album reviews."
  on public.album_reviews for insert
  with check ( auth.uid() = user_id );

drop policy if exists "Users can update own album reviews." on public.album_reviews;
create policy "Users can update own album reviews."
  on public.album_reviews for update
  using ( auth.uid() = user_id );

drop policy if exists "Users can delete own album reviews." on public.album_reviews;
create policy "Users can delete own album reviews."
  on public.album_reviews for delete
  using ( auth.uid() = user_id );

-- -----------------------------------------------
-- OPSIYONEL: Sadece şarkı puanı 0-10 kabul etmiyorsa (reviews.rating 1-5 ise) çalıştır:
-- Supabase Table Editor → reviews → Constraints bölümünden mevcut rating constraint adını gör,
-- sonra aşağıdaki satırda 'reviews_rating_check' yerine o adı yaz.
-- alter table public.reviews drop constraint if exists reviews_rating_check;
-- alter table public.reviews add constraint reviews_rating_check check (rating >= 0 and rating <= 10);
