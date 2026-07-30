# Spectrum — App Store Readiness

> Status of this document: written after a full read of the codebase and verified against a
> real `xcodebuild` run and the resulting `Spectrum.app/Info.plist`. Items are marked
> **[VERIFIED]** (I checked the built artifact or the code path), **[REASONED]** (correct by
> inspection, not executed) or **[NEEDS YOU]** (only the account owner can do it).
>
> **Nothing in this document has been visually tested on a device.** MusicKit does not work in
> the Simulator, so every UI claim below is a code-level claim.

---

## 0. Blockers, ranked

| # | Severity | Item | State |
| - | -------- | ---- | ----- |
| 1 | **Rejection** | In-app account deletion (Guideline 5.1.1(v)) | **Client done**, server step outstanding — §1 |
| 2 | **Rejection** | `auth.users` row survives deletion — needs an Edge Function | **Function written** (`supabase/functions/delete-user`), **you must deploy it** — §1.2 |
| 3 | **Rejection risk** | RLS not audited — the entire security model | **[NEEDS YOU]** — §6 |
| 3b | **Rejection risk** | UGC: filter + report + block (Guideline 1.2) | **Implemented in app**, migration must be run — §8 |
| 4 | **Was fatal, fixed** | Deployment target was iOS **26.2** → almost no installable devices | **Fixed → 17.0** — §3.1 |
| 5 | **Rejection risk** | App declares **iPad** support but the UI is phone-portrait only | **Decision needed** — §3.2 |
| 6 | **Upload blocker** | Privacy manifest missing | **Added** — §4 |
| 7 | **Upload friction** | `ITSAppUsesNonExemptEncryption` missing → export question on every upload | **Added** — §3.3 |
| 8 | **Metadata** | Privacy policy + support URL, screenshots, age rating | **[NEEDS YOU]** — §7, §8 |
| 9 | **Guideline 5.2.1** | Apple Music attribution/branding | **[NEEDS YOU]** — §5 |
| 10 | Quality | Mixed Turkish/English UI strings | Open — §9 |

---

## 1. Account deletion — Guideline 5.1.1(v)

Apple requires that any app offering account **creation** also offers account **deletion**
from inside the app. Spectrum had sign-up and no way out. This was the single most likely
cause of a first-submission rejection.

### 1.1 What now exists in the app **[VERIFIED — compiles, code path reviewed]**

`SupabaseManager.deleteAccount()` and a **Delete Account** button at the bottom of
`SettingsView`, behind a destructive confirmation alert that spells out what is lost.

Deletion order is deliberate — owned content first, profile row last, so an interrupted run
never leaves a live-looking profile pointing at content that is already gone:

1. `reviews`, `album_reviews`, `artist_reviews` where `user_id = me`
2. `follows` where `follower_id = me` **and** where `following_id = me`
   (both directions — otherwise other users keep a follower who no longer exists)
3. Storage object `avatars/<uuid>/avatar.jpg` (best-effort; a storage error must not block)
4. `profiles` where `id = me`
5. `auth.signOut()`

`SessionStore.signOut()` was also fixed: it previously left `currentUser` populated when the
network sign-out threw, which would have kept the app showing signed-in tabs immediately
after the account was deleted.

### 1.2 What you must still do server-side **[NEEDS YOU — REQUIRED]**

The row in `auth.users` is **not** deleted by the app, and must not be: removing it requires
the `service_role` key, and embedding that key in the binary would give every user full
admin access to your database. Anyone can extract it from an IPA.

Deploy this Edge Function, then have the app call it. Until you do, a deleted account leaves
an orphaned auth row containing the email address — which Apple can reasonably consider
incomplete deletion.

```bash
supabase functions new delete-user
```

`supabase/functions/delete-user/index.ts`:

