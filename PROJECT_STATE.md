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

---

## 2 Ağustos 2026 — App Store Connect dolduruldu, build yüklendi

App Store Connect API ile (key `22H7A52C65`, App Manager yetkisi) yapıldı:

- Subtitle, description, keywords, promotional text, support + privacy URL, copyright
- Kategoriler: **Music** / **Social Networking**
- Content Rights: **USES_THIRD_PARTY_CONTENT** (MusicKit kapak + preview gösteriliyor)
- Yaş sınırı beyanı: `matureOrSuggestiveThemes` ve `profanityOrCrudeHumor` = Infrequent/Mild,
  `userGeneratedContent` = true, `socialMedia` = true, geri kalan hepsi None/false
- App Review Information: ad, telefon, e-posta, 1739 karakterlik review notu
- **Build 1.0 (1) yüklendi, işlendi (VALID) ve sürüme bağlandı**

### İmzalama — PC değişikliğinin kalıntısı çözüldü
Hesapta bir `iOS Distribution` sertifikası vardı ama **özel anahtarı eski bilgisayarda** kaldı,
bu yüzden arşiv App Store için yeniden imzalanamıyordu (`Cloud signing permission error`).
Bu Mac için yenisi üretildi:

- Sertifika `V32J9SMM8B` — *iPhone Distribution: Berkay CEFAKAR*, keychain'de kurulu
- Profil `84Z2JN5QDR` — *Spectrum App Store 2026*, `IOS_APP_STORE`, Sign in with Apple
  entitlement'ını içeriyor (App ID'nin doğru yapılandırıldığının kanıtı)
- API key ayrıca `~/.appstoreconnect/private_keys/` altına kopyalandı (`altool` orada arıyor)

> **Yedek al:** yeni dağıtım sertifikasının özel anahtarı sadece bu Mac'in keychain'inde.
> Keychain Access → "iPhone Distribution: Berkay CEFAKAR" → sağ tık → Export → `.p12`.
> Bu dosya olmadan başka bir bilgisayarda App Store build'i imzalayamazsın.

### Senden kalan işler
- **Ekran görüntüleri** — App Store Connect'te 0 set var, zorunlu. Cihazdan çek
  (simülatörde MusicKit boş döner)
- **App Privacy anketi** — API'de endpoint'i yok, panelden: Email Address, User ID,
  Photos or Videos, Other User Content; hepsi "Linked: Yes", "Tracking: No"
- **Demo hesabı** — Confirm email açık olduğu için doğrulanmış olmalı.
  `berkaycefakar+demo@icloud.com` gibi bir + takma adı işe yarar
- **Cihazda test** — hiçbir şey gerçek donanımda denenmedi (özellikle hesap silme,
  tek kullanımlık hesapla)

---

## 26 Eylül 2026 — eksik kapatma turu

Submit işleri bilerek ertelendi; bu tur tamamen ürün ve kod eksiklerine ayrıldı. **Her adımda
`xcodebuild` temiz derledi, build artık SIFIR uyarı veriyor.** Cihazda test edildiği teyit
edildi (kullanıcı beyanı).

### Test altyapısı: 0 → çalışan suite
`SpectrumTests.swift` boş Xcode şablonuydu. Silindi, yerine dört dosya:
`ProfanityFilterTests`, `QueryPatternTests`, `ModelTests`, `ListeningStatsTests`.
Hepsi geçmişte gerçekten yaşanmış bug'ların regresyonu.

> **Test, canlı bir açık buldu:** Türkçe `İ` (U+0130) `lowercased()` ile `i` + U+0307
> (birleşen nokta) oluyor. `ProfanityFilter.normalize` önce küçültüp sonra folding tablosuna
> baktığı için `"İ": "i"` satırı **hiç çalışmıyordu** — `SİKTİR` "si̇ktir"e dönüşüp filtreden
> geçiyordu. Yani **caps yazmak küfür filtresinin tamamını bypass ediyordu.** `normalize`
> artık Foundation'ın `.caseInsensitive + .diacriticInsensitive` folding'ini önce uyguluyor;
> `sık`/`şık` false-positive koruması caps'te de doğrulandı.

