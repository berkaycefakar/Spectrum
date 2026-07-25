# Spectrum — Devir / Handoff Özeti

> Yeni bir sohbet oturumu bu dosyayı okuyarak bağlamı devralır. Strateji (güvenlik/çıkış/para
> kazanma) notları için `SPECTRUM_NOTES.md`'ye bak.

## Proje nedir
- **Spectrum** = "müzik için Letterboxd". Kullanıcılar şarkı/albüm/sanatçı loglar, puanlar,
  yorum yazar, bir "vibe" rengi seçer; başkalarını takip edip feed'de görür.
- **Gerçek proje konumu: `~/Desktop/Spectrum`** (`~/projects/Spectrum` DEĞİL — orası eski/ölü
  iTunes denemesi).
- Platform: **iOS 17+**, SwiftUI. Bundle id `berkay.Spectrum`, team `8ZCY68284F`.
- Xcode projesi **synchronized file groups** (objectVersion 77) kullanıyor — yeni .swift
  dosyaları otomatik derlemeye girer, pbxproj'a elle ekleme gerekmez.
- Git: `origin = github.com/berkaycefakar/Spectrum`, branch `main` (solo repo, doğrudan main'e
  push ediliyor). Son iş 10 ayrı commit halinde push edildi.

## Mimari
- **Müzik verisi: Apple MusicKit** (`Spectrum/Services/MusicService.swift`). iTunes Search API
  terk edildi (`iTunesService.swift` ölü kod, duruyor). Katalog arama/lookup için MusicKit
  authorization ŞART — Simülatörde çalışmaz, **gerçek cihaz gerekir**. App ID'de MusicKit
  servisi açık. Abonelik gerekmez (arama/artwork/preview ücretsiz; sadece tam şarkı çalma
  abonelik ister — uygulama onu kullanmıyor).
- **Backend: Supabase** (`Spectrum/Services/SupabaseManager.swift`). Koddaki anahtar `anon`
  (gömülmesi normal). Tablolar: `profiles`, `reviews`, `follows`, `album_reviews`,
  `artist_reviews`. Güvenlik tamamen RLS'e bağlı.
- Modeller: `Track` (artık `artists: [ArtistRef]` çoklu sanatçı destekli), `Album`, `Artist`,
  `Review`, `AlbumReview`, `ArtistReview`, `Profile`.
- Renk sistemi: `Core/Extensions/ArtworkColor.swift` — artwork'ün baskın canlı rengini
  **arka planda** (actor, main thread DEĞİL) çıkarır; nötr artwork'e mor yerine nötr ton verir.

