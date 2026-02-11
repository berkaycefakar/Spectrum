# Spectrum

Müzik loglama ve sosyal keşif uygulaması — şarkı ve albümleri puanlayın, yorum ekleyin, takip ettiğiniz kullanıcıların loglarını feed’de görün. *Letterboxd for music.*

## Özellikler

- **Şarkı loglama** — iTunes ile arama, puan (0–5), vibe rengi ve yorum
- **Albüm puanlama** — Albüm sayfasında topluluk puanları, parça listesi; puan ve yorum ayrı sheet’te
- **Profil** — Kendi log’larınız (Songs / Albums), istatistikler, düzenleme
- **Feed** — Takip ettiğiniz kullanıcıların log’ları; kimseyi takip etmiyorsanız son log’lar
- **Kullanıcı arama ve takip** — Kullanıcı adıyla arama, profil görüntüleme, takip et / bırak
- **Auth** — E-posta ile kayıt / giriş; onay linki uygulama deep link’i ile (`spectrum://auth-callback`)

## Teknolojiler

- **SwiftUI** (iOS)
- **Supabase** — Auth, Postgres (profiles, reviews, album_reviews, follows)
- **iTunes Search API** — Şarkı/albüm arama ve detay

## Gereksinimler

- Xcode 15+
- iOS 17+
- Supabase projesi

## Kurulum

1. **Repoyu klonlayın**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Spectrum.git
   cd Spectrum
   ```

2. **Xcode’da açın**  
   `Spectrum.xcodeproj` dosyasını açın; gerekirse Swift paketleri (Supabase) otomatik çözülür.

3. **Supabase**
   - [Supabase](https://supabase.com) üzerinde bir proje oluşturun.
   - **SQL Editor**’da sırayla çalıştırın:
     - `Supabase_migration_album_reviews.sql` — `album_reviews` tablosu ve RLS
     - `Supabase_fix_reviews_rating_constraint.sql` — `reviews.rating` 0–10 kısıtı
   - **Authentication → URL Configuration** içinde Redirect URL’lere ekleyin:  
     `spectrum://auth-callback`
   - Xcode’da **URL Types** (Target → Info) ekleyin: Scheme = `spectrum`

4. **API anahtarları**  
   `Spectrum/Services/SupabaseManager.swift` içinde `supabaseURL` ve `supabaseKey` değerlerini kendi Supabase projenize göre güncelleyin. (Geliştirme için genelde anon key yeterlidir.)

5. **Derleyip çalıştırın**  
   Simülatör veya cihaz seçip Run (⌘R).

## Veritabanı

- **profiles** — Kullanıcı adı, avatar, bio
- **reviews** — Şarkı log’ları (itunes_track_id, rating 0–10, review_text, vibe_color)
- **album_reviews** — Albüm puanları (itunes_collection_id, rating 0–10, review_text)
- **follows** — Takip ilişkileri (follower_id, following_id)

RLS ile kullanıcılar sadece kendi verilerini yazabiliyor; okuma ilkeleri paylaşıma uygun.

## Lisans

Bu proje kişisel / eğitim amaçlı kullanım içindir.