### Düzeltilenler
- **Paylaşım Spotify'a gidiyordu.** `spotify:search:...` bir URI şeması: Messages/WhatsApp'ta
  tıklanabilir link değil, alıcıda Spotify yoksa ölü, ve tüm veri Apple Music'ten gelirken
  rakibe yönlendiriyordu. `Track.appleMusicUrl` MusicKit'in kanonik `song.url`'ünden
  doldu, `music.apple.com/song/<id>` fallback'i var. Elle `UIActivityViewController`
  sunumu da `ShareLink`'e çevrildi — eski kod `connectedScenes.first`'e uzanıyordu, bu
  ekran bir sheet içindeyken paylaşım **sessizce hiç açılmıyordu.**
- **15 çıplak `print(` → `debugLog`.** `DebugLog.swift` yazılmıştı ama sadece servis
  katmanına uygulanmıştı; 9 View dosyası Release'te de konsola yazıyordu.
- **`ArtistDetailView` bomboş sayfa**: id lookup + isim araması ikisi de patlarsa hiçbir şey
  yoktu. "Couldn't load this artist" + Try Again eklendi.
- **`SpotifyCredentials.txt` silindi.** ⚠️ Dosya gitti ama **anahtar hâlâ geçerli** —
  Spotify panelinden secret'ı iptal et.