## Bu ana kadar yapılan iş (hepsi derlendi, `main`'e push'landı)
1. MusicKit'e tam geçiş doğrulandı; boş feed/arama sebebi Simülatör + yutulan hatalardı.
2. Dinamik artwork renkleri (mor fallback bug'ı düzeltildi); ana-thread donması düzeltildi
   (ArtworkColorLoader artık `actor`).
3. Track↔Albüm↔Sanatçı çapraz gezinme. Çoklu sanatçı: her sanatçı ayrı tıklanabilir (FlowLayout).
4. Track ekranında oynat tuşu = albüm kapağı rengi.
5. Sanatçı sayfası Spotify tarzı tam-genişlik kare hero.
6. Log ekranı (AddLogView) tek ekrana sığar + daha büyük kapak; log **düzenle/sil** eklendi.
7. Profil: avatar yükleme (PhotosPicker→Supabase Storage), Cancel butonu, kullanıcı adı
   doğrulaması; ölü "Settings" butonu → gerçek `SettingsView`; sanatçı logları sekmesi açıldı.
8. Discover: gerçek "trending" (topluluğun son logladıkları) + rotasyonlu vibe havuzu; vibe
   tıklama artık müzikal sorgu aratıyor (ör. "Late Night Drive" → `synthwave`).
9. Activity: başlık + zaman gruplaması (Today/This Week/Earlier) + yeniden tasarlanmış kartlar
   (tür rozeti, tipografi, gölge).
10. Performans: feed/profil detayları tek toplu MusicKit isteğiyle (N+1 kaldırıldı); URLCache
    büyütüldü (artwork tekrar tekrar indirilmiyordu).
11. App icon (mor neon prizma), markalaşma (`SpectrumBranding.swift`: SpectrumMark/Wordmark/
    SplashView), açılışta splash screen, beyaz "Spectrum" feed başlığı (gökkuşağı yazı kaldırıldı).

## Son oturumda yapılanlar (derlendi, henüz commit EDİLMEDİ, cihazda test EDİLMEDİ)

### Topluluk puanları
- Yeni `UI/Components/CommunityStatsView.swift`: `VibePalette` (8 vibe hex + isim + en yakın
  ton eşleme), `CommunityStats` (ortalama puan, kişi sayısı, renk dağılımı), `CommunityStatsCard`.
- Şarkı / albüm / sanatçı sayfalarının üçünde de: **ortalama puan, kaç kişi puanladı, en çok
  verilen vibe rengi** + dağılım çubuğu. Sanatçı sayfasında topluluk bölümü hiç yoktu.
- Albüm logu vibe rengini `#FFCC00` olarak SABİT kaydediyordu → prism picker eklendi, artık
  gerçek veri. Eski albüm kayıtları hâlâ sarı görünür.

### Kaydetme katmanı (kritik)
- `saveReview`/`saveAlbumReview`/`saveArtistReview` artık `upsert(onConflict:)` KULLANMIYOR.
  Eski hâli iki ayrı bug üretiyordu:
  - `reviews`: unique index olmadığı için Postgres `"no unique or exclusion constraint
    matching the ON CONFLICT specification"` fırlatıyordu → şarkı loglamak hata veriyordu.
  - `album_reviews`: conflict target yoktu → primary key'e düşüyor, payload'da `id` olmadığı
    için **her kayıt yeni satır** ekliyordu. Düzenleme çalışmıyor, kopya satırlar birikiyordu.
- Yeni akış: satırı bul → varsa **update**, yoksa **insert**; eski kopyaları best-effort siler
  (bu temizlik başarısız olsa bile kayıt düşmez). **Artık hiçbir SQL migration'a bağımlı değil.**
- Sanatçı adı eşleşmesi `.eq` (harf duyarlı) idi → `ilike` (harf duyarsız, `%`/`_`/`\` escape'li).
  "Daft Punk" ve "daft punk" artık aynı sanatçı.

### Özellikler
- **Similar Artists** — `MusicKit.Artist.similarArtists`, sanatçı sayfasında yuvarlak fotoğraflı
  yatay satır. Boşsa gizleniyor.
- **Albümler en yeniden eskiye** — `Album.newestFirst` (tarihsizler sonda, eşitlik başlıkla
  bozuluyor), sıralama kırpmadan ÖNCE yapılıyor ki tutulan 20 albüm gerçekten en yeniler olsun.
- **Tür sayısı** — `combinedGenres`: sanatçının kendi türleri önde, top şarkı/albüm türleri
  sıklığa göre ekleniyor, Apple'ın "Music" üst türü eleniyor, max 8. (1 tür yerine 4-6.)
- **Apple Music izni reddedilirse** — `MusicAuthorizationStore` + `MusicAccessView`: ne bozulduğu,
  abonelik gerekmediği anlatılıyor, Settings'e deep link, öne gelince izin yeniden okunuyor.
- **Hesap silme** — `SettingsView` → onay → `SupabaseManager.deleteAccount()` (loglar, follow
  grafiği iki yönlü, avatar, profil satırı, sonra signOut). App Store için ZORUNLU.

### Düzeltilen diğer buglar (detay: `APP_STORE_READINESS.md` §2)
- `AudioManager` `AVAudioSession`'ı **init'te** aktive ediyordu → uygulamayı açmak, kullanıcının
  o an dinlediği müziği susturuyordu. Artık sadece preview çalarken aktive/serbest bırakılıyor.
- `SearchDiscoveryView`: 4 arama tek tuple'da await ediliyordu, biri patlayınca **dördü birden**
  çöpe gidiyordu (Apple Music izni yoksa kullanıcı araması da boş dönüyordu). Artık bağımsız.
- `ArtistDetailView` rating her `onChange`'de kaydediyordu; sürüklerken ilk adım kaydediliyor,
  gerisi `isSaving` guard'ında sessizce düşüyordu → 550 ms debounce + `persistedRating` guard.
- `SessionStore.signOut` hata alınca `currentUser`'ı temizlemiyordu → çıkış yapılamıyordu.
- `UserProfileView` Artists sekmesi `count: 0` hardcode'du → başkalarının sanatçı logları görünmüyordu.
- `EditProfileView` sessiz `return` → spinner sonsuza kadar dönüyordu.
- Sıralamalar: `sorted(by:)` stabil değil → `createdAt` tie-break; arama comparator'ı geçerli
  bir strict weak ordering değildi → integer rank.
- `ActivityView`'a `.refreshable` (yeni takipçiler ancak yeniden başlatınca görünüyordu).
- Detay sayfalarındaki ardışık `await` zincirleri `async let` ile paralelleştirildi.
- Ölü `iTunesService.swift` silindi.

### App Store hazırlığı
- `IPHONEOS_DEPLOYMENT_TARGET` **26.2 → 17.0**. Bu hâliyle uygulama neredeyse hiçbir cihaza
  kurulamazdı — tek başına en kritik bulgu.
- `PrivacyInfo.xcprivacy` eklendi (paketlendiği doğrulandı), `ITSAppUsesNonExemptEncryption = NO`.
- **`APP_STORE_READINESS.md`** — 489 satırlık tam rapor: sıralı engeller, RLS policy seti +
  audit script'i, App Privacy anket cevapları, Edge Function SQL'i, mağaza metinleri listesi.

### Giriş / kayıt ekranı (son oturum)
- **Hata mesajları hiç görünmüyordu — kök sebep bulundu.** `SessionStore.signIn/signUp`
  global `isLoading`'i true yapıyordu; `ContentView` ise `isLoading` true iken `SplashView`
  gösteriyor. Yani "Log In"e basar basmaz `AuthView` ekrandan siliniyor, hata artık var olmayan
  bir view'a yazılıyor, istek bitince SwiftUI **yepyeni ve boş** bir `AuthView` kuruyordu.
  Artık `isLoading` sadece "açılışta oturum geri yükleniyor" demek; form kendi local state'ini
  kullanıyor.
- `AuthErrorMessage` (yeni): Supabase/URLSession hatalarını insan diline çeviriyor (yanlış şifre,
  onaylanmamış e-posta, kayıtlı e-posta, kısa şifre, rate limit, çevrimdışı). Ayrıca gönderim
  öncesi istemci tarafı doğrulama — boş alan/geçersiz e-posta anında cevap veriyor.
- **Şifremi unuttum** — `PasswordResetView` sheet'i + `resetPasswordForEmail`. Mesaj, adresin
  kayıtlı olup olmadığını sızdırmayacak şekilde yazıldı.
- **Kayıt olunca doğrudan giriş** — `signUp` artık `SignUpOutcome` döndürüyor. Session varsa
  direkt içeri; Supabase'de "Confirm email" açıksa session gelmiyor, o zaman net bir mesaj
  gösteriliyor (eskiden profil satırı RLS'e takılıp hata veriyordu, hesap açılmış olmasına rağmen).
- **Apple ve Google ile giriş** — `SignInWithAppleButton` + `signInWithIdToken` (nonce'un raw
  hâli Supabase'e, SHA-256 hash'i Apple'a gider; karıştırmak en sık hata). Google, ekstra
  bağımlılık gerektirmeyen `signInWithOAuth` web akışıyla. `ensureProfile` her giriş yolunda
  profil satırını garantiliyor (sosyal girişte kullanıcı adı yok, e-postadan türetiliyor).
- **Buton dokunma alanları** — `.frame/.padding/.background` Button'ın *dışına* uygulandığında
  sadece çizim büyüyor, dokunma alanı yazı kadar kalıyordu. 4 gerçek yerde düzeltildi
  (AddLogView ×2, EditProfileView, FeedView) + AuthView/LandingView yeniden yazıldı.
  Kalan `.padding`'ler sadece kenar boşluğu, sorun değil.
- **Landing ekranı** — tasarım DEĞİŞMEDİ (kullanıcı mevcut tasarımı beğeniyor). Sadece kırık
  olan iki URL düzeltildi: hem albüm kapağı hem preview 2020'den kalma sabit adreslerdi ve
  **ikisi de 404 dönüyordu** (curl ile doğrulandı) — yani yeni kullanıcının gördüğü ilk şey
  gri bir kutuydu ve oynat tuşu hiçbir şey yapmıyordu. Güncel adresler kondu, üstüne
  `refreshDemoTrack()` ile çalışma zamanında **public iTunes lookup**'tan tazeleniyor
  (MusicKit değil: bu ekran login ve izin isteğinden ÖNCE geliyor, MusicKit orada çalışmaz).
  Apple dosyaları yine taşırsa ekran kendini onarır.
- **Preview gecikmesi** — `AVAudioSession.setCategory/setActive` main actor'da senkron
  çalışıyordu; bir process'teki **ilk** çağrı mediaserverd'e IPC olduğu için yüzlerce ms
  sürüyor ve o süre boyunca arayüz donuyordu. Artık seri bir arka plan kuyruğunda.
  Ayrıca `isBuffering` eklendi (`timeControlStatus`'tan): eskiden ikon anında "pause"a
  dönüp saniyelerce sessiz kalıyordu, şimdi spinner dönüyor. `automaticallyWaitsToMinimizeStalling
  = false` — 30 sn'lik preview için erken başlamak, hiç takılmamaktan iyi.
- **Google butonu** — `globe` SF Symbol'ü "herhangi bir web sitesi" gibi duruyordu; SF
  Symbols'ta Google glifi yok. `GoogleGMark` ile dört renkli "G" çizildi (halka + mavi
  çubuk). **Yayın öncesi:** Google'ın Identity Guidelines'ı kendi resmî asset'lerini şart
  koşuyor — resmî SVG/PDF'i asset kataloğuna koyup bunu değiştir.

## KULLANICININ YAPMASI GEREKENLER
> Tam liste ve hazır SQL/kod için **`APP_STORE_READINESS.md`**'ye bak. Özet:

1. **RLS doğrulaması** — tüm tablolarda RLS açık mı, policy'ler doğru mu (§7'de audit script'i
   ve gereken tam policy seti var). Uygulamanın TÜM güvenliği buna bağlı. En kritik iş.
2. **Hesap silme Edge Function'ı** (§1.2) — uygulama içi silme kullanıcının tüm verisini siliyor
   ama `auth.users` satırını silemiyor (service-role key uygulamaya GÖMÜLMEZ). Apple bunu bekliyor.
3. **UGC gereksinimleri** (§8) — içerik bildirme, kullanıcı engelleme, küfür filtresi. Hesap
   silmeden sonra **en olası ikinci ret sebebi**, henüz kodda YOK.
4. **artist_reviews tablosu** (`Supabase_migration_artist_reviews.sql`) ve **avatars bucket**
   (Public + policy) hâlâ gerekli.
5. **iPad kararı** (§3.2) — uygulama iPad desteği beyan ediyor ama arayüz sadece telefon-dikey.
   Ya iPad'i kapat ya da düzenle; aksi hâlde ret riski.
6. ~~Mükerrer log unique constraint'i~~ — **artık gerekmiyor**, kod constraint'siz çalışıyor.
   (Yine de eklemek istersen veri bütünlüğü için faydalı, ama zorunlu değil.)

### Apple / Google girişi için panel ayarları (kod hazır, ayarlar yapılmadı → şu an ÇALIŞMAZ)
> **Adım adım tam rehber: `AUTH_SETUP.md`.** Aşağısı sadece özet.
>
> Ayrıca düzeltildi: `spectrum://` URL şeması bundle'da **hiç kayıtlı değildi**
> (`CFBundleURLTypes` yoktu) — yani e-posta onay ve şifre sıfırlama linkleri uygulamayı
> açamıyordu. `SpectrumInfo.plist` eklendi (`INFOPLIST_FILE`), üretilen anahtarların
> hepsinin korunduğu build çıktısından doğrulandı. Dosya bilerek sync klasörünün DIŞINDA:
> içine konduğunda synchronized file group onu hem Info.plist hem resource olarak alıp
> "Multiple commands produce" hatası veriyor.
7. **Apple Developer portal** → Identifiers → `berkay.Spectrum` → **Sign In with Apple**'ı işaretle.
   (Kodda entitlement eklendi: `Spectrum/Spectrum.entitlements`. Portal'da açılmazsa imzalama
   hata verir.)
8. **Supabase → Auth → Providers → Apple**: aç. Bundle id `berkay.Spectrum` yeterli (native
   akış kullanıyoruz, Services ID + secret key sadece web akışı için gerekli).
9. **Supabase → Auth → Providers → Google**: aç, Google Cloud Console'dan OAuth Client ID +
   Secret gir. Google Cloud'da "Authorized redirect URI" olarak Supabase'in verdiği
   `https://ysgbqlltzdhgsezukxxm.supabase.co/auth/v1/callback` adresini ekle.
10. **Supabase → Auth → URL Configuration → Redirect URLs**: `spectrum://auth-callback`
    listede olmalı. Hem Google akışı hem şifre sıfırlama linki buna dönüyor.
11. **"Confirm email" kararı** (Auth → Providers → Email): **kapalıysa** kayıt olan kullanıcı
    doğrudan içeri girer (istediğin davranış). Açık bırakırsan uygulama artık bunu düzgün
    yönetiyor ama kullanıcı önce e-postasını onaylamak zorunda kalır.
12. **Şifre sıfırlama linki** `spectrum://auth-callback`'e döner ve uygulamayı açar; ancak
    **yeni şifreyi girecek ekran henüz YOK**. Şu an link uygulamayı açar ve oturum kurar.
    Tam akış için bir "yeni şifre belirle" ekranı gerekiyor — yapılmadı.

## DOĞRULANMADI / RİSKLER
- **Son oturumun hiçbir değişikliği cihazda test edilmedi.** Öncelikli test listesi: albümü iki
  kez kaydedip renginin gerçekten değiştiği (ve eski kopya satırların temizlendiği), rating'siz
  save uyarısı, similar artists satırı, albümlerin en yeniden sıralanması, hesap silme akışı
  (geri dönüşü YOK — önce tek kullanımlık bir hesapla dene), Apple Music iznini reddedip
  açıklama ekranının çıkması, preview çalarken arkadaki müziğin susmaması.
- **Karışık dil**: `EditProfileView` hata mesajları Türkçe, uygulamanın geri kalanı İngilizce.
  Mağazaya çıkmadan birine karar verilmeli.
- `MusicAuthorizationStore` Simülatörde de "izin yok" ekranını gösterebilir (Simülatörde Media &
  Purchases hesabı yok) — bu doğru davranış ama test ederken şaşırtmasın.
- Tüm değişiklikler **derlendi** ama **cihazda görsel doğrulama YAPILMADI**. Cihazda test edilecekler:
  splash animasyonu, yeni Activity kartları, vibe aramasının sonuç döndürmesi, çoklu sanatçı
  satırı, log düzenle/sil akışı, avatar yükleme (bucket kurulduktan sonra), AddLogView'in küçük
  ekranda (iPhone SE) tek ekrana sığması.
- Çoklu sanatçı isimleri/ID'leri `.artists` MusicKit ilişkisine bağlı; albüm parça listelerinde
  ilişki gelmeyebilir → tek sanatçıya fallback yapıyor (kasıtlı).

## SONRAKİ OLASI İŞLER (kullanıcıyla konuşuldu, henüz yapılmadı)
- Freemium "Spectrum Pro": istatistik/Wrapped, sınırsız liste, profil temaları, rozet, reklamsız.
  İlk gelir için en hızlısı: albüm/şarkı sayfalarına **Apple Music affiliate linki**. Abonelik
  için RevenueCat önerildi.
- Mini-player (preview çalarken kalıcı gösterge) — henüz yapılmadı.
- Track/album/artist için düzgün paylaşım kartı (Wrapped tarzı).

### Kodun şu an çok yakın olduğu eklemeler (öneri — sıralı, uygulanmadı)
Hepsi mevcut `MusicService`/model katmanına küçük eklemelerle çıkar:

1. **Gerçek listeler (charts)** — `MusicCatalogChartsRequest` (types: `Song`, `MusicKit.Album`).
   Discover'daki "trending" şu an sadece *bu uygulamanın* loglarından geliyor; kullanıcı azken
   neredeyse boş. Apple'ın gerçek listeleriyle desteklemek Discover'ı ilk günden doldurur.
   **En yüksek getirili madde.**
2. **Albüm rozetleri** — `mkAlbum.contentRating` (Explicit etiketi), `audioVariants`
   (Dolby Atmos / Lossless / Hi-Res), `recordLabel`, `copyright`. Hepsi `MusicKit.Album`'de
   hazır, sadece `Album` modeline taşınıp albüm sayfasında gösterilmesi gerekiyor.
3. **"Latest release" bloğu** — `artist.latestRelease`; sanatçı sayfasının en üstüne
   "yeni çıktı" kartı. `similarArtists` ile aynı request'e bedavaya biner.
4. **Şarkı detayları** — `song.composerName`, `workName` (klasik için), `isrc`. Özellikle
   besteci, Letterboxd'un "yönetmen" alanının müzikteki karşılığı — konsepte çok uyuyor.
5. **Yarım yıldız gösterimi** — `ArtistReviewRow` şu an `rating / 2` tam sayı bölmesi yapıyor,
   3.5★ → 3★ görünüyor. Veri zaten 0-10 tutuluyor, sadece görüntüleme meselesi.
6. **Sanatçı yükleme hatası boş durumu** — `ArtistDetailView`'da hem id lookup hem isim araması
   başarısız olursa bomboş sayfa çıkıyor; "bulunamadı + tekrar dene" gerekiyor.
7. **Mini-player** — `AudioManager` zaten tekil ve `isPlaying`/`currentTrackId` yayınlıyor;
   kalıcı bir alt çubuk çoğunlukla UI işi.

## Çalışma tarzı notları
- Build komutu: `xcodebuild -project Spectrum.xcodeproj -scheme Spectrum -destination
  'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Editördeki "No such module 'Supabase'/'UIKit'" uyarıları SourceKit'in yanlış alarmı; gerçek
  xcodebuild temiz derliyor — onlara güvenme, build'e güven.
- Kullanıcı Türkçe konuşuyor, doğrudan ve pratik cevap istiyor.