```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response("Unauthorized", { status: 401 });

  // Identify the caller from THEIR token — never trust a user-supplied id.
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return new Response("Unauthorized", { status: 401 });

  // Elevate only after the caller is proven.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  await admin.from("reviews").delete().eq("user_id", user.id);
  await admin.from("album_reviews").delete().eq("user_id", user.id);
  await admin.from("artist_reviews").delete().eq("user_id", user.id);
  await admin.from("follows").delete().eq("follower_id", user.id);
  await admin.from("follows").delete().eq("following_id", user.id);
  await admin.storage.from("avatars").remove([`${user.id}/avatar.jpg`]);
  await admin.from("profiles").delete().eq("id", user.id);

  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return new Response(delErr.message, { status: 500 });

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

```bash
supabase functions deploy delete-user
```

Then replace the body of `SupabaseManager.deleteAccount()` with a single invocation
(`client.functions.invoke("delete-user")`) followed by `signOut()`. The current client-side
deletion becomes the fallback. **Do not put the service-role key in the app under any
circumstances.**

---

## 2. Bugs found and fixed this pass

All verified to compile; none verified on device.

| Severity | Where | Defect | Fix |
| -------- | ----- | ------ | --- |
| **High** | `SearchDiscoveryView.performSearch` | Four searches awaited as one tuple with `try await (…)`. Any one throwing discarded **all four** result sets — so with Apple Music access denied, searching for a friend's username returned "No tracks found". | Each source fails independently. |
| **High** | `ArtistDetailView.ratingSection` | Auto-saved on every `onChange`. A drag emits a change per step; each started a save and the `isSaving` guard **silently dropped the rest** — so the rating written to the database was the *first* step of the drag, not the last. Opening a page you'd already rated also wrote the same value straight back. | 550 ms debounce + `persistedRating` guard. One write per gesture, none on load. |
| **High** | `SessionStore.signOut` | A thrown network error left `currentUser` set → app stayed "logged in" after the user signed out. | Local session always cleared. |
| **High** | `AudioManager` | `AVAudioSession` was set to `.playback` and activated in `init`, i.e. at app launch. **Opening Spectrum stopped whatever music the user was already playing**, even if they never pressed play. | Session activated on play, released on pause/stop/end. |
| **Medium** | `UserProfileView` (Artists tab) | Hardcoded `count: 0` and "No artists rated yet". Other users' artist ratings existed in the DB and on their own profile but were invisible to everyone else. | Loads and renders real artist reviews + photos. |
| **Medium** | `EditProfileView.saveProfile` | `guard let user … else { return }` inside the `Task` left `isLoading == true` forever — a spinner with no recovery but a force-quit. | Clears state, shows an error. |
| **Medium** | `SupabaseManager.getArtistReviews` / `getUserArtistReview` / artist write path | Matched artist name with `.eq` (case-**sensitive**). "Daft Punk" and "daft punk" became two artists with two separate community averages, and re-rating created a duplicate row instead of updating. | Case-insensitive `ilike` with `%`/`_`/`\` escaped so a name can't act as a wildcard. |
| **Medium** | `ProfileView`, `UserProfileView` grids | Sorted on `rating` alone. `sorted(by:)` is **not stable**, so equally-rated logs reshuffled on every reload. | `createdAt` tie-break — deterministic order. |
| **Medium** | `SearchDiscoveryView` sort predicates | The comparator returned `false` both for "equal" and for "b before a" — not a strict weak ordering. `sort` may produce any arrangement from an invalid predicate. | Replaced with an integer rank comparison. |
| **Medium** | `ActivityView` | `.task` runs once per view identity; the tab showed launch-time state and new followers never appeared without relaunching. | Added `.refreshable`. |
| **Medium** | `ArtistDetailView`, `AlbumDetailView`, `TrackDetailView`, both profiles | 3–6 independent awaits chained sequentially; page latency was the *sum* of every request. | `async let` fan-out throughout. |
| **Low** | `SearchDiscoveryView.performSearch` | No cancellation check after the awaits — a slow earlier keystroke could overwrite newer results. | `Task.isCancelled` guard before publishing. |
| **Low** | `fetchTrendingTrackIds` | Always pulled a flat 200 rows to de-duplicate client-side. | Window scales with the request (Discover asks 12 → 120 rows). See §6.4 for the proper fix. |
| **Cleanup** | `iTunesService.swift`, `iTunesResponse` | Dead since the MusicKit migration; confirmed zero references. | Deleted. |

### Investigated and deliberately **not** changed

- **`Track.artworkUrl600` / `Album.artworkUrl600` naive `"100x100"` → `"600x600"` replace.**
  Every URL is minted by our own `artwork?.url(width: 100, height: 100)` call, so the token
  appears exactly once in the filename segment. Rewriting this would add risk without fixing
  a reachable bug.
- **`AlbumGridItemView`'s fixed `width: 160` inside a two-column grid.** 2×160 + spacing +
  padding = 368 pt, which fits the narrowest device still supported at iOS 17 (375 pt).
- **`ArtistReviewRow` star count uses integer division** (`rating / 2`), so 3.5★ renders as 3.
  Consistent rounding-down, not a defect — but half-stars would be an improvement.

---

## 3. Project configuration

### 3.1 Deployment target — was the most damaging single setting **[VERIFIED, FIXED]**

`IPHONEOS_DEPLOYMENT_TARGET` was **26.2** (an Xcode 26 template default). The app would have
installed on essentially no devices in the wild, and the store listing would have shown
"Requires iOS 26.2 or later".

Lowered to **17.0** and verified: `** BUILD SUCCEEDED **`, and the built
`Info.plist` reports `MinimumOSVersion = 17.0`. Swift enforces API availability at compile
time, so a clean build at 17.0 means no API used here is newer than iOS 17.

> **Still test on a real iOS 17 device before shipping.** Compiling is not running.

### 3.2 Device family and platforms — **decision needed before you submit**

Current, from the built `Info.plist` **[VERIFIED]**:

- `UIDeviceFamily = [1, 2]` → **iPhone and iPad**
- `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator"`
- iPhone orientations: Portrait, LandscapeLeft, LandscapeRight
- iPad orientations: all four