- **3 derleme uyarısı kapandı.** Proje `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  kullanıyor, bu yüzden saf yardımcılar arka plan bağlamından çağrılınca uyarı veriyordu
  (Swift 6'da hata olacaklardı): `ProfanityFilter` ve `Album.newestFirst` artık
  `nonisolated`. `URLQueryRepresentable` → `PostgrestFilterValue`.
- **`SupabaseManager` artık `final`** (default argümanda `Self` kullanılamıyordu).

### Pagination — üç ekranda
`SupabaseManager.pageSize = 30`. Profil sorguları `.range()` alıyor ve **benzersiz
tie-break**'le sıralı (`rating → created_at → id`): rating 0-10 olduğu için eşitlik kural,
tie-break olmadan sayfalar arası satır hem tekrarlanır hem kaybolur. Feed
`ReviewPage { reviews, hasMore }` döndürüyor; `hasMore` **sunucunun** döndürdüğü satır
sayısına bakıyor, filtreden geçenlere değil — yoksa tamamı engelli kullanıcılardan oluşan
bir sayfa "feed bitti" gibi görünürdü.

Sayfalamanın açığa çıkardığı iki sessiz hata:
- Sekme sayıları `reviews.count`'tan geliyordu → "yüklenen kadar" demeye başlardı.
  `countUserLogs` (head request) eklendi.
- "Your Spectrum" grafiği ve ortalama puan da yüklü sayfadan hesaplanıyordu → sessizce
  "son 30 logun özeti" olurdu. `fetchUserLogSummary` sadece `vibe_color,rating,created_at`
  çekiyor.
- Client tarafı `sorted` kaldırıldı: sayfa 2'nin 5 yıldızı ekrandaki 3 yıldızın üstüne
  zıplıyordu. Sıralama artık sunucuda.

### Beğeni sistemi
`Supabase_migration_review_likes.sql` — tek polimorfik tablo, RLS (okuma herkese,
yazma/silme `auth.uid()`), tekil indeks (çift dokunuş 23505 → "zaten beğenilmiş"),
`review_like_counts` RPC'si (PostgREST `group by` yapamıyor; popüler bir log'un her
kaydırmada beğeni başına bir satır indirmesini engelliyor), silinen log'un beğenilerini
temizleyen üç trigger. İstemci tarafı: `LikeButton` + `HapticFeedback` (tek hazırlanmış
generator), iyimser toggle (kalp dokunuşla aynı karede döner, sadece yazma patlarsa geri
alınır), feed sayfa başına tek istekle tüm durumları çekiyor, kendi logunda kalp gizli.
`deleteAccountClientSide` verilen beğenileri de siliyor.

> 🔴 **SENDE:** `Supabase_migration_review_likes.sql`'i SQL Editor'de çalıştır. Çalışana
> kadar kalpler görünür ama sayı 0 kalır ve dokunuş sessizce geri alınır.

### Discover gerçek verilere bağlandı
`MusicService.fetchTopSongs` / `fetchTopAlbums` (`MusicCatalogChartsRequest`). 15
sanatçılık sabit tohum havuzu **silindi** — her yeni kullanıcı aynı altı şarkıyı
görüyordu. Yeni "Top Charts" yatay satırı + topluluk logları "Logged Recently".
Hiçbir şey yapmayan "See All" butonu kaldırıldı (`TODO: Navigate to full list` idi).

### MusicKit'te bedava duran alanlar
Hepsi zaten yapılan isteklerle geliyordu: albüm sayfasında **Explicit / Dolby Atmos /
Lossless / Hi-Res** rozetleri + "plak şirketi · yıl · N şarkı" satırı
(`CatalogBadges.swift`), şarkı sayfasında **besteci** ("Written by…", sanatçıyla aynıysa
gizli) ve Explicit, sanatçı sayfasında **Latest Release** kartı.
Not: `MusicKit.Track` (Song ∪ MusicVideo) `composerName` taşımıyor — albüm parça
listelerinde besteci yok, şarkının kendi sayfasında var.

### Mini-player
`AudioManager` artık `currentTrack` yayınlıyor. Tab bar'ın üstünde kapsül: kapak, başlık,
play/pause, kapat; dokununca şarkının sayfasını sheet olarak açıyor. **`TrackDetailView`
artık `onDisappear`'da sesi durdurmuyor** — mini-player varken sayfadan çıkmak sesi kesen
tek eylem olurdu. Çıkış yapınca ses susuyor (`SessionStore.signOut`).

### Bildirim rozeti (push değil)
Gerçek push APNs anahtarı + DB yazmalarına tepki veren bir sunucu ister; ikisi de yok.
Yapılabilen kısım yapıldı: `ActivityBadgeStore` + `latestActivityTimestamp` (üç adet
`limit 1` okuma) → uygulama öne gelince Activity sekmesinde nokta. "Görüldü" işareti
`UserDefaults`'ta **kullanıcı id'sine göre** (aynı telefonda ikinci hesap birincinin
durumunu devralmasın) ve `now` yerine **o fetch'in bildiği en yeni timestamp**'e
ayarlanıyor — saat kullanmak, fetch ile dokunuş arasında yazılanı sessizce okundu yapardı.

### Dynamic Type — iddia değil, doğrulama
60 sabit `.system(size:)`in sadece 8'i metin, gerisi ikon. Metin olanlar `@ScaledMetric`'e
çevrildi (Activity başlığı, log başlığı, sanatçı adı). Sabit yükseklikli chrome (tab bar,
mini-player) `dynamicTypeSize(...xxLarge)` ile sınırlandı.

> **Simülatörde AccessibilityXXXL ile doğrulandı ve gerçek bir taşma buldu:** LandingView'da
> tagline 3 satıra çıkıp "Spectrum" wordmark'ını durum çubuğunun/Dynamic Island'ın altına
> itiyordu. `VStack` + `Spacer()` taşamaz, sadece kırpar. `GeometryReader` + `ScrollView` +
> `frame(minHeight:)` yapıldı — normal boyutlarda ortalama aynı, büyük boyutta kayıyor.
> Ekran görüntüleriyle önce/sonra doğrulandı.

### Yeni: istatistik ekranı ve paylaşım kartı
- **`ListeningStatsView`** — profildeki "Your Spectrum" bloğu artık tıklanabilir. Toplam
  log, ortalama, gün serisi, renk dağılımı (tek spektrum çubuğu), puan histogramı, son 12
  ay. Tamamı `ListeningStats` saf değer tipinde ve test edilmiş. **Bilerek sanatçı
  istatistiği yok:** bir ömürlük track id'yi isme çevirmek yüzlerce katalog isteği demek.
- **`ShareCard`** — log'u 1080×1080 karta çeviriyor (kapak, yıldız, vibe rengi, yorum,
  @kullanıcı adı), `ImageRenderer` ile ekran dışında. Log sayfasında paylaş butonu; görsel
  + Apple Music linki birlikte gidiyor. `AsyncImage` değil `Image(uiImage:)` — renderer
  senkron çalışır ve placeholder'ı yakalardı.

### Listeler — Letterboxd'un en ayırt edici özelliği
`Supabase_migration_lists.sql`: `lists` + `list_items`, manuel sıralamalı (`position`) ve
kayıt başına not alanlı. Varsayılan **private** — kullanıcının yazdığı bir şey, sahibi aksini
söyleyene kadar taslaktır.

RLS'in dikkat edilen yeri: `list_items` SELECT policy'si `exists (... lists ...)` ile
ebeveynine bakıyor. Bu olmasa bir item satırı kendi başına okunabilirdi ve istemci
`list_items`'ı doğrudan tarayıp **birinin yayınlanmamış listesini yeniden kurabilirdi.**

Ayrıca: `list_item_counts` RPC'si (on listeli bir profil, on sayı yazdırmak için hepsinin
bütün içeriğini indirmesin), item değişince ebeveynin `updated_at`'ini güncelleyen trigger
(profil `updated_at`'e göre sıralı; "son güncellenen" listeye kayıt eklemeyi de kapsamalı).

İstemci: profilde Lists bölümü (kendi profilinde private'lar da, başkasınınkinde sadece
public — **filtreleme istemcide değil RLS'te**, anon key IPA'dan çıkarılabiliyor),
`ListDetailView` (sürükle-bırak sıralama, kaydırıp silme, iki toplu MusicKit isteğiyle
çözümleme), `EditListView`, şarkı/albüm/sanatçı sayfalarında **Add to List**.

`reorderList` bilerek satır satır UPDATE yapıyor, toplu upsert değil: `list_items`'ta bu
payload şekli için conflict target yok ve bu, inceleme tablolarının düştüğü tuzağın aynısı —
oradaki upsert sessizce kopya satır ekliyordu.

`rejectProfanity` genelleştirildi (`context:` parametresi): mesaj koşulsuz "your profile"
diyordu, liste başlığı için yanlıştı.

### Kararlar (26 Eylül, kullanıcı onayı)
- **Türkçe + İngilizce yapılacak.** ~190 benzersiz kullanıcı metni. Altyapı kuruldu:
  `Spectrum/Localizable.xcstrings`, `SWIFT_EMIT_LOC_STRINGS = YES` (6 hedef yapılandırması),
  `knownRegions`'a `tr`. **Yarım bırakılmayacak** — karışık dil hiç çeviri yapmamaktan kötü.
- **Crash reporting ertelendi.** 1.0 sonrasına. Eklenince `PrivacyInfo.xcprivacy` ve App
  Privacy anketi de güncellenmeli.

### Türkçe yerelleştirme — tamamlandı
`Spectrum/Localizable.xcstrings` (205 anahtar) + `Spectrum/SpectrumInfoPlist.xcstrings`.
**200 çeviri + 11 çevrilmeyecek format/marka dizesi, eksik sıfır.** Kod değişmedi: SwiftUI'da
`Text("literal")` zaten kataloğa bağlanıyor, `NSLocalizedString` sarmalamaya gerek yok.

Ayarlar: `SWIFT_EMIT_LOC_STRINGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = NO`,
`knownRegions`'a `tr`. Altı yapılandırmanın her birinde **tam bir kez** — Xcode bu iki
anahtarı zaten tanımlamıştı, ilk denemede aynı sözlüğe çakışan ikinci kopyalar eklenmişti,
temizlendi.

> **Sembol üretimi neden kapalı:** katalog her anahtarı bir Swift tanıtıcısına çeviriyor ve
> bu burada mümkün değil — on bir anahtar saf format dizesi (`%lld`, `/ %lld`, `·`), tanıtıcı
> türetilecek harf yok. Üretilen semboller zaten hiçbir yerde kullanılmıyor.

**Bu arada kaynakta beş çift ikiz metin tekilleştirildi** (yalnızca büyük/küçük harfle
ayrılan anahtarlar aynı sembolü üretip derlemeyi kırıyordu): `Add to list`→`Add to List`,
`New list`→`New List`, `No Activity Yet`→`No activity yet`, `Play preview`→`Play Preview`.
Sabit büyük harfli başlıklar (`ARTIST`, `USERNAME`) `.textCase(.uppercase)`'e çevrildi —
bu zaten doğru biçim: **Türkçe'de büyük harfe çevirme yerele bağlı** (i→İ) ve elle yazılmış
ASCII "ARTIST" bunu hiçbir zaman veremez.

### Bu turda YAPILMAYAN, sende kalan
1. **`Supabase_migration_review_likes.sql` çalıştırılacak.**
2. **`Supabase_migration_lists.sql` çalıştırılacak.** Çalışana kadar Lists bölümü boş görünür
   ve liste oluşturma hata verir.
3. **Spotify client secret iptal edilecek** (dosya silindi, anahtar hâlâ geçerli).

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
