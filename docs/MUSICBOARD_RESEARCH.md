# Musicboard: kullanıcı yorumları incelemesi (19 Kasım 2026)

**Kaynak:** Apple'ın herkese açık yorum akışından ABD ve İngiltere App Store'undaki 505 yorum
(Haziran 2020 – Kasım 2026). Bunların 216'sı 2025'ten sonra yazılmış.
Yıldız dağılımı (tümü): 5★ 159 · 4★ 95 · 3★ 81 · 2★ 69 · 1★ 101.

Sayılar anahtar kelime eşleşmesinden geliyor; kesin değil ama sıralama belirgin.

## Neden şikâyet ediyorlar (1–3★)

| Konu | 1–3★ yorum | Ne diyorlar |
|---|---|---|
| Hata / çökme / yüklenmeme | 107 | "Bu albümü ilk açan sensin, birkaç saniye sürebilir" ekranı hiç bitmiyor; puan veya yorum "yayınlanmıyor"; sunucu haftalarca kapalı |
| Hesap / giriş | 56 | Oturum düşüyor, şifre sıfırlama maili gelmiyor, destek cevap vermiyor |
| Arayüz yavaş / hantal | 40 | Arama geç geliyor, ekranlar takılıyor |
| Sosyal akış | 28 | Akış yenilenmiyor, takip edilecek kişi bulmak zor, herkesin zevki aynı |
| Eksik / yanlış albüm verisi | 21 | Yeni ya da niş albümler yok; diskografi tekrarlı ve dağınık; "katkı" sayfası açılmıyor |
| Bırakılmış uygulama | 9 (+ çok sayıda dolaylı) | "Barely works anymore", "on its way out", 6 aydır güncelleme yok |
| Topluluk / taciz | 7 | İş teklifi spam'i, reşit olmayanlara taciz, ölüm tehditleri; moderasyon yok |
| Premium | 7 | Ücretsiz deneme alındı ama özellikler açılmadı, destek yok |

**En önemli çıkarım:** Musicboard'un bir numaralı sorunu kendi albüm veritabanı. Albümü kendisi
çekip saklıyor; çekemediğinde kullanıcı o albüme puan veremiyor. Spectrum katalogu doğrudan
Apple Music'ten okuyor. Bu yüzden bu sorun Spectrum'da yok, mağaza metninde öne çıkarılmaya
değer: "Apple Music'teki her şarkıyı ve albümü, çıktığı gün logla."

İkinci çıkarım: güvenilirlik. Musicboard'u bitiren şey kapalı sunucular ve cevapsız destek.
Spectrum'un Supabase projesi ücretsiz planda ve hareketsiz kalınca duraklatılıyor (17 Kasım'da
duraklatılmış bulundu). Kullanıcı gelmeye başlamadan Pro plana geçmek ya da düzenli bir ping
kurmak gerekiyor.

## Ne istiyorlar (4–5★ yorumlardaki istekler)

Spectrum'da durumu ile:

| İstek | Spectrum'da |
|---|---|
| Albüm yorumunda şarkıları tek tek puanlamak | Yok, şarkılar ayrı ayrı loglanıyor. **Güçlü aday** |
| "Sonra dinle" listesi | Yok (listelerle kısmen). **Güçlü aday** |
| İsteğe bağlı dinleme tarihi, geçmişte dinlenenleri loglamak | Log tarihi otomatik |
| Daha ince puanlama (10'luk ya da 100'lük) | 0,5 adımlı 5'lik. Echo bunu sunuyor; Musicboard'da şikâyet var |
| Spotify / Apple Music bağlantısı, "şu an dinliyor" | Yok. Paylaş menüsü üç servise yönlendiriyor |
| Listeyi Spotify / Apple Music çalma listesine aktarmak | Yok. Apple Music'e MusicKit ile mümkün |
| Başkasının listesini kopyalamak / kaydetmek | Yok |
| Listede loglanmış albümleri soluk göstermek | Yok, ucuz bir iş |
| Kendi puanlarında arama | Yok |
| Profilde favori 4 albüm | **Var** |
| Kapak (banner) ücretsiz olsun | **Var**, ücretsiz |
| Krediler (yapımcı, söz yazarı) | Söz yazarı var |
| Doğru çıkış tarihi | Apple kataloğundan geliyor |
| Keşfette tür çeşitliliği | Keşif ekranı listelere dayanıyor; tür filtresi yok |
| Albüm / şarkı düelloları (bracket) | Yok, eğlenceli bir 1.x fikri |

## Musicboard Pro

Bir indirim sitesine göre ömür boyu Pro $19,99 (liste fiyatı $179,64). İçeriği:
- gelişmiş istatistikler
- hareketli avatar, tema ve kapak
- tema renkleri
- reklamsız kullanım

Kullanıcıların tepkisi: *"Pro özelliklerinin çoğu herkese açık olmalı"*, *"banner için Pro'ya
geçmek zorunda olmasaydım"*. TechRadar yazarı da Pro'yu "parasına değmez" buluyor.

**Spectrum için sonuç:** Temel işlevler hep ücretsiz kalmalı: loglama, liste, favori 4, kapak.
Premium; görünüş, derin istatistik ve güç kullanıcısı araçları satmalı.
Öneri `docs/PREMIUM_PLAN.md` dosyasında.

## Kaynaklar
- Apple yorum akışı: `https://itunes.apple.com/{us,gb}/rss/customerreviews/page=N/id=1503544789/sortby=mostrecent/json`
- [JustUseApp yorum özeti](https://justuseapp.com/en/app/1503544789/musicboard-discuss-music/reviews)
- [TechRadar: "I love music and this app makes my experience complete"](https://techradar.com/computing/software/i-love-music-and-this-app-makes-my-experience-complete)
- [Musicboard Pro ömür boyu fırsatı (Android Authority Deals)](https://deals.androidauthority.com/sales/musicboard-pro-plan-lifetime-subscritpion)