Consequences if you leave this as-is:
- App Store Connect will **require a full set of iPad screenshots**.
- Reviewers will run it on an iPad. The UI is built around phone-portrait assumptions (fixed
  hero heights, `width: 130` album tiles, a `width * 1.1` artist hero). On a 13" iPad this
  will look stretched — a Guideline 4.0 "design" rejection risk.
- Landscape on iPhone has the same problem and is currently allowed.

**Recommended (iPhone-portrait-only, matches how the app is actually designed):**

```
TARGETED_DEVICE_FAMILY = 1;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;
```

I did **not** apply this — which platforms you ship is a product decision, not a bug fix.
It is a one-line edit in Build Settings and trivially reversible.

### 3.3 Other settings **[VERIFIED in the built Info.plist]**

| Key | Value | Verdict |
| --- | ----- | ------- |
| `CFBundleShortVersionString` | `1.0` | Fine for a first release |
| `CFBundleVersion` | `1` | Fine; must increase on **every** upload |
| `ITSAppUsesNonExemptEncryption` | `false` | **Added this pass.** HTTPS-only use is exempt. Without it you answer the export question on every single upload |
| `NSAppleMusicUsageDescription` | present, accurate | Good — required, and rejected if vague |
| `UILaunchScreen` | generated | Present |
| `AppIcon` | single 1024×1024 universal | Sufficient; iOS 18 dark/tinted variants optional |
| `AccentColor` | present | Fine |

No `NSPhotoLibraryUsageDescription` is needed: avatar picking uses `PhotosPicker`
(`PHPickerViewController`), which runs out of process and requires no permission string.

### 3.4 Dependencies **[VERIFIED]**

`supabase-swift 2.40.0` and its transitive Point-Free / Apple Swift packages. All source
dependencies; nothing requiring extra licensing disclosure.

### 3.5 Tests

`SpectrumTests/` and `SpectrumUITests/` are untouched Xcode templates — no real coverage.
Not an App Store requirement, but there is no automated safety net for any of the above.

---

## 4. Privacy manifest — `PrivacyInfo.xcprivacy` **[VERIFIED — present in the built .app]**

Created at `Spectrum/PrivacyInfo.xcprivacy`; confirmed copied into `Spectrum.app/` by the
build. Declares:

- `NSPrivacyTracking = false`, no tracking domains.
- Collected, **linked to the user, not used for tracking**, all for App Functionality:
  email address, user ID (username/bio), photos (avatar), other user content
  (ratings/reviews/vibes), contacts (the follow graph).
