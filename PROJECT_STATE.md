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
> **30 Temmuz 2026 güncellemesi (2).** UGC migration'ı (`content_reports` + `user_blocks` +
> trigger) Supabase'de **çalıştırıldı** — rapor ve engelleme artık canlı. Kalanlar:
> `Supabase_migration_artist_reviews.sql`, RLS denetimi, `avatars` bucket + storage policy'leri,
> `supabase functions deploy delete-user`, e-posta doğrulaması kontrolü.
>
> **30 Temmuz 2026 güncellemesi (1).** Aşağıdaki 1. madde (commit/push) tamamlandı — `32594f5`
> commit'i atıldı ve push edildi. 4. ve 5. maddelerin **kod tarafı da yazıldı**; artık senden
> sadece panel işleri kaldı:
> - `Supabase_migration_ugc_reports_blocks.sql` çalıştırılacak (rapor + engelleme tabloları)
> - `supabase functions deploy delete-user` (hesap silmenin sunucu adımı)
>
> Ayrıca tab bar'a scroll'da küçülüp yazılarını gizleyen efekt eklendi
> (`UI/Components/SpectrumTabBar.swift`), iOS 26'da gerçek Liquid Glass kullanıyor.

1. ~~**Commit + push**~~ — yapıldı (`32594f5`).
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

## 30 Temmuz 2026 — bu oturumda yapılanlar

Hepsi `xcodebuild` ile temiz derleniyor. **Hiçbiri gerçek cihazda test edilmedi** — simülatörde
UI test ile swipe/tap attırıp ekran görüntüsüyle doğrulandı.

### 1. Tab bar: scroll'da küçülen kapsül (`UI/Components/SpectrumTabBar.swift`)
- Sistem tab bar'ı gizli (`.toolbar(.hidden, for: .tabBar)`), yerine custom kapsül.
- Aşağı kaydırınca yazılar gizlenip kapsül küçülüyor; durunca 250 ms sonra geri geliyor.
- iOS 26'da **gerçek Liquid Glass**: `glassEffect(.regular.interactive(), in: .capsule)`.
  `interactive()` parmakla etkileşen efekti veriyor. iOS 17–25 için material yedeği var.
- Ölçüler native kapsülden alındı: 22pt kenar boşluğu, 52pt öğe yüksekliği.
- **Öğrenilenler (tekrar aynı hataya düşmemek için):**
  - Scroll state'i `ContentView` dinlerse her açılıp kapanmada 4 ekran birden yeniden kurulur
    ve bar "yavaş" hissettirir. State sadece bar view'ının içinde dinlenmeli.
  - Her dokunuşta yeni `UIImpactFeedbackGenerator` yaratmak ilk tıkta belirgin gecikme yapıyor;
    tek örnek tutulup `prepare()` edilmeli.
  - Seçili pill doğrudan `selection`'a bağlanırsa hedef ekran kurulana kadar kıpırdamaz; ayrı
    bir state ile dokunulan karede hareket ettiriliyor, sekme geçişi bir runloop sonra.
  - iOS 26'nın kendi `.tabBarMinimizeBehavior(.onScrollDown)` davranışı bizim istediğimiz şey
    DEĞİL: barı tek yuvarlağa indirip diğer ikonları tamamen gizliyor (simülatörde doğrulandı).

### 2. UGC — App Store Guideline 1.2 (2. en olası ret sebebi kapandı)
- `Core/Utils/ProfanityFilter.swift` — TR+EN, leet-speak ("s1kt1r") ve tekrar harf ("fuuuck")
  çözümlü. `SupabaseManager.writeReview`'a konuldu: şarkı/albüm/sanatçı yazma yollarının üçü de
  oradan geçtiği için sonradan eklenecek bir ekran atlayamaz. Okurken de maskeleniyor
  (`ProfanityFilter.masked`) — filtre öncesi yazılmış satırlar DB'de duruyor.
- `UI/Screens/ReportContentView.swift` — sebep seçimi + detay + 24 saat yanıt taahhüdü.
- `UI/Components/ModerationActions.swift` — feed kartına / topluluk incelemesine uzun basınca
  Report + Block. Profilde ⋯ menüsünden de var.
- `UI/Screens/BlockedUsersView.swift` — Settings → Blocked Users, engel kaldırma.
- Engellenen kullanıcı feed, arama, aktivite ve tüm inceleme listelerinden süzülüyor
  (`SupabaseManager.blockedUserIds()`, 60 sn cache).
- **Moderasyon manuel:** `select * from content_reports where status = 'pending' order by created_at;`

