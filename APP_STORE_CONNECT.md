# App Store Connect — kopyala/yapıştır

Bu dosyadaki her şey App Store Connect'e girilmek üzere hazır. Sırayla üstten aşağı gidebilirsin.
Ekran görüntüleri ve Apple hesabına giriş sende — geri kalan tüm metin burada.

---

## 0. Önce: hukuki sayfaları yayına al

Sayfalar `docs/` klasöründe hazır (`terms.html`, `privacy.html`, `support.html`).
GitHub Pages ile yayınlamak için:

1. GitHub'da `Spectrum` deposu → **Settings → Pages**
2. **Source: Deploy from a branch**, Branch: `main`, Folder: **`/docs`** → Save
3. Bir-iki dakika sonra şu adresler açılır:
   - https://berkaycefakar.github.io/Spectrum/terms.html
   - https://berkaycefakar.github.io/Spectrum/privacy.html
   - https://berkaycefakar.github.io/Spectrum/support.html

> Uygulamadaki linkler (`Spectrum/Core/Utils/LegalLinks.swift`) tam olarak bu üç adresi
> gösteriyor. Depo adını veya barındırmayı değiştirirsen o dosyayı da güncelle.
>
> Üç sayfa da iletişim adresi olarak **berkaycefakar@icloud.com** yazıyor. Ayrı bir destek
> adresi kullanacaksan üç HTML dosyasında da değiştir.

---

## 1. App Information

| Alan | Değer |
| --- | --- |
| Name | `Spectrum` |
| Subtitle | `Log the music you love` |
| Bundle ID | `berkay.Spectrum` |
| Primary Category | **Music** |
| Secondary Category | **Social Networking** |
| Content Rights | Contains third-party content: **No** (MusicKit içerik sağlıyor, sen barındırmıyorsun) |
| Copyright | `2026 Berkay Cefakar` |

---

## 2. URL'ler

| Alan | Değer |
| --- | --- |
| Privacy Policy URL | `https://berkaycefakar.github.io/Spectrum/privacy.html` |
| Support URL | `https://berkaycefakar.github.io/Spectrum/support.html` |
| Marketing URL | (boş bırak) |

---

## 3. Promotional Text (170 karakter sınırı)

```
Rate every song, album and artist you hear — then give it a colour. Follow friends and watch
their taste unfold in your feed.
```

---

## 4. Description

```
Spectrum is a diary for your listening.

Log a song, an album or an artist. Give it a rating out of five, write down what you thought,
and pick the colour it feels like. Over time your profile becomes a picture of your taste —
not a list of numbers, but something you actually want to look at.

RATE WHAT YOU HEAR
Search Apple Music's full catalogue and log anything in it. Songs, albums, artists — all three
get their own rating, review and vibe colour.

A COLOUR FOR EVERY RECORD
Every log carries a colour you choose from the prism. It's the part that turns a list of
ratings into something personal, and it's how a profile starts to look like the person behind
it.

SEE WHAT EVERYONE ELSE THINKS
Each song, album and artist has a community score: the average rating, how many people logged
it, and the colour most people reached for. Sometimes you agree. Sometimes that's the
interesting part.

FOLLOW PEOPLE WITH TASTE
Follow friends and strangers, and their logs land in your feed as they happen. Find people
through search, or through the records you both rated.

PREVIEW BEFORE YOU LOG
Thirty-second previews play straight from the card, so you can check a track before rating it.

No Apple Music subscription required — search, artwork and previews all work without one.
Spectrum needs permission to use Apple Music so it can look music up.
```

---

## 5. Keywords (100 karakter sınırı, virgülle, boşluksuz)

```
music,log,rate,review,album,artist,diary,tracker,letterboxd,taste,vibe,social,song,listening
```

---

## 6. What's New in This Version

```
First release.
```

---

## 7. App Review Information

**Sign-In Required: YES** — uygulama tamamen kayıt arkasında.

| Alan | Değer |
| --- | --- |
| Username | (bir test hesabı e-postası) |
| Password | (o hesabın şifresi) |

> ⚠️ **Confirm email açık** olduğu için bu hesabın e-postası **doğrulanmış** olmalı. Doğrulanmamış
> bir hesap verirsen incelemeci giriş yapamaz ve uygulama doğrudan reddedilir. Hesabı kendin
> oluştur, maildeki linke bas, sonra o bilgileri buraya yaz. Hesapta birkaç log bulunsun ki
> incelemeci boş bir uygulama görmesin.

### Notes

