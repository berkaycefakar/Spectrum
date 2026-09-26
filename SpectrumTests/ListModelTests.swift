import Foundation
import Testing
@testable import Spectrum

/// List references are polymorphic and untyped in the database — a text column holding either
/// an Apple numeric id or an artist's name. `numericRef` is the one place that ambiguity gets
/// resolved, so it is the one place worth pinning down.
@MainActor
struct ListModelTests {

    private func item(_ kind: ListItemKind, _ ref: String) -> MusicListItem {
        MusicListItem(
            id: UUID(),
            listId: UUID(),
            kind: kind,
            contentRef: ref,
            note: nil,
            position: 0,
            createdAt: Date()
        )
    }

    @Test func songsAndAlbumsExposeTheirNumericId() {
        #expect(item(.song, "1440857781").numericRef == 1_440_857_781)
        #expect(item(.album, "1440857780").numericRef == 1_440_857_780)
    }

    /// Artists are keyed by name because no table in this schema stores an artist id.
    /// Reading one as a number would produce a lookup against a nonexistent record.
    @Test func artistsHaveNoNumericId() {
        #expect(item(.artist, "Daft Punk").numericRef == nil)
    }

    /// A numerically-named artist ("21 Savage") must not start resolving as a song id.
    @Test func numericallyNamedArtistsAreStillNotNumericRefs() {
        #expect(item(.artist, "21").numericRef == nil)
    }

    /// Defensive: a malformed row shouldn't crash a list, it should render as unresolved.
    @Test func nonNumericSongReferenceIsNil() {
        #expect(item(.song, "not-a-number").numericRef == nil)
    }

    @Test func everyKindHasALabelAndAnIcon() {
        for kind in ListItemKind.allCases {
            #expect(!kind.label.isEmpty)
            #expect(!kind.icon.isEmpty)
        }
    }

    /// The raw values are the database's CHECK constraint. Renaming a case without changing
    /// the migration would make every insert fail at runtime.
    @Test func rawValuesMatchTheDatabaseConstraint() {
        #expect(ListItemKind.song.rawValue == "song")
        #expect(ListItemKind.album.rawValue == "album")
        #expect(ListItemKind.artist.rawValue == "artist")
    }
}
