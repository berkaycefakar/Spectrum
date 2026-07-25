# Spectrum — Apple & Google ile Giriş Kurulumu

> Kod tarafı hazır ve derleniyor. Bu adımlar yapılmadan **butonlar görünür ama çalışmaz**.
> Hiçbiri cihazda test edilmedi.

## Proje sabitleri (aşağıda sürekli lazım olacak)

| | |
|---|---|
| Bundle ID | `berkay.Spectrum` |
| Apple Team ID | `8ZCY68284F` |
| Supabase proje ref | `ysgbqlltzdhgsezukxxm` |
| Supabase callback URL | `https://ysgbqlltzdhgsezukxxm.supabase.co/auth/v1/callback` |
| Uygulama redirect URL | `spectrum://auth-callback` |

---

# BÖLÜM 0 — Önce bu (ikisi için de ortak)

**Supabase → Authentication → URL Configuration → Redirect URLs**
`spectrum://auth-callback` satırını ekle, kaydet.

Bu tek satır üç şeyi birden etkiliyor: Google girişi, e-posta onay linki ve şifre sıfırlama
linki. Ekli değilse Supabase yönlendirmeyi reddeder.

> Not: Uygulama tarafında `spectrum://` şeması artık `SpectrumInfo.plist` içinde kayıtlı.
> Daha önce kayıtlı DEĞİLDİ — yani e-posta onay ve şifre sıfırlama linkleri uygulamayı hiç
> açamıyordu. Bu düzeltildi, ekstra bir şey yapmana gerek yok.

---

# BÖLÜM 1 — Apple ile Giriş

Uygulama **native** akış kullanıyor (`SignInWithAppleButton` → `signInWithIdToken`).
Bu, web akışından daha az kurulum istiyor: **Services ID, Key ID veya .p8 secret key
GEREKMİYOR.** Onlar sadece web/Android tarafı için.

### 1.1 Apple Developer portal
1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
2. **Identifiers** → listeden `berkay.Spectrum`'u aç
3. **Sign In with Apple** kutusunu işaretle
4. Sağ üstten **Save** → çıkan uyarıyı onayla

### 1.2 Xcode
Entitlement dosyası (`Spectrum/Spectrum.entitlements`) ve build ayarı zaten eklendi.
Automatic signing kullandığın için Xcode profili kendisi yeniler. Yapman gereken:
- Xcode'u aç, hedefi gerçek bir cihaz seç, bir kez **Run**
- İmzalama hatası verirse: **Signing & Capabilities** sekmesinde "Sign in with Apple"
  capability'sinin listede göründüğünü doğrula, yoksa **+ Capability** ile ekle

### 1.3 Supabase
1. **Authentication → Providers → Apple** → **Enable** aç
2. **Client IDs** alanına `berkay.Spectrum` yaz
   (Alan virgülle ayrılmış çoklu değer kabul eder; native akış için bundle ID yeterli.)
3. Secret Key / Services ID / Team ID / Key ID alanlarını **boş bırak**
4. **Save**

### 1.4 Test
- **Gerçek cihaz gerekiyor** ve cihaz bir Apple ID'ye giriş yapmış olmalı
- `CODE_SIGNING_ALLOWED=NO` ile alınan build'lerde çalışmaz — entitlement imzaya gömülmüyor
- İlk girişte Apple ad/soyad döner; **sadece ilk seferde**. Kod bunu hemen profile yazıyor
  (`ensureProfile`). Test hesabını sıfırlamak istersen:
  iPhone → Ayarlar → [adın] → Oturum Açma ve Güvenlik → Apple ile Oturum Aç → Spectrum →
  **Apple Kimliği Kullanımını Durdur**

---

# BÖLÜM 2 — Google ile Giriş

Uygulama `signInWithOAuth` web akışını kullanıyor (`ASWebAuthenticationSession` ile sistem
tarayıcı sayfası açılıyor). Bu yüzden **GoogleSignIn SDK'sı gerekmiyor** ve Google Cloud'da
**iOS tipi değil, "Web application" tipi** OAuth client oluşturacaksın — token değişimini
Supabase sunucu tarafında yapıyor.

### 2.1 Google Cloud Console — OAuth consent screen
1. https://console.cloud.google.com → üstten proje seç veya **New Project** ile oluştur
2. **APIs & Services → OAuth consent screen**
3. User type: **External** → Create
4. Doldur:
   - App name: `Spectrum`
   - User support email: kendi e-postan
   - Developer contact information: kendi e-postan
