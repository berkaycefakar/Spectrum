-- ============================================================
-- artist_reviews tablosu — sanatçı loglama özelliği için.
-- Bu tablo olmadığı için ProfileView'da özellik kapalıydı.
-- Supabase SQL Editor'da bu dosyayı çalıştır.
-- ============================================================

-- 1) artist_reviews tablosu yoksa oluştur
create table if not exists public.artist_reviews (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,

  artist_name text not null,

  rating integer check (rating >= 0 and rating <= 10),
  review_text text,
  vibe_color text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()),

  -- Bir kullanıcı aynı sanatçıyı bir kez loglar; tekrar puanlarsa üzerine yazılır.
  unique (user_id, artist_name)
);

-- Profilde ve sanatçı sayfasında sık sorgulanan kolonlar
create index if not exists artist_reviews_user_id_idx on public.artist_reviews (user_id);
create index if not exists artist_reviews_artist_name_idx on public.artist_reviews (artist_name);

-- 2) RLS aç
alter table public.artist_reviews enable row level security;

-- 3) Policy'ler (tekrar çalıştırılabilir)
drop policy if exists "Artist reviews are viewable by everyone." on public.artist_reviews;
create policy "Artist reviews are viewable by everyone."
  on public.artist_reviews for select
  using ( true );

drop policy if exists "Users can create artist reviews." on public.artist_reviews;
create policy "Users can create artist reviews."
  on public.artist_reviews for insert
  with check ( auth.uid() = user_id );

drop policy if exists "Users can update own artist reviews." on public.artist_reviews;
create policy "Users can update own artist reviews."
  on public.artist_reviews for update
  using ( auth.uid() = user_id );

drop policy if exists "Users can delete own artist reviews." on public.artist_reviews;
create policy "Users can delete own artist reviews."
  on public.artist_reviews for delete
  using ( auth.uid() = user_id );
