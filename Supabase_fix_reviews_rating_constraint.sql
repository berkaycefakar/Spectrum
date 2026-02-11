-- ============================================================
-- Şarkı loglarken "reviews_rating_check" hatasını giderir.
-- Uygulama puanı 0-10 (integer) kaydediyor; eski constraint 1-5 idi.
-- Supabase SQL Editor'da bu dosyayı çalıştır.
-- ============================================================

-- Eski constraint adı bazen "reviews_rating_check" bazen "reviews_rating-check" olabiliyor; ikisini de deniyoruz.
alter table public.reviews drop constraint if exists reviews_rating_check;
alter table public.reviews drop constraint if exists "reviews_rating-check";

-- 0-10 aralığını kabul et (0.5 yıldız = 1, 5 yıldız = 10)
alter table public.reviews add constraint reviews_rating_check check (rating >= 0 and rating <= 10);
