# Spectrum — Güvenlik, Çıkış Senaryosu ve Para Kazanma Notları

## 1. Bu turda yapılan kod değişiklikleri

- Feed başlığı: prizma logo işareti + **beyaz** "Spectrum" (gökkuşağı yazı kaldırıldı).
- App icon eklendi (mor neon prizma, `AppIcon-1024.png`).
- Çoklu sanatçı: bir şarkıdaki her sanatçı ayrı ayrı tıklanabilir → kendi profiline gider.
- Track ekranında oynat tuşu artık albüm kapağı renginde.
- Mükerrer log düzeltmesi: `saveReview` artık upsert (SQL gerekiyor, aşağıda).
- Log silme/düzenleme: kendi logunda sağ üst menü (Edit / Delete).
- Discover: gerçek "trending" (topluluğun son logladıkları) + boşsa rotasyonlu tohum havuzu.
- Trending vibes: 12'lik havuzdan her açılışta 6 rastgele.
- Activity ekranı: başlık + zaman gruplaması (Today / This Week / Earlier).
- Performans: feed/profil detayları tek toplu istekle çekiliyor (N+1 kaldırıldı).

## 2. Çalıştırılması gereken SQL (Supabase → SQL Editor)

### a) Mükerrer log önleme (upsert'in çalışması için ŞART)
```sql
-- Önce olası mevcut mükerrerleri en yenisi kalacak şekilde temizle
delete from public.reviews a
using public.reviews b
where a.user_id = b.user_id
  and a.itunes_track_id = b.itunes_track_id
  and a.created_at < b.created_at;

-- Sonra tekillik kısıtı ekle
alter table public.reviews
  add constraint reviews_user_track_unique unique (user_id, itunes_track_id);
```

### b) Avatar storage bucket politikası (GÜVENLİ sürüm)
Storage → New bucket → `avatars` (Public) oluşturduktan sonra:
```sql
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- Kullanıcı SADECE kendi klasörüne (user_id/...) yazabilir
create policy "Users manage their own avatar"
  on storage.objects for insert
  with check ( bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text );

create policy "Users update their own avatar"
  on storage.objects for update
  using ( bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text );
```

## 3. Güvenlik taraması

**İyi olanlar:**
- Koddaki Supabase anahtarı `anon` anahtarı — istemciye gömülmesi TASARIM GEREĞİ normaldir, sızıntı değil. (JWT içinde `"role":"anon"`.) Kritik olan `service_role` anahtarı kodda YOK. ✅
- Sorgular parametreli (`.eq`, `.ilike value:`) → SQL injection yok. ✅
- Yorum metinleri SwiftUI `Text` ile gösteriliyor, HTML render yok → XSS yok. ✅
- `SpotifyCredentials.txt` .gitignore'da ve git'e girmemiş. ✅