- Required-reason API: **UserDefaults — `CA92.1`** (app's own settings). Required because the
  Supabase SDK persists its session there.

If you later add analytics, a crash reporter or ads, this file **and** the App Privacy
answers must both be updated — Apple cross-checks them.

---

## 5. App Privacy questionnaire — paste these answers **[NEEDS YOU]**

App Store Connect → your app → App Privacy → "Yes, we collect data from this app".

| Category | Data type | Collected | Linked to user | Used for tracking | Purpose |
| -------- | --------- | --------- | -------------- | ----------------- | ------- |
| Contact Info | Email Address | Yes | Yes | No | App Functionality |
| Contact Info | Name | No | – | – | – |
| User Content | Other User Content (ratings, reviews, vibe colours) | Yes | Yes | No | App Functionality |
| User Content | Photos or Videos (profile avatar) | Yes | Yes | No | App Functionality |
| Identifiers | User ID (account UUID / username) | Yes | Yes | No | App Functionality |
| Contacts | (the follow graph) | Yes | Yes | No | App Functionality |
| Usage Data | – | No | – | – | – |
| Diagnostics | – | No | – | – | – |
| Location, Financial, Health, Browsing, Search History, Purchases, Sensitive Info | – | No | – | – | – |

Answer **"No"** to *"Do you or your third-party partners use data for tracking?"* — Spectrum
has no ad SDK, no analytics, no IDFA, and therefore must **not** show an ATT prompt.

Note honestly, if asked: profile data (username, bio, avatar, ratings) is **publicly visible
to other users of the app** by design. That is a product property, not a privacy violation,
but the privacy policy must say so plainly.

---

## 6. Apple Music / MusicKit review considerations **[NEEDS YOU]**

1. **Enable the MusicKit service** for App ID `berkay.Spectrum` in the Developer portal
   (identifiers → App ID → App Services → MusicKit). Already reported as enabled — reconfirm,
   because catalog requests fail without it and a reviewer would see an empty app.
2. **The reviewer must be able to use the app.** MusicKit catalog search requires
   authorization, and the reviewer will tap "Don't Allow" at least once. `MusicAccessView`
   exists to explain this — confirm on device that the app is not a dead end in that state.
   An app that looks broken when a permission is declined gets rejected under 2.1.
3. **Review notes: supply a working demo account** (email + password). Spectrum gates
   everything behind sign-up; a reviewer who cannot get in will reject under 2.1. Add it in
   App Store Connect → App Review Information → Sign-In Required.
4. **Attribution / branding (Guideline 5.2.1 + the Apple Music Identity Guidelines).**
   - Where content comes from Apple Music, credit it. A visible "Music data provided by
     Apple Music" line in Settings satisfies this; `SettingsView` already shows
     *"Music data — Apple Music (MusicKit)"*, which is a reasonable minimum.
   - **Do not** use the Apple Music logo, the word "Apple" in the app name, or imply
     endorsement.
   - **Do not** let previews be presented as full tracks. Spectrum plays only the 30-second
     `previewAssets` — correct.
   - Artwork must be shown unmodified, not cropped into a logo or overlaid with your own
     branding.
5. **Do not claim "listen to full songs"** anywhere in the description; the app does not
   (and would require an Apple Music subscription to).

---

## 7. Supabase security — the part with the most risk left **[NEEDS YOU]**

The embedded key **[VERIFIED]** is the `anon` key (`"role":"anon"` in the JWT). Embedding it
is correct and by design. There is **no** `service_role` key in the source. `SpotifyCredentials.txt`
is gitignored **[VERIFIED]**.

That means **RLS is the only thing standing between the anon key and your entire database.**
Anyone can extract that key from the IPA in minutes. If RLS is off on even one table, that
table is world-readable *and world-writable*.

### 7.1 Audit script — run this first

```sql
-- 1. Is RLS actually on?  Anything with rowsecurity = false is fully exposed.
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

-- 2. What policies exist?
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd;
```

### 7.2 The policy set the app's code actually requires

Derived from every query in `SupabaseManager`. Read is public (the app shows other people's
logs and profiles); writes are restricted to the owner.

```sql
-- profiles ------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles are publicly readable"
  on public.profiles for select using (true);
create policy "users insert their own profile"
  on public.profiles for insert with check (auth.uid() = id);
create policy "users update their own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "users delete their own profile"       -- REQUIRED by account deletion
  on public.profiles for delete using (auth.uid() = id);

-- reviews / album_reviews / artist_reviews ----------------------------------
-- Repeat verbatim for all three tables.
alter table public.reviews enable row level security;

create policy "reviews are publicly readable"
  on public.reviews for select using (true);
create policy "users insert their own reviews"
  on public.reviews for insert with check (auth.uid() = user_id);
create policy "users update their own reviews"
  on public.reviews for update using (auth.uid() = user_id);
create policy "users delete their own reviews"       -- REQUIRED by delete-log AND deletion
  on public.reviews for delete using (auth.uid() = user_id);

-- follows -------------------------------------------------------------------
alter table public.follows enable row level security;

create policy "follows are publicly readable"
  on public.follows for select using (true);
create policy "users create their own follows"
  on public.follows for insert with check (auth.uid() = follower_id);
-- Both directions: deleting an account must remove rows where the user is the
-- FOLLOWED party too, otherwise other people keep a follower who no longer exists.
create policy "users remove follows they are part of"
  on public.follows for delete
  using (auth.uid() = follower_id or auth.uid() = following_id);
```

> A missing **DELETE** policy is the trap here. `writeReview`'s duplicate cleanup swallows
> delete failures by design, and account deletion would silently leave rows behind while the
> app reports success. Verify deletion actually removes rows before you rely on it.

### 7.3 Schema the Swift code assumes **[VERIFIED against the Codable models]**

| Table | Columns read/written |
| ----- | -------------------- |
| `profiles` | `id` (uuid, PK = auth.users.id), `username` (unique), `avatar_url`, `bio` |
| `reviews` | `id` (uuid), `user_id`, `itunes_track_id` (int8), `spotify_track_id`, `rating` (int, 0–10), `review_text`, `vibe_color`, `created_at` |
| `album_reviews` | `id`, `user_id`, `itunes_collection_id` (int8), `rating`, `review_text`, `vibe_color`, `created_at` |
| `artist_reviews` | `id`, `user_id`, `artist_name` (text), `rating`, `review_text`, `vibe_color`, `created_at` |
| `follows` | `id`, `follower_id`, `following_id`, `created_at` |
| Storage | public bucket `avatars`, object path `<user_uuid>/avatar.jpg` |

### 7.4 Still outstanding on the backend

- **Uniqueness constraints are still not applied.** The app no longer *needs* them (the
  read-then-write path in `writeReview` works without them), but without them two rapid saves
  can still race into duplicate rows. Recommended:
  ```sql
  delete from public.reviews a using public.reviews b
   where a.user_id = b.user_id and a.itunes_track_id = b.itunes_track_id
     and a.created_at < b.created_at;
  alter table public.reviews
    add constraint reviews_user_track_unique unique (user_id, itunes_track_id);

  delete from public.album_reviews a using public.album_reviews b
   where a.user_id = b.user_id and a.itunes_collection_id = b.itunes_collection_id
     and a.created_at < b.created_at;
  alter table public.album_reviews
    add constraint album_reviews_user_album_unique unique (user_id, itunes_collection_id);

  -- Artist names are matched case-insensitively by the app, so the constraint must be too.
  delete from public.artist_reviews a using public.artist_reviews b
   where a.user_id = b.user_id and lower(a.artist_name) = lower(b.artist_name)
     and a.created_at < b.created_at;
  create unique index artist_reviews_user_artist_unique
    on public.artist_reviews (user_id, lower(artist_name));

  alter table public.follows
    add constraint follows_unique unique (follower_id, following_id);
  ```
- **Indexes** for the app's hot paths:
  ```sql
  create index if not exists reviews_created_at_idx on public.reviews (created_at desc);
  create index if not exists reviews_user_idx on public.reviews (user_id);
  create index if not exists reviews_track_idx on public.reviews (itunes_track_id);
  create index if not exists album_reviews_album_idx on public.album_reviews (itunes_collection_id);
  create index if not exists artist_reviews_name_idx on public.artist_reviews (lower(artist_name));
  create index if not exists follows_follower_idx on public.follows (follower_id);
  create index if not exists follows_following_idx on public.follows (following_id);
  ```
- **Email confirmation must be ON** (Auth → Providers → Email → Confirm email). Off means
  anyone can create accounts with addresses they don't own.
- **Optional, removes the last client-side aggregation** (see the trending note in code):
  ```sql
  create or replace view public.trending_tracks as
    select distinct on (itunes_track_id) itunes_track_id, created_at
    from public.reviews order by itunes_track_id, created_at desc;
  ```
  then order that view by `created_at desc` with a small `limit`.
- **Storage policies** for `avatars` — use the per-user-folder version in `SPECTRUM_NOTES.md`
  §2b, and add a delete policy so account deletion can remove the avatar:
  ```sql
  create policy "users delete their own avatar"
    on storage.objects for delete
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
  ```

---

## 8. Store listing — what only you can supply **[NEEDS YOU]**

| Item | Requirement | Notes |
| ---- | ----------- | ----- |
| **Privacy policy URL** | **Mandatory.** Must be live before submission | Must state: what you collect (§5), that profiles/logs are public, that data is stored by Supabase, how to delete an account, and a contact address. A GitHub Pages or Notion page is acceptable |
| **Support URL** | **Mandatory.** Must be live and reachable | A simple page with an email address is enough |
| **Marketing URL** | Optional | – |
| **Screenshots** | 6.9" (iPhone 16 Pro Max, 1320×2868) **and** 6.5". iPad required *only if* you keep `UIDeviceFamily = [1,2]` (§3.2) | Must show the real app. Must be taken on a **device** — MusicKit is empty in the Simulator, so Simulator screenshots would show an empty app |
| **App preview video** | Optional | – |
| **Age rating** | Expect **12+** | Spectrum has user-generated text reviews and user-to-user following → "Infrequent/Mild Mature or Suggestive Themes" is likely once UGC is declared. Answer the questionnaire honestly; under-rating gets caught |
| **Category** | Music (primary); Social Networking (secondary) | – |
| **Demo account** | **Mandatory** — the app is fully gated behind sign-up | App Review Information → Sign-In Required |
| **Review notes** | Strongly recommended | Explain: MusicKit access is required for search to return anything; the app plays 30-second previews only; no subscription needed |
| **Copyright** | e.g. `2026 Berkay Cefakar` | – |

### User-generated content — Guideline 1.2 **[NEEDS YOU, likely rejection if skipped]**

Spectrum lets users post text reviews and follow each other. Apple requires apps with UGC to
have **all** of:

1. A method to **filter objectionable material** — even a basic profanity filter on
   `review_text`.
2. A mechanism for users to **report offensive content**, with a response commitment.
3. The ability to **block abusive users**.
4. Published contact information for the developer.

**Status: 1–3 are now implemented in the app. 4 is still on you.**

| Requirement | Where it lives now |
| ----------- | ------------------ |
| Filter objectionable material | `Core/Utils/ProfanityFilter.swift`. Enforced in `SupabaseManager.writeReview` — the single choke point all three review writes (song / album / artist) pass through, so a screen added later can't skip it. Also applied on *read* (`ProfanityFilter.masked`) in the feed card, track detail, log detail and activity card, because rows written before the filter existed are still in the database. |
| Report offensive content | `UI/Screens/ReportContentView.swift` (reason picker + optional details + a stated 24-hour response commitment). Reachable by long-pressing a feed card or a community review (`UI/Components/ModerationActions.swift`), and from the ⋯ menu on another user's profile. Writes to `content_reports`. |
| Block abusive users | Same long-press menu, the profile ⋯ menu, and offered again right after a report is filed. Blocked users disappear from the feed, search, activity, and every per-item review list. Reversible in **Settings → Blocked Users** (`UI/Screens/BlockedUsersView.swift`), which Apple expects. |
| Published contact information | **[NEEDS YOU]** — App Store Connect support URL / email. Nothing in the code can satisfy this. |

**Before this works you must run `Supabase_migration_ugc_reports_blocks.sql`** (creates
`content_reports` and `user_blocks`, their RLS policies, and a trigger that tears down the
follow relationship in both directions when a block is inserted — doing that in the app would
leave it half-done whenever the connection drops).

Moderation itself is manual: reports land in `content_reports` with `status = 'pending'`, and
only the service role can read the queue or change a status. Check it in the dashboard —
`select * from content_reports where status = 'pending' order by created_at;`

---

## 9. Smaller quality items

- **Mixed languages.** `EditProfileView` shows Turkish error strings ("Kullanıcı adı boş
  olamaz.", "Bu kullanıcı adı zaten kullanılıyor.") while the rest of the UI is English. Pick
  one, or localize properly with a String Catalog. Reviewers do notice.
- **Code comments in Turkish** in `AlbumDetailView`, `FeedView`, `Track.swift` — harmless,
  but inconsistent with the rest of the codebase.
- **`SpotifyCredentials.txt`** is gitignored and unused; delete it to remove the temptation.
- **No crash reporting.** Consider adding one *after* launch — and remember it changes §4/§5.
- **No empty-state for a failed artist load**: `ArtistDetailView` shows a bare page if both
  the id lookup and the name search fail.

---

## 10. Suggested order of work

1. Run the RLS audit (§7.1) and apply the policies (§7.2). **Nothing else matters if this is wrong.**
2. Deploy the `delete-user` Edge Function (§1.2) and point the app at it.
3. Implement UGC report/block/filter (§8).
4. Decide iPhone-only vs iPad (§3.2) and set orientations to match.
5. Test everything on a **real device** — none of this pass has been visually verified.
6. Publish privacy policy + support URLs; capture device screenshots.
7. Create the demo account, write review notes, submit.
