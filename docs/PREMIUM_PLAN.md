# Spectrum+ (premium plan)

Musicboard'dan çıkan ders (`MUSICBOARD_RESEARCH.md`): kullanıcı temel işlevleri parayla
almayı sevmiyor. *"Banner için Pro'ya geçmek zorunda olmasaydım"*, *"Pro özelliklerinin çoğu
herkese açık olmalı"*. Bu yüzden Spectrum'da loglama, puan, vibe, yorum, liste, favori 4 ve
kapak hep ücretsiz kalıyor.

Spectrum+ üç şey satıyor:
- daha derin istatistik
- kendini ifade etmek
- güç kullanıcısına araç

## Ücretsiz / Spectrum+

| | Ücretsiz | Spectrum+ |
|---|---|---|
| Şarkı / albüm / sanatçı loglama, puan, vibe, yorum | ✓ | ✓ |
| Listeler, favori 4, profil kapağı | ✓ | ✓ |
| Tüm zamanlar özeti (kayıt, ortalama, spektrum, dağılım) | ✓ | ✓ |
| **Zaman içinde spektrum**: ay ay vibe akışı, yıl karşılaştırması | | ✓ |
| **Yıl özeti kartı**: paylaşılabilir, Spotify Wrapped tadında | | ✓ |
| **En çok dinlenen**: sanatçı, tür, on yıl kırılımları | | ✓ |
| **Kendi loglarında arama ve filtre** (puan, vibe, yıl) | | ✓ |
| **Profil vurgu rengi**: kendi spektrumundan seç | | ✓ |
| **Spectrum+ rozeti** profilde | | ✓ |
| **Hareketli profil fotoğrafı ve kapak** (GIF / Live Photo; Musicboard Pro'da var) | | ✓ |
| **Alternatif uygulama ikonları** (Musicboard Pro'nun "tema" karşılığı) | | ✓ |
| Yeni özelliklere erken erişim | | ✓ |

Reklam yok, olmayacak; o yüzden "reklamsız" bir satış maddesi değil.

**Kural (Apple Developer Program License Agreement 3.3.6(D)):** Apple Music erişimi
doğrudan ya da dolaylı yoldan paraya bağlanamaz. Spectrum+ yalnızca kullanıcının kendi
loglarından üretilen şeyleri satar. "Listeyi Apple Music çalma listesine aktar" bu yüzden
ücretsiz kalmalı (ya da hiç yapılmamalı), premium'a konamaz. Ayrıntı: `docs/API_COMPLIANCE.md`.

## Ekran (seçildi: B, 20 Kasım)

Kaydırmalı 5 sayfa, altta sabit "1 hafta ücretsiz dene" ve fiyat satırı:
1. Yıl özeti kartı · 2. Ay ay spektrum · 3. Derin istatistik · 4. Loglarında arama ·
5. Görünüş (hareketli fotoğraf/kapak, profil rengi, uygulama ikonu, rozet).
Tasarım: https://claude.ai/artifact/AuaiwSNEDMj7Z5f4eEfcVK

Musicboard Pro'dan "reklamsız" alınmadı: Spectrum'da reklam yok.

## Fiyat

| Ürün | ID | Fiyat (ABD) | TR |
|---|---|---|---|
| Aylık | `berkay.Spectrum.plus.monthly` | $2,99 | ~₺99 |
| Yıllık | `berkay.Spectrum.plus.yearly` | $19,99 (%44 indirim) | ~₺699 |

Yıllığa 1 haftalık ücretsiz deneme. Musicboard'un ömür boyu fırsatının $19,99'a satılması,
bu kitlenin yılda ~$20'yi kabul ettiğini gösteriyor. Sonra bir de ömür boyu seçenek ($39,99)
denenebilir.

## Uygulama durumu (19 Kasım 2026)

Yapıldı (kodda, **kapalı**):
- `Services/PremiumStore.swift`: StoreKit 2 ile ürünleri yükleme, satın alma,
  `Transaction.updates` dinleme, geri yükleme ve `isPlus`.
- `UI/Screens/PaywallView.swift`: plan seçimi, deneme, geri yükleme, Apple'ın istediği
  koşullar ve gizlilik linkleri.
- Ayarlar'da "Spectrum+" satırı, profilde rozet.
- `Spectrum.storekit`: simülatörde gerçek hesap olmadan test için.
- Hepsi `PremiumStore.isOfferEnabled` bayrağının arkasında. Bayrak `false` olduğu için 1.0
  incelemesine giden build'de hiçbiri görünmüyor.

Kalan:
1. **1.0 onaylandıktan sonra** App Store Connect'te abonelik grubunu ve iki ürünü oluştur.
   Ürünlerin ekran görüntüsü ve açıklaması lazım; ilk abonelik bir sürümle birlikte
   incelemeye gönderilmek zorunda.
2. Satılan özellikleri yaz. Şu an sadece rozet var; önce "zaman içinde spektrum" ve
   "yıl özeti kartı" yapılmalı.
3. Abonelik durumunu Supabase'e yaz (rozetin başkalarına da görünmesi için). Bunun için
   App Store Server Notifications V2'yi alan bir Edge Function gerekiyor.
4. `isOfferEnabled = true` yap ve 1.1 olarak gönder.

**Neden 1.0'da değil:** İlk sürümde uygulama içi satın alma olursa inceleme ürünleri de
denetler. Satılan özelliklerin çoğu henüz yazılmadı ve Apple boş vaatli paywall'u reddeder
(Guideline 3.1.1 / 2.1). Çıkışı geciktirmemek için premium 1.1 ile gelir.
