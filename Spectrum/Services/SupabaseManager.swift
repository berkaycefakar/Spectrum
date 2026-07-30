import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Configuration Placeholders
    private let supabaseURL = URL(string: "https://ysgbqlltzdhgsezukxxm.supabase.co")!
    // FIX: Ensure the key is on a single line without breaks
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzZ2JxbGx0emRoZ3NlenVreHhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwMDU2NTYsImV4cCI6MjA4NDU4MTY1Nn0.C6cpEojPrZw4DEHNTePMEhrn0cikqfZ9oUvCEN63LLQ"
    
    /// Deep link used by Supabase email confirmations / magic links.
    /// You must also add this to Supabase Dashboard → Auth → URL Configuration → Redirect URLs.
    private let authRedirectURL = URL(string: "spectrum://auth-callback")!
    
    let client: SupabaseClient

    /// Blocked-user ids, cached for a minute: the feed, search, activity and profile screens
    /// all need this on every load, and it only changes when the user blocks someone.
    ///
    /// An actor rather than two stored properties. Every method here is `nonisolated async`,
    /// so each one resumes on an arbitrary cooperative thread — and the feed refresh, the
    /// activity tab's `.task` and the four parallel searches in Discover routinely overlap.
    /// Concurrent writes to a plain `Set<UUID>?` are a torn write on a refcounted box, i.e. a
    /// crash in `swift_release`, not just a stale read.
    private let blockedCache = BlockedIdsCache()

    private init() {
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                redirectToURL: authRedirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey, options: options)
    }
    
    // MARK: - Auth
    
    /// Returns the currently authenticated user, or nil if not logged in.
    /// In Supabase Swift 2.x, session is accessed via currentSession (sync) or session (async).
    func getCurrentUser() async throws -> User? {
        // Use currentSession for synchronous access - returns nil if not logged in
        return client.auth.currentSession?.user
    }
    
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }
    
    /// What happened after a sign-up attempt — the caller needs to know whether it can send
    /// the user straight into the app or has to ask them to check their inbox.
    enum SignUpOutcome {
        /// A session exists: the user is already logged in, no second trip through the form.
        case signedIn
        /// The Supabase project has "Confirm email" switched on, so there is no session yet.
        case needsEmailConfirmation
    }

    @discardableResult
    func signUp(email: String, password: String, username: String) async throws -> SignUpOutcome {
        // 1. Create Auth User
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)],
            redirectTo: authRedirectURL
        )

        // 2. With email confirmation enabled there is no session yet, so we are still an
        //    anonymous caller — writing the profile row here would be refused by RLS and the
        //    user would see a scary error for an account that was actually created fine.
        //    `ensureProfile` runs on their first real sign-in instead.
        guard response.session != nil else {
            return .needsEmailConfirmation
        }

        try await ensureProfile(userId: response.user.id, preferredUsername: username)
        return .signedIn
    }

    /// Creates the `profiles` row if this account doesn't have one yet.
    ///
    /// Needed on every entry path, not just sign-up: Apple and Google hand us an account with
    /// no username at all, and email sign-ups whose profile insert was deferred (see above)
    /// arrive here on their first sign-in. Safe to call repeatedly.
    @discardableResult
    func ensureProfile(userId: UUID, preferredUsername: String?) async throws -> Profile {
        if let existing = try? await getProfile(userId: userId) {
            return existing
        }

        let base = Self.sanitizedUsername(preferredUsername) ?? "listener"

        // `profiles.username` is unique, so a taken name has to be nudged rather than retried
        // forever — three attempts is plenty and keeps sign-in from hanging on a bad day.
        for attempt in 0..<3 {
            let candidate = attempt == 0 ? base : "\(base)\(Int.random(in: 1000...9999))"
            let profile = Profile(id: userId, username: candidate, avatarUrl: nil, bio: nil)
            do {
                try await client.from("profiles").insert(profile).execute()
                return profile
            } catch {
                let message = error.localizedDescription
                let isDuplicate = message.contains("duplicate key") || message.contains("profiles_username_key")
                guard isDuplicate, attempt < 2 else { throw error }
            }
        }

        return try await getProfile(userId: userId)
    }

    /// Turns an email address or a person's name into something usable as a username.
    private static func sanitizedUsername(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let localPart = raw.split(separator: "@").first.map(String.init) ?? raw
        let allowed = localPart.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let trimmed = String(allowed.prefix(20))
        return trimmed.count >= 3 ? trimmed : nil
    }

    // MARK: - Social sign-in

    /// Exchanges an Apple identity token for a Supabase session.
    ///
    /// Apple only discloses the user's name on the *very first* authorization, so the caller
    /// passes it through here — after that it is gone for good and we fall back to the email.
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        try await ensureProfile(
            userId: session.user.id,
            preferredUsername: fullName ?? session.user.email
        )
    }

    /// Google sign-in through the system browser sheet.
    ///
    /// Deliberately the OAuth web flow rather than the GoogleSignIn SDK: it needs no extra
    /// dependency, no client-id in the bundle, and Supabase already owns the redirect.
    /// Requires Google to be enabled in Supabase → Auth → Providers, and
    /// `spectrum://auth-callback` listed under Redirect URLs.
    func signInWithGoogle() async throws {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: authRedirectURL
        )
        try await ensureProfile(
            userId: session.user.id,
            preferredUsername: session.user.email
        )
    }

    // MARK: - Password reset

    /// Sends the "reset your password" email. Always report success to the caller even for an
    /// address with no account — telling a stranger which emails are registered is a
    /// disclosure we don't need to make.
    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: authRedirectURL)
    }

    /// Replaces the password on the currently signed-in account.
    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Account Deletion

    /// Erases everything this account owns, then signs out.
    ///
    /// App Store Review Guideline 5.1.1(v) requires any app that lets a user *create* an
    /// account to let them delete it from inside the app. Spectrum had sign-up but no way
    /// out, which is a straightforward rejection.
    ///
    /// Prefers the `delete-user` Edge Function (`supabase/functions/delete-user`), which is the
    /// only thing that can remove the `auth.users` row — that needs the service-role key, and
    /// shipping that key inside the app would hand every user full admin access to the
    /// database. If the function isn't deployed yet, this falls back to clearing everything the
    /// app itself owns, which leaves an orphaned auth row holding only the email address.
    func deleteAccount() async throws {
        do {
            try await client.functions.invoke("delete-user")
            // The server has already destroyed the account; all that's left is the local
            // session. Sign-out failures are ignored: the account is gone either way, and
            // `SessionStore` clears local state regardless.
            try? await client.auth.signOut()
            return
        } catch {
            // Only a *missing* function is a reason to fall back. Any other status means the
            // function ran and failed partway — swallowing that told the user their account
            // was deleted while the auth.users row survived, so they could never re-register
            // with the same address. That is exactly the 5.1.1(v) rejection this code exists
            // to prevent, and it was invisible because the error was only printed.
            guard Self.isFunctionMissing(error) else { throw error }
            #if DEBUG
            print("delete-user Edge Function not deployed, falling back to client-side deletion:", error)
            #endif
        }

        try await deleteAccountClientSide()
    }

    /// True when the Edge Function simply isn't deployed, as opposed to having failed.
    private static func isFunctionMissing(_ error: Error) -> Bool {
        if let functionsError = error as? FunctionsError,
           case let .httpError(code, _) = functionsError {
            return code == 404
        }
        // No network at all: the function may well be there, but the client-side path can't
        // reach the database either, so it will surface its own error a moment later.
        let urlError = error as? URLError
        return urlError?.code == .notConnectedToInternet || urlError?.code == .cannotFindHost
    }

    /// Fallback path: erases everything the app owns, then signs out.
    ///
    /// Order matters. Owned content goes first, then the follow graph, then the avatar, then
    /// the profile row — so that if the run is interrupted we never leave a profile pointing
    /// at content that no longer exists (a half-deleted profile still reads as a live user).
    private func deleteAccountClientSide() async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(
                domain: "Spectrum",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"]
            )
        }
        let userId = user.id

        // 1. Everything the user wrote.
        for table in ["reviews", "album_reviews", "artist_reviews"] {
            try await client.from(table).delete().eq("user_id", value: userId).execute()
        }

        // 2. The follow graph, in both directions — otherwise other people keep a follower
        //    that no longer exists and their counts stay wrong forever.
        try await client.from("follows").delete().eq("follower_id", value: userId).execute()
        try await client.from("follows").delete().eq("following_id", value: userId).execute()

        // 3. Their own block list. Rows where they are the *blocked* party can't be removed
        //    from here — RLS scopes deletes to the blocker — and don't need to be: the
        //    foreign key cascades once the Edge Function removes the auth row.
        try? await client.from("user_blocks").delete().eq("blocker_id", value: userId).execute()

        // 4. The avatar. Best-effort: a storage failure must not block the deletion, and a
        //    user who never uploaded one has nothing at this path.
        do {
            _ = try await client.storage
                .from("avatars")
                .remove(paths: ["\(userId.uuidString)/avatar.jpg"])
        } catch {
            print("Account deletion: couldn't remove avatar object:", error)
        }

        // 5. The profile row — the last thing that makes the account visible to anyone else.
        try await client.from("profiles").delete().eq("id", value: userId).execute()

        // 6. Drop the local session.
        try await client.auth.signOut()
    }
    
    // MARK: - Profiles
    
    func getProfile(userId: UUID) async throws -> Profile {
        let response: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return response
    }
    
    func updateProfile(userId: UUID, username: String, bio: String) async throws {
        try Self.rejectProfanity(username: username, bio: bio)
        let updateData = ProfileUpdate(username: username, bio: bio)
        try await client
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    /// Updates username, bio, and (optionally) the avatar URL in one call.
    func updateProfile(userId: UUID, username: String, bio: String, avatarUrl: String?) async throws {
        try Self.rejectProfanity(username: username, bio: bio)
        let updateData = ProfileUpdateFull(username: username, bio: bio, avatar_url: avatarUrl)
        try await client
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    /// Usernames and bios are user-generated content too: they render on every card in the
    /// feed and in search results, and a bio is what a profile report quotes. Guideline 1.2
    /// makes no distinction between a review and a display name, so both go through the same
    /// filter that `writeReview` applies.
    private static func rejectProfanity(username: String, bio: String) throws {
        let offending = ProfanityFilter.firstMatch(in: username)
            ?? ProfanityFilter.firstMatch(in: bio)
        guard let offending else { return }
        throw NSError(
            domain: "Spectrum",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey:
                "Please take out “\(offending)” — your profile can't contain offensive language."]
        )
    }

    /// Uploads avatar image data to the `avatars` storage bucket and returns its public URL.
    /// Requires a public bucket named `avatars` to exist in Supabase Storage.
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        // Per-user folder so a storage policy can restrict writes to a user's own folder.
        // Stable filename so a new upload overwrites the old avatar instead of piling up.
        let path = "\(userId.uuidString)/avatar.jpg"

        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )

        // Cache-buster: the public URL is stable across uploads, so without this the UI would
        // keep showing the previous image from cache.
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
    }
    
    // MARK: - Reviews
    
    func getUserReviews(userId: UUID) async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func saveReview(trackId: Int, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        let newReview = NewReview(
            user_id: user.id,
            itunes_track_id: Int64(trackId),
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )

        // Look the row up and edit it in place rather than `upsert(onConflict:)`. Postgres
        // rejects ON CONFLICT outright ("no unique or exclusion constraint matching the ON
        // CONFLICT specification") unless a matching unique index exists, so re-logging a
        // song failed on any database where that migration hadn't been run.
        try await writeReview(
            table: "reviews",
            existingIds: try await existingReviewIds(
                table: "reviews",
                userId: user.id,
                targetColumn: "itunes_track_id",
                targetValue: Int(trackId)
            ),
            insert: newReview,
            rating: rating,
            text: text,
            vibeColor: vibeColor
        )
    }

    // MARK: - Review write helpers

    /// Ids of the current user's existing rows for one target, newest first.
    private func existingReviewIds(
        table: String,
        userId: UUID,
        targetColumn: String,
        targetValue: any URLQueryRepresentable
    ) async throws -> [UUID] {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from(table)
            .select("id")
            .eq("user_id", value: userId)
            .eq(targetColumn, value: targetValue)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(\.id)
    }

    /// Same as above but matching the target case-insensitively. Only used for artists, which
    /// are keyed by name: MusicKit isn't perfectly consistent about capitalisation between
    /// endpoints, so an exact match would let one artist become two rows.
    private func existingReviewIdsIgnoringCase(
        table: String,
        userId: UUID,
        targetColumn: String,
        targetValue: String
    ) async throws -> [UUID] {
        struct Row: Decodable {
            let id: UUID
            let artist_name: String
        }
        let rows: [Row] = try await client
            .from(table)
            .select("id, \(targetColumn)")
            .eq("user_id", value: userId)
            .ilike(targetColumn, pattern: Self.literalPattern(targetValue))
            .order("created_at", ascending: false)
            .execute()
            .value
        // The pattern is a superset (see `literalPattern`), so the name is compared here to
        // make the match exact. Updating the wrong row would overwrite another rating.
        return rows.filter { Self.matches($0.artist_name, targetValue) }.map(\.id)
    }

    /// Escapes a value so it can be used as an `ilike` pattern that matches it literally.
    /// Without this, an artist called "_" or one with a "%" in their name would match rows
    /// belonging to somebody else entirely.
    ///
    /// `*` cannot be escaped: PostgREST rewrites it to `%` on the server, *after* whatever
    /// escaping we do here, so a backslash never reaches it. It is mapped to `_` instead,
    /// which matches exactly one character and so always still matches the literal `*`. That
    /// makes the pattern a superset rather than a wildcard, and callers narrow it with
    /// `matches(_:_:)`. Left alone, an artist named `N*E*R*D` searched as `N%E%R%D` and could
    /// select a *different* review by the same user — which `writeReview` would then update
    /// and delete the rest of, losing a rating silently.
    static func literalPattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "*", with: "_")
    }

    /// Pattern for a user-typed search box, where `*` carries no meaning worth preserving.
    /// Dropped entirely rather than mapped: `%_%` still matches every row, so typing a single
    /// `*` would keep listing the whole user table.
    static func searchPattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Exact, case-insensitive name comparison. The `ilike` filters above are deliberately
    /// permissive so no row is missed; this is what makes the result exact again.
    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Updates the newest existing row, or inserts when there is none.
    ///
    /// Also deletes any older rows for the same target: the album path used to `upsert`
    /// without a conflict target, which Postgres resolves against the primary key — and since
    /// the payload carries no `id`, every save inserted a *fresh* row. Users ended up with a
    /// pile of duplicate ratings for one album and edits appeared to do nothing. Cleaning the
    /// extras up here heals the rows that bug already created.
    private func writeReview(
        table: String,
        existingIds: [UUID],
        insert: some Encodable,
        rating: Int,
        text: String,
        vibeColor: String
    ) async throws {
        // The single choke point every review write goes through — song, album and artist. The
        // check lives here rather than in each sheet so a screen added later can't skip it.
        // App Store Review Guideline 1.2 requires filtering objectionable user content.
        if let offending = ProfanityFilter.firstMatch(in: text) {
            throw NSError(
                domain: "Spectrum",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey:
                    "Please take out “\(offending)” — reviews can't contain offensive language."]
            )
        }

        guard let keeper = existingIds.first else {
            try await client.from(table).insert(insert).execute()
            return
        }

        try await client
            .from(table)
            .update(ReviewUpdate(rating: rating, review_text: text, vibe_color: vibeColor))
            .eq("id", value: keeper)
            .execute()

        // Best-effort: the edit itself has already landed, so a missing RLS delete policy
        // shouldn't surface to the user as "couldn't save".
        let stale = existingIds.dropFirst().map(\.uuidString)
        if !stale.isEmpty {
            do {
                try await client.from(table).delete().in("id", values: stale).execute()
            } catch {
                print("Couldn't clean up \(stale.count) duplicate \(table) row(s):", error)
            }
        }
    }

    /// Deletes the current user's log for a track.
    func deleteReview(trackId: Int64) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        try await client
            .from("reviews")
            .delete()
            .eq("user_id", value: user.id)
            .eq("itunes_track_id", value: Int(trackId))
            .execute()
    }
    
    /// Track ids that the community has logged most recently, de-duplicated, newest first.
    /// Used to drive a real "trending" row on Discover instead of a hardcoded artist list.
    ///
    /// De-duplication happens client-side because PostgREST has no `DISTINCT ON`, so we
    /// over-fetch and collapse. The window scales with what the caller actually wants rather
    /// than always pulling a flat 200 rows: Discover asks for 12, which now costs 120 rows
    /// instead of 200. If Discover ever needs to be cheaper than this, the right fix is a
    /// Postgres view (`create view trending_tracks as select distinct on (itunes_track_id)
    /// ...`) — noted in APP_STORE_READINESS.md.
    func fetchTrendingTrackIds(limit: Int = 20) async throws -> [Int64] {
        struct Row: Decodable { let itunes_track_id: Int64 }
        let window = min(max(limit * 10, 50), 200)
        let rows: [Row] = try await client
            .from("reviews")
            .select("itunes_track_id")
            .order("created_at", ascending: false)
            .limit(window)
            .execute()
            .value

        // Preserve recency order while removing repeats.
        var seen = Set<Int64>()
        var ordered: [Int64] = []
        for row in rows where !seen.contains(row.itunes_track_id) {
            seen.insert(row.itunes_track_id)
            ordered.append(row.itunes_track_id)
            if ordered.count >= limit { break }
        }
        return ordered
    }

    func getTrackReviews(trackId: Int64) async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .eq("itunes_track_id", value: Int(trackId))
            .order("created_at", ascending: false)
            .execute()
            .value
        let blocked = await blockedUserIds()
        return response.filter { !blocked.contains($0.userId) }
    }
    
    // MARK: - Album Reviews
    
    func saveAlbumReview(collectionId: Int64, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let newReview = NewAlbumReview(
            user_id: user.id,
            itunes_collection_id: collectionId,
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )

        try await writeReview(
            table: "album_reviews",
            existingIds: try await existingReviewIds(
                table: "album_reviews",
                userId: user.id,
                targetColumn: "itunes_collection_id",
                targetValue: Int(collectionId)
            ),
            insert: newReview,
            rating: rating,
            text: text,
            vibeColor: vibeColor
        )
    }

    /// The current user's rating for one album, newest first — cheaper and more correct than
    /// pulling their whole album history and filtering it client-side.
    func getUserAlbumReview(collectionId: Int64) async throws -> AlbumReview? {
        guard let user = try await getCurrentUser() else { return nil }
        let rows: [AlbumReview] = try await client
            .from("album_reviews")
            .select()
            .eq("user_id", value: user.id)
            .eq("itunes_collection_id", value: Int(collectionId))
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func getUserAlbumReviews(userId: UUID) async throws -> [AlbumReview] {
        let response: [AlbumReview] = try await client
            .from("album_reviews")
            .select()
            .eq("user_id", value: userId)
            .order("rating", ascending: false) // Highest first
            .execute()
            .value
        return response
    }
    
    func getAlbumReviews(collectionId: Int64) async throws -> [AlbumReview] {
        let response: [AlbumReview] = try await client
            .from("album_reviews")
            .select()
            .eq("itunes_collection_id", value: Int(collectionId))
            .order("created_at", ascending: false)
            .execute()
            .value
        let blocked = await blockedUserIds()
        return response.filter { !blocked.contains($0.userId) }
    }
    
    // MARK: - Artist Reviews
    
    func saveArtistReview(artistName: String, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let newReview = NewArtistReview(
            user_id: user.id,
            artist_name: artistName,
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )

        try await writeReview(
            table: "artist_reviews",
            existingIds: try await existingReviewIdsIgnoringCase(
                table: "artist_reviews",
                userId: user.id,
                targetColumn: "artist_name",
                targetValue: artistName
            ),
            insert: newReview,
            rating: rating,
            text: text,
            vibeColor: vibeColor
        )
    }

    /// The current user's rating for one artist.
    func getUserArtistReview(artistName: String) async throws -> ArtistReview? {
        guard let user = try await getCurrentUser() else { return nil }
        let rows: [ArtistReview] = try await client
            .from("artist_reviews")
            .select()
            .eq("user_id", value: user.id)
            .ilike("artist_name", pattern: Self.literalPattern(artistName))
            .order("created_at", ascending: false)
            .execute()
            .value
        // No `.limit(1)`: the pattern is a superset, so the first row back isn't necessarily
        // this artist. Narrow first, then take the newest.
        return rows.first { Self.matches($0.artistName, artistName) }
    }

    func getUserArtistReviews(userId: UUID) async throws -> [ArtistReview] {
        let response: [ArtistReview] = try await client
            .from("artist_reviews")
            .select()
            .eq("user_id", value: userId)
            .order("rating", ascending: false) // Highest first
            .execute()
            .value
        return response
    }
    
    /// Everyone's ratings for one artist.
    ///
    /// Matched case-insensitively on purpose. Artists are keyed by *name* here (there is no
    /// artist id column), so an exact match split "Tyler, The Creator" from "TYLER, THE
    /// CREATOR" into two separate artists with two separate community averages. Casing is the
    /// variation this can fix; differing punctuation still can't be reconciled without
    /// storing the MusicKit artist id — see the note in HANDOFF.md.
    func getArtistReviews(artistName: String) async throws -> [ArtistReview] {
        let response: [ArtistReview] = try await client
            .from("artist_reviews")
            .select()
            .ilike("artist_name", pattern: Self.literalPattern(artistName))
            .order("created_at", ascending: false)
            .execute()
            .value
        let blocked = await blockedUserIds()
        return response.filter {
            Self.matches($0.artistName, artistName) && !blocked.contains($0.userId)
        }
    }
    
    // MARK: - User Search
    
    func searchUsers(query: String) async throws -> [Profile] {
        // Escaped: an unescaped `%`, `_` or `*` typed into the search field is a wildcard, so
        // searching for any one of them used to return every user in the database.
        let response: [Profile] = try await client
            .from("profiles")
            .select()
            .ilike("username", pattern: "%\(Self.searchPattern(query))%")
            .limit(30)
            .execute()
            .value

        let blocked = await blockedUserIds()
        return response.filter { !blocked.contains($0.id) }
    }
    
    // MARK: - Follows
    
    func followUser(userId: UUID) async throws {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Check first to avoid duplicate insert
        let already = try await isFollowing(userId: userId)
        if already { return }
        
        struct FollowInsert: Encodable {
            let follower_id: UUID
            let following_id: UUID
        }
        
        let follow = FollowInsert(follower_id: currentUser.id, following_id: userId)
        
        try await client
            .from("follows")
            .insert(follow)
            .execute()
    }
    
    func unfollowUser(userId: UUID) async throws {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        try await client
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUser.id)
            .eq("following_id", value: userId)
            .execute()
    }
    
    func getFollowing(userId: UUID) async throws -> [Profile] {
        struct FollowRow: Codable {
            let following_id: UUID
        }

        let response: [FollowRow] = try await client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value

        guard !response.isEmpty else { return [] }
        let ids = response.map { $0.following_id.uuidString }
        return try await batchGetProfiles(ids: ids)
    }

    func getFollowers(userId: UUID) async throws -> [Profile] {
        struct FollowRow: Codable {
            let follower_id: UUID
        }

        let response: [FollowRow] = try await client
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: userId)
            .execute()
            .value

        guard !response.isEmpty else { return [] }
        let ids = response.map { $0.follower_id.uuidString }
        return try await batchGetProfiles(ids: ids)
    }

    /// Batch fetch profiles by IDs in a single query (avoids N+1)
    func batchGetProfiles(ids: [String]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        let response: [Profile] = try await client
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return response
    }
    
    func isFollowing(userId: UUID) async throws -> Bool {
        guard let currentUser = try await getCurrentUser() else {
            return false
        }
        
        struct FollowCheck: Codable {
            let follower_id: UUID
        }
        
        let response: [FollowCheck] = try await client
            .from("follows")
            .select("follower_id")
            .eq("follower_id", value: currentUser.id)
            .eq("following_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - Feed
    
    func fetchRecentReviews() async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .order("created_at", ascending: false)
            // Over-fetch so that filtering out blocked users doesn't leave a short feed.
            .limit(40)
            .execute()
            .value

        let blocked = await blockedUserIds()
        return response.filter { !blocked.contains($0.userId) }.prefix(20).map { $0 }
    }
    
    func fetchFollowingReviews(userId: UUID) async throws -> [Review] {
        // Get list of following user IDs
        let following = try await getFollowing(userId: userId)
        let followingIds = following.map { $0.id }
        
        guard !followingIds.isEmpty else {
            // If not following anyone, return empty or fallback to recent reviews
            return []
        }
        
        // Fetch reviews from followed users
        // Convert UUID array to String array for .in() method
        let blocked = await blockedUserIds()
        let userIdStrings = followingIds
            .filter { !blocked.contains($0) }
            .map { $0.uuidString }
        guard !userIdStrings.isEmpty else { return [] }

        let response: [Review] = try await client
            .from("reviews")
            .select()
            .in("user_id", values: userIdStrings)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return response
    }

    // MARK: - Activity Feed
    
    /// Fetches a mixed activity feed for the current user:
    /// - track and album reviews from people they follow
    /// - new followers (people who started following them)
    func fetchActivityFeed(limitPerType: Int = 30) async throws -> [ActivityItem] {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        struct FollowRelation: Codable {
            let follower_id: UUID
            let following_id: UUID
            let created_at: Date
        }
        
        // 1. Load follow relationships
        let followingRelations: [FollowRelation]
        do {
            followingRelations = try await client
                .from("follows")
                .select("follower_id,following_id,created_at")
                .eq("follower_id", value: currentUser.id)
                .execute()
                .value
        } catch {
            print("Activity: failed to load following relations:", error)
            followingRelations = []
        }
        
        let followerRelations: [FollowRelation]
        do {
            followerRelations = try await client
                .from("follows")
                .select("follower_id,following_id,created_at")
                .eq("following_id", value: currentUser.id)
                .execute()
                .value
        } catch {
            print("Activity: failed to load follower relations:", error)
            followerRelations = []
        }
        
        let followingIds = followingRelations.map { $0.following_id }
        let followerIds = followerRelations.map { $0.follower_id }
        
        // 2. Load profiles for all related users in a single query
        let allActorIds = Array(Set(followingIds + followerIds))
        let actorIdStrings = allActorIds.map { $0.uuidString }
        
        var profilesById: [UUID: Profile] = [:]
        if !actorIdStrings.isEmpty {
            do {
                let profileResponse: [Profile] = try await client
                    .from("profiles")
                    .select()
                    .in("id", values: actorIdStrings)
                    .execute()
                    .value
                for profile in profileResponse {
                    profilesById[profile.id] = profile
                }
            } catch {
                print("Activity: failed to load profiles:", error)
            }
        }
        
        // 3. Load reviews from people the user follows
        var activityItems: [ActivityItem] = []
        if !followingIds.isEmpty {
            let followingIdStrings = followingIds.map { $0.uuidString }
            
            // Track reviews
            let trackReviews: [Review]
            do {
                trackReviews = try await client
                    .from("reviews")
                    .select()
                    .in("user_id", values: followingIdStrings)
                    .order("created_at", ascending: false)
                    .limit(limitPerType)
                    .execute()
                    .value
            } catch {
                print("Activity: failed to load track reviews:", error)
                trackReviews = []
            }
            
            for review in trackReviews {
                let profile = profilesById[review.userId]
                let item = ActivityItem(
                    id: review.id,
                    type: .trackReview,
                    actorId: review.userId,
                    actorUsername: profile?.username,
                    actorAvatarUrl: profile?.avatarUrl,
                    targetId: String(review.itunesTrackId),
                    targetName: nil,
                    rating: review.rating,
                    vibeColor: review.vibeColor,
                    reviewText: review.reviewText,
                    createdAt: review.createdAt
                )
                activityItems.append(item)
            }
            
            // Album reviews
            let albumReviews: [AlbumReview]
            do {
                albumReviews = try await client
                    .from("album_reviews")
                    .select()
                    .in("user_id", values: followingIdStrings)
                    .order("created_at", ascending: false)
                    .limit(limitPerType)
                    .execute()
                    .value
            } catch {
                print("Activity: failed to load album reviews:", error)
                albumReviews = []
            }
            
            for review in albumReviews {
                let profile = profilesById[review.userId]
                let item = ActivityItem(
                    id: review.id,
                    type: .albumReview,
                    actorId: review.userId,
                    actorUsername: profile?.username,
                    actorAvatarUrl: profile?.avatarUrl,
                    targetId: String(review.itunesCollectionId),
                    targetName: nil,
                    rating: review.rating,
                    vibeColor: review.vibeColor,
                    reviewText: review.reviewText,
                    createdAt: review.createdAt
                )
                activityItems.append(item)
            }
        }
        
        // 4. New followers
        for relation in followerRelations {
            guard relation.follower_id != currentUser.id else { continue }
            let profile = profilesById[relation.follower_id]
            let item = ActivityItem(
                id: UUID(),
                type: .newFollower,
                actorId: relation.follower_id,
                actorUsername: profile?.username,
                actorAvatarUrl: profile?.avatarUrl,
                targetId: currentUser.id.uuidString,
                targetName: nil,
                rating: nil,
                vibeColor: nil,
                reviewText: nil,
                createdAt: relation.created_at
            )
            activityItems.append(item)
        }
        
        // 5. Sort by date, newest first, minus anyone the user has blocked.
        let blocked = await blockedUserIds()
        return activityItems
            .filter { !blocked.contains($0.actorId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Moderation: reports

    /// Files a report against a piece of content.
    ///
    /// Required by App Store Review Guideline 1.2 for user-generated content. The reporter is
    /// taken from the session, never from the caller — the RLS policy checks the same thing,
    /// so a tampered client can't file reports as somebody else.
    ///
    /// Reporting the same thing twice is not an error: a unique index collapses it, and the UI
    /// should read that as "already reported" rather than showing a failure.
    func submitReport(
        contentType: ReportedContentType,
        contentRef: String?,
        reportedUserId: UUID?,
        reason: ReportReason,
        details: String?,
        reportedText: String?
    ) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(
                domain: "Spectrum",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "You need to be signed in to report content."]
            )
        }

        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = NewContentReport(
            reporter_id: user.id,
            reported_user_id: reportedUserId,
            content_type: contentType.rawValue,
            content_ref: contentRef,
            reason: reason.rawValue,
            details: (trimmedDetails?.isEmpty == false) ? trimmedDetails : nil,
            reported_text: reportedText
        )

        do {
            try await client.from("content_reports").insert(payload).execute()
        } catch {
            // 23505 = unique violation: this user already reported this content.
            guard Self.isDuplicateKeyError(error) else { throw error }
        }
    }

    private static func isDuplicateKeyError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("23505") || description.contains("duplicate key")
    }

    // MARK: - Moderation: blocks

    /// Blocks a user. The database trigger tears down the follow relationship in both
    /// directions, so that can't be left half-done by a dropped connection.
    func blockUser(_ userId: UUID) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(
                domain: "Spectrum",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "You need to be signed in to block someone."]
            )
        }
        guard user.id != userId else {
            throw NSError(
                domain: "Spectrum",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "You can't block yourself."]
            )
        }

        do {
            try await client
                .from("user_blocks")
                .insert(NewUserBlock(blocker_id: user.id, blocked_id: userId))
                .execute()
        } catch {
            // Already blocked — the caller asked for a state, and it's already the state.
            guard Self.isDuplicateKeyError(error) else { throw error }
        }
        await invalidateBlockedCache()
    }

    func unblockUser(_ userId: UUID) async throws {
        guard let user = try await getCurrentUser() else { return }
        try await client
            .from("user_blocks")
            .delete()
            .eq("blocker_id", value: user.id)
            .eq("blocked_id", value: userId)
            .execute()
        await invalidateBlockedCache()
    }

    /// The ids the current user has blocked. Cached briefly because the feed, search, activity
    /// and profile screens all need it and it changes only when the user blocks someone.
    ///
    /// Two things this must get right, because a block that quietly stops applying is worse
    /// than no block at all:
    ///
    /// * **A failed query is not an empty block list.** Losing the network used to produce an
    ///   empty set that was then cached as authoritative, so for the next minute every blocked
    ///   user reappeared across the feed, search and activity.
    /// * **The cache belongs to one account.** Signing out and back in as somebody else used
    ///   to inherit the previous user's list until it expired.
    func blockedUserIds() async -> Set<UUID> {
        guard let user = try? await getCurrentUser() else {
            await blockedCache.clear()
            return []
        }

        if let cached = await blockedCache.value(for: user.id) { return cached }

        struct BlockRow: Decodable { let blocked_id: UUID }
        do {
            let rows: [BlockRow] = try await client
                .from("user_blocks")
                .select("blocked_id")
                .eq("blocker_id", value: user.id)
                .execute()
                .value
            let ids = Set(rows.map(\.blocked_id))
            await blockedCache.store(ids, for: user.id)
            return ids
        } catch {
            // Serve the last known good list rather than "nobody is blocked", and don't let
            // the failure become the cached answer.
            return await blockedCache.lastKnown(for: user.id) ?? []
        }
    }

    func isBlocked(_ userId: UUID) async -> Bool {
        await blockedUserIds().contains(userId)
    }

    /// Blocked users with their profiles, for the management screen in Settings. Apple expects
    /// a block to be reversible, so this list has to exist.
    func fetchBlockedUsers() async throws -> [BlockedUser] {
        guard let user = try await getCurrentUser() else { return [] }

        struct BlockRow: Decodable {
            let blocked_id: UUID
            let created_at: Date?
        }
        let rows: [BlockRow] = try await client
            .from("user_blocks")
            .select("blocked_id, created_at")
            .eq("blocker_id", value: user.id)
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let profiles = try await batchGetProfiles(ids: rows.map { $0.blocked_id.uuidString })
        let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.compactMap { row in
            guard let profile = profilesById[row.blocked_id] else { return nil }
            return BlockedUser(profile: profile, blockedAt: row.created_at)
        }
    }

    func invalidateBlockedCache() async {
        await blockedCache.clear()
    }
}

/// The blocked-id cache, isolated so the overlapping loads across tabs can't race on it.
///
/// Keyed by owner: `value(for:)` returns nothing when the id doesn't match, which is what
/// stops one account's block list from applying to the next person who signs in on the
/// same device.
actor BlockedIdsCache {
    private var ownerId: UUID?
    private var ids: Set<UUID>?
    private var stamp = Date.distantPast

    private let lifetime: TimeInterval = 60

    /// The cached list, but only while it is fresh *and* belongs to this user.
    func value(for owner: UUID) -> Set<UUID>? {
        guard ownerId == owner, Date().timeIntervalSince(stamp) < lifetime else { return nil }
        return ids
    }

    /// The cached list regardless of age, used when a refresh fails and stale beats empty.
    func lastKnown(for owner: UUID) -> Set<UUID>? {
        ownerId == owner ? ids : nil
    }

    func store(_ newIds: Set<UUID>, for owner: UUID) {
        ownerId = owner
        ids = newIds
        stamp = Date()
    }

    func clear() {
        ownerId = nil
        ids = nil
        stamp = .distantPast
    }
}
