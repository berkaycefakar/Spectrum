# Spectrum — Proje Durumu & PC Devir Notu

> **Bu dosya, PC değişikliği için yazıldı (25 Temmuz 2026).** Son birkaç sohbette yapılan her
> şeyin özeti, neyin bittiği, neyin kaldığı ve yeni bilgisayarda ne yapman gerektiği.
>
> Diğer dokümanlar: `HANDOFF.md` (teknik günce), `APP_STORE_READINESS.md` (mağaza),
> `AUTH_SETUP.md` (Apple/Google giriş kurulumu), `SPECTRUM_NOTES.md` (strateji).

---

## 🔴 ÖNCE BUNU OKU — İŞİN GİTMESİN

**Son 4-5 sohbetin TÜM işi şu an sadece bu bilgisayarda ve GitHub'a gönderilmedi.**
- 26 değişen dosya + 14 yeni dosya + 1 silinen dosya, hepsi commit edilmemiş.
- Son commit `f677fed` — o günden sonrası (community stats, giriş ekranı, hesap silme,
  Apple/Google, şifre sıfırlama, tüm bug'lar) **commit'te YOK.**

### PC değiştirmeden önce MUTLAKA yap:
```bash
cd ~/Desktop/Spectrum
git add -A
git commit -m "Community stats, auth overhaul, account deletion, App Store prep"
git push origin main
```
> Ben senin adına commit/push YAPMADIM (istemedin). Bunu sen yapmalısın. Yapmazsan yeni
> bilgisayarda `git clone` ile SADECE `f677fed`'i alırsın, gerisi kaybolur.

### Yeni bilgisayarda kurulum:
1. `git clone https://github.com/berkaycefakar/Spectrum.git`
2. Xcode ile `Spectrum.xcodeproj`'u aç
3. İlk açılışta SPM paketleri (Supabase vb.) otomatik çözülür — internet gerekir, biraz sürer
4. **Gerçek cihaz gerekir** — MusicKit ve Apple ile giriş simülatörde çalışmaz
5. Signing: Team `8ZCY68284F` seçili olmalı (Automatic signing)

---

## Proje 30 saniyede

- **Spectrum = "müzik için Letterboxd".** Kullanıcı şarkı/albüm/sanatçı loglar, 0-5 puan verir,
  yorum yazar, bir "vibe" rengi seçer, başkalarını takip eder, feed'de görür.
- **iOS 17+, SwiftUI.** Bundle `berkay.Spectrum`, Team `8ZCY68284F`.
- **Müzik verisi:** Apple MusicKit (`MusicService.swift`). Simülatörde ÇALIŞMAZ, cihaz şart.
  Abonelik gerekmez (arama/kapak/preview ücretsiz).
- **Backend:** Supabase (`SupabaseManager.swift`). Tablolar: `profiles`, `reviews`,
  `album_reviews`, `artist_reviews`, `follows`. Güvenlik tamamen RLS'e bağlı.
- **Gerçek konum: `~/Desktop/Spectrum`** (`~/projects/Spectrum` DEĞİL — o ölü iTunes denemesi).
- **Build:** `xcodebuild -project Spectrum.xcodeproj -scheme Spectrum -destination
  'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Editördeki "No such module 'Supabase'/'UIKit'" uyarıları SourceKit'in yanlış alarmı;
  gerçek xcodebuild temiz derliyor. **Şu an build TEMİZ (doğrulandı).**

---

## Son sohbetlerde YAPILAN İŞLER (hepsi derleniyor, HİÇBİRİ cihazda test edilmedi)

### 1. Topluluk puanları (community stats)
- **Yeni:** `UI/Components/CommunityStatsView.swift` — `VibePalette` (8 vibe rengi + isimleri +
  en yakın tona yuvarlama), `CommunityStats` (ortalama puan, kişi sayısı, renk dağılımı),
  `CommunityStatsCard`.
- Şarkı / albüm / sanatçı sayfalarının üçünde de: **ortalama puan, kaç kişi puanladı, en çok
  verilen vibe rengi** + dağılım çubuğu. (Sanatçı sayfasında topluluk bölümü hiç yoktu.)

### 2. Profilde sanatçı fotoğrafları
- `artist_reviews` sadece isim tutuyor → fotoğraf yoktu, harf rozeti görünüyordu.
- `MusicService.fetchArtistBriefs(names:)` + `ArtistBriefCache` actor + `ArtistBrief` modeli:
  isimleri MusicKit'te paralel arayıp foto+id çözüyor, cache'liyor.

### 3. Similar Artists
- `MusicKit.Artist.similarArtists` → sanatçı sayfasında yuvarlak fotoğraflı yatay satır.
  Boşsa gizli.

### 4. Kaydetme katmanı (KRİTİK bug'lar düzeltildi)
- `saveReview`/`saveAlbumReview`/`saveArtistReview` artık `upsert(onConflict:)` KULLANMIYOR:
  - `reviews`: unique index olmadığı için Postgres "no unique or exclusion constraint..."
    hatası veriyordu → **şarkı loglamak hata veriyordu.**
  - `album_reviews`: conflict target yoktu → her kayıt **yeni satır** ekliyordu, düzenleme
    çalışmıyordu, renk değişmiyordu, kopyalar birikiyordu.
- Yeni akış: satırı bul → varsa update, yoksa insert; eski kopyaları best-effort sil.
  **Artık hiçbir SQL migration'a bağımlı değil.**
- Sanatçı adı eşleşmesi harf duyarsız (`ilike`, `%`/`_`/`\` escape'li) → "Daft Punk" =
  "daft punk".

### 5. Albüm log & sıralama
- Albüm logu vibe rengini `#FFCC00` SABİT kaydediyordu → prism picker eklendi.
- Rating vermeden save → artık **"Add a rating before saving."** uyarısı (buton eskiden
  ölüydü), DB hataları ekranda görünüyor, başarıda sheet kapanıyor.
- Albümler **en yeniden eskiye** sıralanıyor (`Album.newestFirst`), kırpmadan ÖNCE.

### 6. Tür sayısı (genre)
- `combinedGenres`: sanatçının kendi türleri önde + top şarkı/albüm türleri sıklığa göre,
  "Music" üst türü elenmiş, max 8. (1 yerine 4-6 tür.)

### 7. Giriş / kayıt ekranı — komple elden geçti
- **Hata mesajları hiç görünmüyordu — kök sebep:** `signIn/signUp` global `isLoading`'i true
  yapıyordu, `ContentView` de o an `SplashView` gösteriyordu → `AuthView` ekrandan silinip
  boş yeniden kuruluyordu. Düzeltildi (`isLoading` artık sadece "açılışta oturum yükleniyor").
- **`AuthErrorMessage`** (yeni): Supabase/URLSession hatalarını insan diline çeviriyor + gönderim
  öncesi istemci doğrulaması.
- **Apple ile giriş** — `SignInWithAppleButton` + `signInWithIdToken` (native akış).
  `AppleSignInCoordinator.swift` (nonce üretimi + SHA-256). `Spectrum.entitlements` eklendi.
- **Google ile giriş** — `signInWithOAuth` web akışı (ekstra bağımlılık YOK). `GoogleGMark.swift`
  ile dört renkli "G" çizildi (globe simgesi yerine).
- **Şifremi unuttum** — `PasswordResetView` + `resetPasswordForEmail`.
- **Şifre sıfırlama ekranı** — `NewPasswordView.swift` + `AuthDeepLink.swift`. Recovery linki
  yakalanıp "yeni şifre belirle" ekranı açılıyor. Settings → Change Password yolu da var.
- **Kayıt olunca doğrudan giriş** — `signUp` artık `SignUpOutcome` döndürüyor.
- **Buton dokunma alanları** — `.frame/.padding/.background` Button dışına uygulanınca dokunma
  alanı yazı kadar kalıyordu; 4 gerçek yerde düzeltildi (label içine taşındı).
- **Landing ekranı** — tasarım AYNI kaldı; sadece kırık iki URL düzeltildi (kapak + preview
  ikisi de 404'tü). `refreshDemoTrack()` ile çalışma zamanında iTunes lookup'tan tazeleniyor.

### 8. Preview (ses) gecikmesi
- `AVAudioSession` çağrıları main thread'i kilitliyordu → seri arka plan kuyruğuna taşındı.
- `isBuffering` eklendi: indirme sürerken spinner (eskiden ikon "pause"a dönüp sessiz kalıyordu).
- `automaticallyWaitsToMinimizeStalling = false` (30 sn preview için erken başlama).

### 9. URL şeması düzeltmesi (KRİTİK)
- `spectrum://` şeması bundle'da HİÇ kayıtlı değildi → e-posta onay + şifre sıfırlama linkleri
  uygulamayı açamıyordu. `SpectrumInfo.plist` eklendi (`INFOPLIST_FILE`). **Not:** bu dosya
  bilerek `Spectrum/` klasörünün DIŞINDA — içine konunca "Multiple commands produce" hatası
  veriyor (synchronized file group onu iki kez alıyor).

### 10. Hesap silme (App Store için ZORUNLU)
- `SettingsView` → onay → `SupabaseManager.deleteAccount()` (loglar, follow grafiği iki yönlü,
  avatar, profil, signOut). `auth.users` satırına dokunulmuyor (service-role key uygulamaya
  gömülemez → Edge Function gerekli, `APP_STORE_READINESS.md`'de).

### 11. Apple Music izni reddedilirse
- `MusicAuthorizationStore` + `MusicAccessView`: ne bozulduğunu anlatan ekran, Settings'e deep
  link, öne gelince izin yeniden okunuyor.

### 12. Diğer bug düzeltmeleri (Chief oturumu — detay `APP_STORE_READINESS.md` §2)
- `SessionStore.signOut` hata alınca oturumu temizlemiyordu → çıkış yapılamıyordu.
- `SearchDiscoveryView`: 4 arama tek tuple'da, biri patlayınca dördü çöpe gidiyordu.
- `ArtistDetailView` rating her `onChange`'de kaydediyordu → 550ms debounce.
- `EditProfileView` sessiz return → spinner sonsuza dönüyordu.
- Sıralamalar stabil değildi → `createdAt` tie-break.
- `ActivityView`'a `.refreshable`.
- Detay sayfalarındaki ardışık await'ler `async let` ile paralelleştirildi.
- Ölü `iTunesService.swift` silindi.
- Deployment target **26.2 → 17.0** (bu haliyle neredeyse hiçbir cihaza kurulamazdı — tek
  başına en kritik bulgu).
- `PrivacyInfo.xcprivacy` eklendi, `ITSAppUsesNonExemptEncryption = NO`.

---

## KALAN İŞLER (öncelik sırasıyla)

### 🔴 Yayın öncesi ZORUNLU (Supabase panelinde / senin yapman gereken)
1. **Commit + push** (yukarıda) — her şeyden önce.
2. **RLS denetimi** — tüm tablolarda RLS açık mı, policy'ler doğru mu? Uygulamanın TÜM güvenliği
   buna bağlı. Audit script'i + gereken policy seti `APP_STORE_READINESS.md` §7'de.
3. **Apple/Google giriş panel ayarları** — kod hazır ama panel ayarları yapılmadan ÇALIŞMAZ.
   Adım adım: `AUTH_SETUP.md`. Özet: Supabase Redirect URL + iki provider + Apple Developer
   portal + Google Cloud Console.
4. **Hesap silme Edge Function'ı** — `auth.users` satırı için (`APP_STORE_READINESS.md` §1.2).
5. **UGC gereksinimleri** — içerik bildirme + kullanıcı engelleme + küfür filtresi. Hesap
   silmeden sonra **en olası ikinci ret sebebi**, kodda YOK (`APP_STORE_READINESS.md` §8).
6. **iPad kararı** — uygulama iPad desteği beyan ediyor ama arayüz sadece telefon-dikey
   (`APP_STORE_READINESS.md` §3.2).
7. **artist_reviews tablosu** (`Supabase_migration_artist_reviews.sql`) + **avatars bucket**
   (Public + policy) hâlâ gerekli.

### 🟡 Test edilmesi gerekenler (cihazda, hiçbiri doğrulanmadı)
- Albümü iki kez kaydet → renginin gerçekten değiştiğini + kopya satırların temizlendiğini gör.
- **Hesap silme** — geri dönüşü YOK, önce tek kullanımlık hesapla dene.
- Şifre sıfırlama akışı (gerçek cihazda, mail linkiyle).
- Similar artists satırı, albüm sıralaması, preview spinner'ı.
- Apple Music iznini reddet → açıklama ekranı çıkıyor mu.
- Preview çalarken arkadaki müziğin susmaması.
- iPhone SE'de AddLogView tek ekrana sığıyor mu.

### 🟢 Öneriler (yapılmadı, `HANDOFF.md` sonunda detaylı)
1. **Gerçek listeler** — `MusicCatalogChartsRequest` (Discover kullanıcı azken boş). En yüksek getiri.
2. Albüm rozetleri (Explicit, Dolby Atmos/Lossless).
3. "Latest release" bloğu, besteci alanı, mini-player, paylaşım kartı.
4. Yarım yıldız gösterimi (`ArtistReviewRow` `rating/2` tam sayı bölmesi yapıyor).

---

## Bilinen açık uçlar / riskler
- **Karışık dil:** `EditProfileView` hata mesajları Türkçe, gerisi İngilizce. Mağaza öncesi karar ver.
- **Şifre sıfırlama:** Supabase Redirect URL eklenmeden linkler uygulamayı açmaz (`AUTH_SETUP.md` Bölüm 0).
- **Google logosu** çizim; yayın öncesi Google'ın resmî asset'iyle değiştir (marka kuralı).
- **Supabase ücretsiz plan:** ilk darboğaz Storage (1 GB) — avatarları yüklemeden küçültmek
  (256×256 JPEG) birkaç bin → on binlerce kullanıcı yapar. Yapılmadı, istenirse eklenir.
- Preview'ın bir kısmı ağ gecikmesi, kalıcı. Gerçek performans için **Release** ile ölç, Debug ile değil.

---

## Yeni eklenen dosyalar (untracked — commit'e girmesi lazım)
```
Spectrum/Core/Extensions/AuthDeepLink.swift
Spectrum/Core/Extensions/AuthErrorMessage.swift
Spectrum/Services/AppleSignInCoordinator.swift
Spectrum/Services/MusicAuthorizationStore.swift
Spectrum/UI/Components/CommunityStatsView.swift
Spectrum/UI/Components/GoogleGMark.swift
Spectrum/UI/Screens/MusicAccessView.swift
Spectrum/UI/Screens/NewPasswordView.swift
Spectrum/Spectrum.entitlements
Spectrum/PrivacyInfo.xcprivacy
SpectrumInfo.plist
APP_STORE_READINESS.md, AUTH_SETUP.md, HANDOFF.md, PROJECT_STATE.md (bu dosya)
```
`git add -A` hepsini alır (`.gitignore` sadece build/DerivedData/credentials'ı hariç tutuyor).