5. **Scopes** adımında: `.../auth/userinfo.email`, `.../auth/userinfo.profile`, `openid`
6. **Test users** adımında kendi Google hesabını ekle
   (Uygulama "Testing" modundayken **sadece** bu listedekiler giriş yapabilir. Herkese açmak
   için sonradan **Publish app** demen gerekiyor.)

### 2.2 Google Cloud Console — OAuth client
1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **Web application** ← burası kritik, iOS seçme
3. Name: `Spectrum Supabase`
4. **Authorized redirect URIs** → **ADD URI**:
   ```
   https://ysgbqlltzdhgsezukxxm.supabase.co/auth/v1/callback
   ```
5. **Create** → çıkan **Client ID** ve **Client Secret**'ı kopyala

### 2.3 Supabase
1. **Authentication → Providers → Google** → **Enable** aç
2. **Client ID** ve **Client Secret** alanlarına 2.2'de aldıklarını yapıştır
3. **Save**

### 2.4 Test
- Simülatörde de çalışır (Apple'ın aksine)
- Butona basınca sistem tarayıcı sayfası açılmalı; Google hesabını seçtikten sonra
  `spectrum://auth-callback`'e dönüp uygulamaya geri gelmeli
- "redirect_uri_mismatch" hatası → 2.2'deki URI'yi yanlış yazmışsın
- "Access blocked / not verified" → 2.1'deki test users listesinde değilsin

---

# BÖLÜM 3 — Kayıt olunca doğrudan giriş

**Supabase → Authentication → Providers → Email → "Confirm email"**

- **Kapalı** → kullanıcı kayıt olur olmaz içeri girer (senin istediğin davranış)
- **Açık** → session gelmez; uygulama artık bunu düzgün yönetiyor ve
  "Account created. Confirm your email, then log in." mesajını gösteriyor

Sosyal girişlerde (Apple/Google) bu ayarın etkisi yok — onlarda e-posta zaten doğrulanmış
sayılıyor.

---

# BÖLÜM 4 — Şifre sıfırlama (tamamlandı)

Akış: "Forgot password?" → e-posta → linke bas → `spectrum://auth-callback` uygulamayı açar →
**"Choose a new password" ekranı** her şeyin üstünde açılır → yeni şifre + tekrar → kaydet.

Dikkat edilen nokta: recovery linki kullanıcıyı zaten **giriş yapmış** hâle getiriyor. Ekran
gösterilmezse kullanıcı içeri girer ama unuttuğu şifre hâlâ geçerli kalır. Bu yüzden ekranın
"vazgeç" seçeneği **oturumu kapatıyor** — sessizce geçilebilen bir adım değil.

### Tespit neden iki yoldan yapılıyor
Supabase SDK'sı `.passwordRecovery` olayını **sadece implicit akışta** yayınlıyor
(`AuthClient.swift:894`). Bu projenin varsayılanı **PKCE** ve orada callback yalnızca
`.signedIn` olarak raporlanıyor. Bu yüzden:
1. `AuthDeepLink.isPasswordRecovery(url)` — URL'in hem query hem fragment kısmında
   `type=recovery` arıyor (`onOpenURL` içinde, `client.handle(url)`'dan ÖNCE)
2. `authStateChanges` içindeki `.passwordRecovery` olayı — ikinci sinyal

### Yine de çalışmazsa
**Settings → Change Password** her zaman çalışır ve aynı ekranı açar. Supabase ileride akışı
değiştirirse güvenli çıkış yolu bu.

### Test
- Linki **cihazda** aç (simülatörde mail uygulaması yok; `xcrun simctl openurl booted
  "spectrum://auth-callback?type=recovery"` ile ekranın açılışını test edebilirsin ama
  gerçek oturum kurulmaz)
- Yeni şifreyle çıkış yapıp tekrar giriş yaparak doğrula

---

# Sırayla ne yapmalı

1. Bölüm 0 (redirect URL) — 1 dakika, üçünü birden açar
2. Bölüm 3 (Confirm email kararı) — 1 dakika
3. Bölüm 2 (Google) — simülatörde test edebildiğin için önce bunu bitir
4. Bölüm 1 (Apple) — cihaz gerektiği için en son