```
Spectrum is a music logging app — think Letterboxd for music.

IMPORTANT FOR REVIEW:
1. The app uses MusicKit for all song, album and artist data. On first launch iOS will ask for
   permission to use Apple Music. Please ALLOW it — if it is denied, search returns no results
   and the app will look empty. (The app detects this and shows an explanatory screen with a
   link to Settings.)
2. An Apple Music SUBSCRIPTION IS NOT REQUIRED. Catalogue search, artwork and 30-second
   previews are all free. The app never plays full tracks.
3. MusicKit does not return results in the Simulator, so please review on a device.

USER-GENERATED CONTENT (Guideline 1.2):
- Written reviews are filtered for offensive language on submit, and masked on display.
- Every review card can be reported: long-press it, or tap the ellipsis button on the card.
  A reason is required and we commit to responding within 24 hours.
- Any user can be blocked from the same menu, and from the ellipsis menu on their profile.
  Blocking hides all of their content and removes the follow relationship in both directions.
- Blocked users are listed and reversible under Settings > Blocked Users.
- Terms of Service (with a stated zero-tolerance policy for objectionable content) and the
  Privacy Policy are linked on the sign-up screen and in Settings > About.

ACCOUNT DELETION (Guideline 5.1.1(v)):
Settings > Delete Account. It removes the profile, all logs and reviews, the follow graph, the
uploaded avatar and the auth record itself, server-side.

The backend is Supabase. There is no advertising, no analytics SDK and no tracking.
```

---

## 8. App Privacy — anketin cevapları

**Do you or your third-party partners collect data from this app? → YES**

Aşağıdaki dört tipi işaretle. **Hepsinde** "Used for Tracking" = **NO**.

| Data type | Linked to user | Purpose |
| --- | --- | --- |
| **Contact Info → Email Address** | Yes | App Functionality |
| **Identifiers → User ID** | Yes | App Functionality |
| **User Content → Photos or Videos** | Yes | App Functionality |
| **User Content → Other User Content** | Yes | App Functionality |

> `Contacts` işaretleme — o tip kullanıcının rehberi demek, uygulama rehbere hiç dokunmuyor.
> Takip grafiği zaten *User ID* altında kapsanıyor. (`PrivacyInfo.xcprivacy` de bununla uyumlu.)
>
> `Location`, `Search History`, `Browsing History`, `Usage Data`, `Diagnostics`,
> `Advertising Data` — hiçbiri işaretlenmeyecek.

---

## 9. Age Rating — anket cevapları

Beklenen sonuç: **12+**

| Soru | Cevap |
| --- | --- |
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | **Infrequent/Mild** (kullanıcı yazıları — filtre var ama garanti değil) |
| Alcohol, Tobacco, or Drug Use | None |
| Horror/Fear Themes | None |
| Mature/Suggestive Themes | **Infrequent/Mild** |
| Gambling | No |
| Contests | No |
| **Unrestricted Web Access** | **No** |
| **App includes user-generated content** | **YES** ← bunu mutlaka işaretle |

> UGC kutusunu işaretlememek, sonradan fark edildiğinde uygulamanın mağazadan kaldırılma
> sebebi. Dürüst doldur.

---

## 10. Ekran görüntüleri (sende)

**Zorunlu boyut:** 6.9" — 1320 × 2868 px (iPhone 16/17 Pro Max)
iPad artık gerekmiyor: uygulama iPhone-only olarak yapılandırıldı.

Cihazda çek (simülatörde MusicKit boş döner → ekranlar boş çıkar).
Önerilen 5 kare, bu sırayla:

1. **Feed** — birkaç renkli log görünürken
2. **Track detail** — topluluk puanı + renk dağılımı çubuğu görünürken
3. **Add log** — prism renk seçici açıkken
4. **Profile** — ızgara dolu, birkaç farklı renkte
5. **Discover** — arama sonuçları veya vibe kartları

Çekme: cihazda Ses Kısma + Yan Tuş → Fotoğraflar → Mac'e AirDrop.

---

## 11. Build yüklemeden önce son kontrol

- [ ] `docs/` GitHub Pages'te yayında, üç link de açılıyor
- [ ] Developer portal → `berkay.Spectrum` → **MusicKit** App Service açık
- [ ] Developer portal → `berkay.Spectrum` → **Sign In with Apple** açık
- [ ] `supabase functions deploy delete-user` yapıldı ve tek kullanımlık hesapla denendi
- [ ] Test hesabı oluşturuldu, e-postası doğrulandı, içinde birkaç log var
- [ ] Xcode → Product → Archive (Release), cihazda bir kez çalıştırılmış