**Aksiyon gerekenler:**
1. **RLS (Row Level Security) — EN KRİTİK.** Anon anahtar herkeste olabilir (binary'den çıkarılabilir). Güvenliğin tamamı RLS politikalarına bağlı. Şu tabloların HEPSİNDE RLS açık ve doğru policy olduğunu doğrula: `profiles`, `reviews`, `follows`, `album_reviews`, `artist_reviews`.
   Kontrol: Supabase → Table Editor → her tablo → RLS "Enabled" mı? Değilse veri herkese açık demektir.
   ```sql
   -- RLS durumunu gör
   select tablename, rowsecurity from pg_tables where schemaname = 'public';
   ```
   `reviews` için beklenen: herkes SELECT edebilir, ama INSERT/UPDATE/DELETE sadece `auth.uid() = user_id`.
2. Avatar storage politikası — yukarıdaki güvenli sürümü kullan (önceki `authenticated` sürümü herkesin herkesin avatarını ezmesine izin veriyordu; kod artık `user_id/avatar.jpg` yoluna yazıyor).
3. E-posta doğrulaması açık mı kontrol et (Supabase → Auth → Email → Confirm email). Kapalıysa sahte hesaplar açılır.

## 4. Muhtemel çıkış (exit) senaryosu

Gerçekçi ol: müzik uygulamalarında çıkış nadir ve genelde küçük. En olası yollar, olasılık sırasıyla:

1. **Acqui-hire / talent + ürün satın alımı (EN OLASI).** Spotify, Apple, SoundCloud, Deezer, Bandcamp gibi bir oyuncu ekibi + ürünü küçük bir meblağa alır. Letterboxd'un müzik boşluğu gerçek; büyük bir platform "sosyal müzik günlüğü" özelliğini hızlı kazanmak için satın alabilir. Tetikleyici: anlamlı kullanıcı sayısı (100K+ aktif) ve güçlü retention.
2. **Music-tech konsolidasyonu.** last.fm (CBS), Genius, Bandsintown gibi şirketler tamamlayıcı sosyal katman için alabilir. Daha çok stratejik, düşük-orta rakam.
3. **Letterboxd'un kendisi** müzik dikeyine girmek isterse referans/rakip olarak satın alma.
4. **Lifestyle business (çıkış YOK).** Abonelik + reklamla kârlı, küçük ama sürdürülebilir bir işletme olarak elde tutmak. Çoğu bu kategoride kalır — ve bu bir başarısızlık değildir.

**Çıkışı gerçekçi kılmak için gereken:** (a) tescilli veri — kullanıcıların oluşturduğu puan/liste/vibe verisi zamanla değerli bir varlık olur; (b) yüksek retention (30 günlük tutma > %25); (c) net bir topluluk kültürü (Letterboxd'un "film Twitter'ı" gibi bir "müzik Twitter'ı").

**Dürüst uyarı:** MusicKit'e bağımlılık çıkışta bir risk. Alıcı Apple değilse, verinin Apple Music kimliklerine bağlı olması taşınabilirliği zorlaştırır. ISRC/MusicBrainz gibi platform-bağımsız kimlikleri de saklamak çıkış değerini artırır.

## 5. Para kazanma (bugünden başlanabilir)

Öncelik sırası:

1. **Freemium abonelik — "Spectrum Pro" (ANA MODEL).** Letterboxd Pro/Patron ($19–49/yıl) tam da bunu yapıyor ve çalışıyor. Ücretsiz katman tam işlevsel kalır; Pro şunları açar:
   - Sınırsız liste + gelişmiş istatistik (yıllık "spektrumun", tür/mood dağılımı, dinleme trendleri).
   - Profil özelleştirme (temalar, rozetler).
   - Reklamsız.
   - Erken erişim özellikleri.
   - Hedef: ilk 12 ayda kullanıcıların %3–5'i. 10K kullanıcıda ~%4 × $25/yıl = ~$10K/yıl. Ölçekle büyür.
2. **Affiliate — en kolay ilk gelir.** Her albüm/şarkı sayfasına Apple Music affiliate linki koy (Apple Services Performance Partners programı). Kullanıcı zaten "bunu dinle" diyecek; tıklama/abonelikten komisyon. Sıfır kullanıcı sürtünmesi. Amazon Music / vinyl (Amazon Associates) linkleri de eklenebilir.
3. **Yıllık "Wrapped" tarzı paylaşılabilir kart.** Yılın özeti (senin spektrumun) — viral büyüme + Pro'ya dönüşüm kancası. Direkt gelir değil ama edinim motoru.
4. **Sonraki aşama — sanatçı/label araçları.** Sanatçılar kendi sayfalarını talep edip takipçi/tepki analitiği görebilir (ücretli). last.fm/Bandsintown modeli.
5. **Reklam (DİKKATLİ).** Feed'de seyrek, native "önerilen" kartlar. Erken dönemde topluluk hissini bozar — abonelik oturmadan yapma.

**Bugün yapılabilecek somut ilk adım:** Apple Music affiliate linklerini albüm/şarkı sayfalarına ekle (kod olarak küçük) + Pro katmanını RevenueCat ile kur (StoreKit'i kendin yazmadan abonelik altyapısı). İkisi de birkaç günlük iş.

**Gerçekçi beklenti:** İlk yıl bu muhtemelen "cep harçlığı" seviyesinde gelir getirir, tam zamanlı gelir değil. Müzik sosyal uygulamaları retention'la kazanır; önce topluluğu büyüt, para ikinci aşama. Erken agresif paraya çevirme büyümeyi öldürür.
