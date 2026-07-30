import Combine
import SwiftUI

/// Everything a tab can push onto its navigation stack.
///
/// The tab screens use value-based navigation (`NavigationLink(value:)`) rather than
/// `NavigationLink(destination:)` for one reason: destination-based links are invisible to the
/// `NavigationPath` binding, so clearing the path does not pop them — verified in the
/// simulator, the detail view just stayed put. Value-based links *are* in the path, which is
/// what makes "tap the tab you're already on to go back to the top" possible.
///
/// Only the first push out of a tab root needs to be a route. Anything a detail screen pushes
/// on top can stay destination-based: clearing the path pops the view underneath it, and the
/// rest of the stack goes with it.
enum AppRoute: Hashable {
    case track(Track)
    case album(Album)
    case artist(name: String, id: String?)
    case user(UUID)
    case log(track: Track, review: Review, isOwner: Bool)
    /// Activity rows only carry the target's id, so the destination loads it on appear.
    case activityTrack(Int64)
    case activityAlbum(Int64)
}

extension View {
    /// Handles every `AppRoute` a tab can push.
    ///
    /// `onLogChanged` is for the profile, which has to reload after the user edits or deletes
    /// a log from the detail screen; the other tabs pass nothing.
    func appRouteDestinations(onLogChanged: (() -> Void)? = nil) -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .track(let track):
                TrackDetailView(track: track)
            case .album(let album):
                AlbumDetailView(album: album)
            case .artist(let name, let id):
                ArtistDetailView(artistName: name, artistId: id)
            case .user(let userId):
                UserProfileView(userId: userId)
            case .activityTrack(let trackId):
                ActivityTrackDestination(trackId: trackId)
            case .activityAlbum(let collectionId):
                ActivityAlbumDestination(collectionId: collectionId)
            case .log(let track, let review, let isOwner):
                LogDetailView(
                    track: track,
                    review: review,
                    isOwner: isOwner,
                    onChanged: { onLogChanged?() }
                )
            }
        }
    }
}

// MARK: - Tab reselection

/// Tracks "the user tapped the tab they were already on".
///
/// Deliberately separate from `TabBarScrollState`: that one publishes on every collapse and
/// expand, and a screen observing it would rebuild all the way through a scroll. This object
/// publishes only on a reselect, so observing it costs nothing the rest of the time.
@MainActor
final class TabReselectionState: nonisolated ObservableObject {
    static let shared = TabReselectionState()

    /// Tab index → number of times it has been reselected. The screens watch their own count
    /// and pop to root whenever it changes; the value itself doesn't mean anything.
    @Published private(set) var tokens: [Int: Int] = [:]

    private init() {}

    func requestPopToRoot(tab: Int) {
        tokens[tab, default: 0] += 1
    }

    func token(for tab: Int) -> Int {
        tokens[tab] ?? 0
    }
}
