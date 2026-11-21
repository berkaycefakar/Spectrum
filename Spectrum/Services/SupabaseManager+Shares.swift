import Foundation
import Supabase

/// A song or album one friend sent another, with an optional note (`shares` table).
struct Share: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case song, album }

    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let kind: Kind
    /// Apple catalog id.
    let contentRef: String
    let note: String?
    let createdAt: Date
    let seenAt: Date?

    var catalogId: Int64? { Int64(contentRef) }

    enum CodingKeys: String, CodingKey {
        case id, kind, note
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case contentRef = "content_ref"
        case createdAt = "created_at"
        case seenAt = "seen_at"
    }
}

extension SupabaseManager {
    static let shareNoteMaxLength = 140

    enum ShareError: LocalizedError {
        case signedOut, offensive, tooLong, limit
        var errorDescription: String? {
            switch self {
            case .signedOut: String(localized: "Sign in to send music.", bundle: appStringsBundle)
            case .offensive: String(localized: "This note contains language that isn't allowed.", bundle: appStringsBundle)
            case .tooLong: String(localized: "Notes can be up to 140 characters.", bundle: appStringsBundle)
            case .limit: String(localized: "You've sent a lot today. Try again tomorrow.", bundle: appStringsBundle)
            }
        }
    }

    /// People who follow you and whom you follow back: the only ones you can send to.
    func mutualFriends() async throws -> [Profile] {
        guard let me = try await getCurrentUser()?.id else { return [] }
        nonisolated struct Following: Decodable, Sendable { let following_id: UUID }
        nonisolated struct Follower: Decodable, Sendable { let follower_id: UUID }
        async let outgoing: [Following] = client.from("follows").select("following_id")
            .eq("follower_id", value: me).execute().value
        async let incoming: [Follower] = client.from("follows").select("follower_id")
            .eq("following_id", value: me).execute().value
        let (out, inc) = try await (outgoing, incoming)
        let blocked = await blockedUserIds()
        let mutual = Set(out.map(\.following_id))
            .intersection(inc.map(\.follower_id))
            .subtracting(blocked)
        let profiles = try await batchGetProfiles(ids: mutual.map(\.uuidString))
        return profiles.sorted { ($0.username ?? "").localizedCaseInsensitiveCompare($1.username ?? "") == .orderedAscending }
    }

    /// Sends one record to each recipient. The server re-checks that every recipient is a
    /// mutual follow and not blocked, and caps a sender at 30 a day.
    func sendShare(kind: Share.Kind, contentRef: String, note: String, to recipients: [UUID]) async throws {
        guard let me = try await getCurrentUser()?.id else { throw ShareError.signedOut }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= Self.shareNoteMaxLength else { throw ShareError.tooLong }
        guard !ProfanityFilter.contains(text) else { throw ShareError.offensive }
        nonisolated struct NewShare: Encodable, Sendable {
            let sender_id: UUID
            let recipient_id: UUID
            let kind: String
            let content_ref: String
            let note: String?
        }
        let rows = recipients.map {
            NewShare(sender_id: me, recipient_id: $0, kind: kind.rawValue, content_ref: contentRef,
                     note: text.isEmpty ? nil : text)
        }
        do {
            try await client.from("shares").insert(rows).execute()
        } catch {
            if String(describing: error).contains("share limit reached") { throw ShareError.limit }
            throw error
        }
    }

    /// What friends sent you, newest first, without anything from people you've blocked.
    func fetchInbox(limit: Int = 30) async throws -> [Share] {
        guard let me = try await getCurrentUser()?.id else { return [] }
        let rows: [Share] = try await client.from("shares").select()
            .eq("recipient_id", value: me)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute().value
        let blocked = await blockedUserIds()
        return rows.filter { !blocked.contains($0.senderId) }
    }

    /// What you sent, newest first, so you can see who got it and whether they opened it.
    func fetchSent(limit: Int = 30) async throws -> [Share] {
        guard let me = try await getCurrentUser()?.id else { return [] }
        return try await client.from("shares").select()
            .eq("sender_id", value: me)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute().value
    }

    func markSharesSeen(_ ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        nonisolated struct Seen: Encodable, Sendable { let seen_at: Date }
        _ = try? await client.from("shares").update(Seen(seen_at: Date()))
            .in("id", values: ids.map(\.uuidString))
            .execute()
    }

    func deleteShare(id: UUID) async throws {
        try await client.from("shares").delete().eq("id", value: id).execute()
    }
}