### 3. Hesap silme sunucu adımı
- `supabase/functions/delete-user/index.ts` yazıldı (çağıranı kendi token'ından doğrulayıp
  sonra service-role'e yükseliyor). `deleteAccount()` önce bunu deniyor, yoksa eski istemci
  yoluna düşüyor. **Deploy edilmedi.**

### 4. Navigasyon: sekmeye tekrar basınca köke dönme
- `Core/Navigation/AppRoute.swift` — dört sekmenin ilk seviye linkleri değer tabanlı
  navigasyona çevrildi (`NavigationLink(value:)` + `navigationDestination(for: AppRoute.self)`).
- **Neden:** `NavigationPath` sıfırlamak `NavigationLink(destination:)` ile açılmış sayfayı
  KAPATMIYOR (simülatörde doğrulandı). Değer tabanlı olunca kapatıyor.
- `TabReselectionState` ayrı bir observable — `TabBarScrollState`'e eklenseydi her scroll
  collapse'ında 4 ekran birden yeniden kurulurdu.
- Detay ekranlarının kendi içindeki linkler destination tabanlı kalabilir; alttaki view
  pop'lanınca üstündekiler de gidiyor.

### 5. Düzeltilen bug'lar
- **Kullanıcı aramasında wildcard sızması:** `searchUsers` `ilike` desenini escape etmiyordu;
  arama kutusuna `%` yazan biri tüm kullanıcıları çekiyordu. `literalPattern` bağlandı.
- **Yarım yıldız kayboluyordu:** `ArtistReviewRow`'da `rating / 2` tam sayı bölmesi 3.5 puanı
  3 yıldız çiziyordu. `star.leadinghalf.filled` ile düzeltildi.
- **Klavye kapanmıyordu:** `AddLogView`, albüm inceleme sheet'i ve `EditProfileView` dikey
  `TextField` kullanıyor (Return = yeni satır). Üçüne de klavye üstü **Done** butonu +
  boşluğa dokununca kapanma eklendi.

### Sonraki oturum için açık işler
- Cihazda test (yukarıdakilerin hiçbiri gerçek donanımda denenmedi).
- `avatars` bucket + storage policy'leri, RLS denetimi, artist_reviews migration.
- iPad kararı, `EditProfileView`'daki Türkçe hata mesajları (karışık dil).
- `SupabaseManager.blockedCache` düz `class` üzerinde mutable — strict concurrency'ye
  geçilirse actor'a taşınmalı.

---

## 30 Temmuz 2026 (2) — App Store hazırlık geçişi

Hepsi `xcodebuild` ile temiz derleniyor, hiçbiri cihazda test edilmedi. Commit'ler:
`e99e1ac`, `38385a3`, `07e7d23`, `96ab5f1`, `70d639e` — hepsi push'landı.

### Yapılandırma
- **`TARGETED_DEVICE_FAMILY = "1,2,7"` → `1`** ve `SUPPORTED_PLATFORMS` sadece iOS. Uygulama
  iPad + Mac + **Vision Pro** beyan ediyordu; her layout telefon-dikey. iPad ekran görüntüsü
  zorunluluğu da böylece kalktı.
- Yönelim sadece **portrait** (landscape beyan ediliyordu).
- `PrivacyInfo.xcprivacy`'den **`NSPrivacyCollectedDataTypeContacts` silindi** — o tip rehber
  demek, uygulama rehbere dokunmuyor. Takip grafiği zaten `UserID` altında.
- `AccentColor` colorset boştu (sistem vurguları maviye düşüyordu) → `#FF00FF`.
- Launch screen siyah (`LaunchBackground` colorset) + kökte `.preferredColorScheme(.dark)`.

### UGC / Guideline 1.2
- **Aktivite kartları ve `LogDetailView`'da rapor/engelle yolu yoktu** — ikisi de başkasının
  yorum metnini gösteriyordu. `.moderationActions` eklendi (`ActivityItem.reportedContentType`).
- Feed ve Aktivite kartlarına **görünür ⋯ butonu** (`showsAffordance`). Sadece uzun basma
  görünmez bir yol; "rapor mekanizması bulunamadı" en sık 1.2 ret gerekçesi.
- **Kullanıcı adı ve bio artık filtreden geçiyor** (`rejectProfanity`) — ikisi de herkese açık.
- `content_reports`: `status`/`content_type`/`reason` CHECK kısıtlı, insert policy `status`'u
  `'pending'`e sabitliyor. Anon key çıkarılabilir olduğu için istemci `'dismissed'` gönderip
  raporu triyajdan kalıcı olarak gizleyebiliyordu.
- **Şartlar/gizlilik/destek sayfaları yazıldı** (`docs/`), `LegalLinks.swift` üzerinden giriş
  ekranına ve Settings → About'a bağlandı. Öncesinde tıklanamaz düz metindi.

### Küfür filtresi — kritik false positive
`ı→i` ve `ş→s` katlaması yüzünden `"sik"` terimi **"sık"** ("sık sık dinliyorum") ve **"şık"**
("bu şarkı çok şık") kelimelerini reddediyordu. `"amina"` substring olarak **"stamina"** içinde
eşleşiyordu. İkisi de çıkarıldı; çekimli formlar (`siktir`, `sikeyim`, `sikerim`) kaldı.

### Doğruluk
- **`blockedCache` actor'a taşındı** ve sahibine (`user.id`) göre anahtarlandı. Düz mutable
  state'ti, üst üste binen sekme yüklemelerinden okunuyordu; çıkış yaptıktan sonra da hayatta
  kalıp bir sonraki hesabın feed'ini süzüyordu.
- **Başarısız blok sorgusu artık "engel yok" diye cache'lenmiyor** — şebeke gidince 60 saniye
  boyunca engellenen herkes geri geliyordu.
- **`deleteAccount` sadece fonksiyon gerçekten yoksa (404) fallback'e düşüyor.** Önceden her
  hata yutuluyordu: kullanıcıya "hesabın silindi" denip `auth.users` satırı hayatta kalıyordu.
- **PostgREST `*`'ı sunucu tarafında `%`'e çeviriyor**, bizim escape'imizden sonra. Desenler
  artık `_`'e eşliyor + `matches(_:_:)` ile kesinleştiriliyor; arama kutusu tamamen atıyor.
  `*` yazan biri hâlâ tüm kullanıcı tablosunu çekebiliyordu, ve `N*E*R*D` gibi bir isim aynı
  kullanıcının **başka** bir yorumunu update edip gerisini siliyordu.

### UI / erişilebilirlik
- `EditProfileView`'daki **Türkçe hata mesajları İngilizceye çevrildi**; fotoğraf yükleme hatası
  artık "Supabase" ve "storage bucket" demiyor.
- İki `TextField` tek `Bool` `@FocusState` paylaşıyordu → `enum Field` ile ayrıldı.
- İkon-only butonlara `accessibilityLabel` (önceden kod tabanında **0** adet vardı).
- Tab bar küçülünce başlık `opacity(0)` olup erişilebilirlik ağacından düşüyordu → etiket
  artık kapsayıcıda beyan ediliyor + `.isSelected` trait'i.
- `BlockedUsersView`: başarısız unblock tüm listeyi temizlenemez hata ekranına çeviriyordu.
- `UserProfileView`: `blockError` yazılıp hiç gösterilmiyordu.
- Servis logları `debugLog` ile Release'te derlenmiyor.

## 31 Temmuz 2026 — backend denetimi TAMAM

Management API ile denetlendi (`supabase login` token'ı üzerinden). **Backend tarafında açık iş
kalmadı:**

- **RLS yedi tabloda da açık** — `profiles`, `reviews`, `album_reviews`, `artist_reviews`,
  `follows`, `content_reports`, `user_blocks`.
- **Yazma policy'lerinin hiçbirinde `true` yok** — hepsi `auth.uid() = <owner>` ile kilitli.
  Silme policy'leri de var, yani hesap silme gerçekten satırları kaldırabiliyor.
- `artist_reviews` **zaten oluşturulmuş** (migration dosyası artık gereksiz).
- `avatars` bucket var, **public**, SELECT/INSERT/UPDATE/DELETE policy'leri tam.
- Unique constraint'ler ve indeksler **uygulanmış**; kopya satır sayısı dört tabloda da **0**.
- `delete-user` Edge Function **deploy edildi** ve doğrulandı (yetkisiz çağrı 401).
- `content_reports` sıkılaştırması **uygulandı**: `status`/`content_type`/`reason` CHECK kısıtlı
  ve insert policy `status`'u `'pending'`e sabitliyor.
- `docs/` sayfaları GitHub Pages'te **canlı** (üçü de 200).

> Fazlalık: `follows`, `profiles` ve `reviews`'ta aynı koşulu tekrarlayan mükerrer policy'ler
> var (ör. `reviews` için 3 ayrı DELETE policy'si). Postgres bunları OR'ladığı için davranış
> doğru, sadece kalabalık. Temizlemek isteğe bağlı, aciliyeti yok.

### Senden kalan işler
- **Cihazda test** — hiçbir şey gerçek donanımda denenmedi (özellikle hesap silme, tek
  kullanımlık hesapla)
- Ekran görüntüleri (cihazdan — simülatörde MusicKit boş)
- App Store Connect metinleri (`APP_STORE_CONNECT.md`) + build yükleme
- Doğrulanmış bir demo hesabı (Confirm email açık)

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
