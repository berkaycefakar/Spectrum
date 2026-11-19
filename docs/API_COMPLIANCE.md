# Spectrum: kullanılan servisler, kuralları ve Supabase kapasitesi (19 Kasım 2026)

> Hukuki görüş değil; Apple'ın yayımlanmış metinlerinin okunmasıdır. Kesin cevabı Apple'ın
> incelemesi verir.

## Kısa cevap

**Yasa dışı bir şey yok.** Hiçbir API'yi kırmıyor, kazımıyor (scraping) ya da gizli bir uç
nokta kullanmıyoruz. Her şey Apple'ın ve Supabase'in herkese açık, belgelenmiş yollarından
geçiyor.

Risk hukuki değil, **sözleşmesel**: Apple'ın geliştirici sözleşmesi MusicKit'i belli koşullarla
kullandırıyor. Bunlara uyulmazsa sonuç ceza değil, **App Store reddi** ya da MusicKit
erişiminin kapatılması olur. Aşağıdaki maddelerin çoğu bugün düzeltildi.

## Uygulamanın konuştuğu servisler

| Servis | Ne için | Anahtar / hesap | Kurallar |
|---|---|---|---|
| **MusicKit** (Apple Music kataloğu) | Arama, şarkı / albüm / sanatçı bilgisi, listeler | Apple geliştirici hesabı (otomatik token) | Apple Developer Program License Agreement (PLA) §3.3.6(D) |
| **iTunes Lookup API** (`itunes.apple.com/lookup`) | Akış kartlarının hızlı verisi | Anahtarsız | iTunes Search API şartları |
| Apple görsel ve önizleme sunucuları (`mzstatic.com`, `audio-ssl.itunes.apple.com`) | Kapaklar, 30 sn önizleme | — | Yukarıdaki iki kuralın parçası |
| **Supabase** | Hesaplar, loglar, takip, beğeni, yorum, liste, avatar | Projede `anon` anahtarı (herkese açık olması normal) | Supabase şartları ve plan kotaları |
| Google ile giriş (Supabase üzerinden) | Giriş | Google Cloud OAuth | Standart; Apple ile giriş de var (Guideline 4.8 tamam) |
| song.link | Paylaşılan link | Yok, sadece URL | API kullanılmıyor (ücretsiz API'si kapandı) |
| Spotify / YouTube Music | "Şurada dinle" menüsü | Yok, sadece arama linki | API yok, logo yok, sadece yazı. Sorun yok |

Spotify API'si **kullanılmıyor**. Eski bir Spotify client secret'ı dışarı sızmıştı; işe
yaramıyor ama panelden iptal edilmeli.

## Apple'ın kuralları, madde madde

### 1. Apple Music erişimi paraya çevrilemez. **Uyumlu**
PLA §3.3.6(D): *"You agree not to require payment for or indirectly monetize access to the
Apple Music service (e.g. in-app purchase, advertising, requesting user info) through Your use
of the MusicKit APIs…"*

- Uygulamada reklam yok ve şu an satış da yok.
- Spectrum+ planı yalnızca kullanıcının **kendi loglarından** üretilen şeyleri satıyor:
  istatistik, yıl özeti, arama, renk.
- "Listeyi Apple Music'e aktar" özelliği premium listesindeydi. Bu madde yüzünden
  **çıkarıldı**, ücretsiz kalmalı.
- **Kural:** Hiçbir Apple verisi (katalog, kapak, önizleme) paralı duvarın arkasına konmaz.

### 2. Kapak görselleri ve müzik metni yalnızca çalma ya da çalma listesi bağlamında. **Orta risk, azaltıldı**
PLA §3.3.6(D): *"album art and music-related text from the MusicKit API may not be used
separately from music playback or managing playlists."*

- Akış kartlarında, şarkı sayfasında ve albüm sayfasında önizleme çalma var.
- Listeler, çalma listesine en yakın kavram.
- Profildeki favori 4 ve aktivite kartları bu kuralın en zayıf olduğu yerler: kapak var ama
  çalma yok.
- Bugün eklenen **"Listen on Apple Music" rozeti** her şarkı ve albüm sayfasından Apple
  Music'e götürüyor. Apple'ın görmek istediği bağ bu.
- Benzer Letterboxd-tarzı müzik uygulamaları App Store'da yayında. Bu madde katı
  uygulanmıyor ama inceleme notunda MusicKit kullanımı zaten açıklanıyor.

### 3. Amaç: kullanıcının Apple Music'ine erişimi kolaylaştırmak. **Orta risk**
PLA §3.3.6(D): *"…not to call the MusicKit APIs … for purposes unrelated to facilitating access
to Your end users' Apple Music subscriptions."*

- En geniş yorumlanabilecek madde bu.
- Lehimize olanlar: rozet ve link her sayfada var, paylaş menüsünde Apple Music ilk sırada,
  önizlemeler Apple'ın kendi sunucusundan çalıyor.
- Güçlendirmek için ileride eklenebilecekler (ücretsiz olarak):
  - "Apple Music kütüphanene ekle"
  - "Listeyi çalma listesi yap"

### 4. Rozet ve atıf (Apple Music Identity Guidelines). **Bugün düzeltildi**
- Apple'ın resmi, değiştirilmemiş "Listen on Apple Music" rozeti eklendi. Koyu zemin
  sürümü, tools.applemediaservices.com adresinden. Şarkı ve albüm sayfalarında,
  öğenin Apple Music sayfasına linkli.
- Önizlemenin altında "Preview provided courtesy of Apple Music." yazıyor.
- Ayarlar'da zorunlu marka satırı var: "Apple and Apple Music are trademarks of Apple Inc…".

### 5. iTunes Lookup API. **Uyumlu**
- **Hız sınırı:** "approximately 20 calls per minute". Bu IP, yani telefon başına. Biz akış
  sayfası başına 1 istek atıyoruz.
- **Önizleme sesi:** "streamed only, not downloaded, saved, cached". Uyumlu: önizlemeler
  `AVPlayer` ile akıtılıyor, indirilmiyor.
- **Önbellek:** API cevaplarının önbelleğe alınması Apple'ın kendi önerisi. Akışın disk
  önbelleği yalnızca metin ve görsel adresi tutuyor, ses tutmuyor.
- **Rozet ve atıf:** Görsel ve önizlemenin rozete yakın olması, atıf yapılması (madde 4).

### 6. Kullanıcı içeriği (Guideline 1.2). **Uyumlu**
- Küfür filtresi var.
- Log, yorum ve profil bildirilebiliyor.
- Kullanıcı engellenebiliyor ve engel geri alınabiliyor.
- Hesap silme sunucu tarafında yapılıyor.

### 7. Apple ID'lerini ve kullanıcı puanlarını saklamak. **Uyumlu**
- Şarkı ve albüm ID'si ile kullanıcının kendi puanı ve yorumu saklanıyor. Bu kullanıcının
  kendi içeriği; gizlilik politikasında açıklı.
- Kapak ve önizleme dosyası saklanmıyor, sadece Apple'ın adresi tutuluyor.

## Supabase: ne zaman dolar?

Ücretsiz plan (supabase.com/pricing, 19 Kasım 2026):

| Kaynak | Ücretsiz | Pro ($25/ay) |
|---|---|---|
| Veritabanı | 500 MB | 8 GB (sonra $0,125/GB) |
| Dışarı veri (egress) | 5 GB/ay (+5 GB önbellekli) | 250 GB (sonra $0,09/GB) |
| Aylık aktif kullanıcı (auth) | 50.000 | 100.000 |
| Dosya (avatar) | 1 GB | 100 GB |
| Hareketsizlikte durdurma | **1 hafta** | Hiç |
| Yedek | **Yok** | Günlük, 7 gün |

Şu an: veritabanı 13 MB, 7 kullanıcı (13 MB'ın çoğu Supabase'in kendi tabloları).

**Tahmin** (ölçüme ve kabullere dayalı, kesin değil):
- **Veritabanı:** Bir log satırı yaklaşık 100 bayt, indekslerle yaklaşık 250 bayt. Aktif bir
  kullanıcı yılda yaklaşık 150 şarkı logu, beğeniler, yorumlar ve oturum kayıtlarıyla
  ~100 KB üretir. 500 MB yaklaşık **4.000–5.000 kullanıcı-yıl** eder.
- **Egress, ilk dolacak sınır:** Açılış başına akış + profil + aktivite yaklaşık 50–80 KB.
  Kapaklar Apple'dan geliyor, Supabase'i harcamıyor. Günde 2 açılışla kullanıcı başına ayda
  ~3–5 MB eder. 5 GB yaklaşık **1.000–1.700 aylık aktif kullanıcı**.
- **Auth (50.000):** Çok sonra gelir, sorun değil.

Kotası aşılan ücretsiz projede ne olduğu Supabase belgelerinde net yazmıyor; projenin
kısıtlanması bekleniyor.

**Asıl tehlike sınırlar değil:**
1. **1 hafta kullanılmayınca proje duruyor.** 17 Kasım'da durmuş bulundu. Apple inceleme
   sırasında açarsa boş uygulama görür ve reddeder.
2. **Yedek yok.** Veritabanı bozulursa ya da yanlışlıkla silinirse her şey gider.

**Öneri:** Yayından hemen önce Pro plana geç ($25/ay, ~₺850). Durma ve yedek sorunu biter,
egress ~50 kat artar. Spend cap varsayılan olarak açık kalsın; sürpriz fatura gelmez.
Spectrum+ yıllık $19,99 ile, Apple'ın %15'i düşülünce, Pro planı ayda yaklaşık 18 abone
karşılar.

## Kaynaklar
- Apple Developer Program License Agreement §3.3.6: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- iTunes Search API (şartlar, hız sınırı): https://performance-partners.apple.com/resources/documentation/itunes-store-web-service-search-api/
- Apple Music Identity Guidelines: https://marketing.services.apple/apple-music-identity-guidelines
- Supabase fiyatları ve kotalar: https://supabase.com/pricing, https://supabase.com/docs/guides/platform/cost-control
