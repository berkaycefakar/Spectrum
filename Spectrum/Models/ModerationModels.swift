import Foundation

/// What a user is reporting. The raw values are what land in `content_reports.content_type`.
enum ReportedContentType: String, Codable {
    case songReview = "song_review"
    case albumReview = "album_review"
    case artistReview = "artist_review"
    case profile = "profile"
}

/// Why they're reporting it. Apple wants a reason attached, and a flat list is easier to
/// triage in the dashboard than free text alone.
enum ReportReason: String, CaseIterable, Identifiable, Codable {
    case offensive
    case harassment
    case spam
    case sexual
    case violence
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .offensive: return "Offensive language"
        case .harassment: return "Harassment or bullying"
        case .spam: return "Spam or misleading"
        case .sexual: return "Sexual content"
        case .violence: return "Violence or threats"
        case .other: return "Something else"
        }
    }

    var icon: String {
        switch self {
        case .offensive: return "exclamationmark.bubble.fill"
        case .harassment: return "person.fill.xmark"
        case .spam: return "tray.fill"
        case .sexual: return "eye.slash.fill"
        case .violence: return "hand.raised.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// Insert payload for `content_reports`. Note there is no `reporter_id` field the caller can
/// set — `SupabaseManager` fills it from the session, and the RLS policy re-checks it.
struct NewContentReport: Encodable {
    let reporter_id: UUID
    let reported_user_id: UUID?
    let content_type: String
    let content_ref: String?
    let reason: String
    let details: String?
    let reported_text: String?
}

struct NewUserBlock: Encodable {
    let blocker_id: UUID
    let blocked_id: UUID
}

/// A row of `user_blocks` joined with the blocked user's profile, for the "Blocked users"
/// screen in Settings.
struct BlockedUser: Identifiable {
    let profile: Profile
    let blockedAt: Date?

    var id: UUID { profile.id }
}
