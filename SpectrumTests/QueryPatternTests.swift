import Testing
@testable import Spectrum

/// Two separate security bugs came out of these three functions, both of them the same
/// shape: a `LIKE` metacharacter typed by a user reaching Postgres unescaped.
@MainActor
struct QueryPatternTests {

    // MARK: - literalPattern: "match exactly this string"

    @Test func percentIsEscapedSoItCannotWidenTheMatch() {
        #expect(SupabaseManager.literalPattern("100%") == "100\\%")
    }

    @Test func underscoreIsEscaped() {
        #expect(SupabaseManager.literalPattern("a_b") == "a\\_b")
    }

    /// The backslash has to go first, otherwise it re-escapes the escapes added after it.
    @Test func backslashIsEscapedBeforeTheOthers() {
        #expect(SupabaseManager.literalPattern("a\\b") == "a\\\\b")
        #expect(SupabaseManager.literalPattern("50\\%") == "50\\\\\\%")
    }

    /// PostgREST rewrites `*` to `%` server-side, *after* our escaping — so `*` has to leave
    /// here as something else entirely. An artist called `N*E*R*D` used to update a different
    /// review of the same user's and delete the rest.
    @Test func asteriskBecomesSingleCharacterWildcardNotPercent() {
        let pattern = SupabaseManager.literalPattern("N*E*R*D")
        #expect(pattern == "N_E_R_D")
        #expect(!pattern.contains("*"))
        #expect(!pattern.contains("%"))
    }

    @Test func ordinaryNamesPassThroughUnchanged() {
        #expect(SupabaseManager.literalPattern("Daft Punk") == "Daft Punk")
    }

    // MARK: - searchPattern: wrapped in %…% by the caller

    /// `searchPattern` is interpolated into `%\(pattern)%`. Mapping `*` to `_` the way
    /// `literalPattern` does would leave `%_%`, which still matches every row — so typing a
    /// single `*` in the search box listed the entire user table. It is dropped instead.
    @Test func asteriskIsDroppedRatherThanMapped() {
        #expect(SupabaseManager.searchPattern("*") == "")
        #expect(SupabaseManager.searchPattern("be*rk") == "berk")
    }

    @Test func percentInSearchBoxIsEscaped() {
        // Typing a bare `%` used to pull down every profile in the table.
        #expect(SupabaseManager.searchPattern("%") == "\\%")
    }

    @Test func underscoreAndBackslashInSearchBoxAreEscaped() {
        #expect(SupabaseManager.searchPattern("_") == "\\_")
        #expect(SupabaseManager.searchPattern("\\") == "\\\\")
    }

    @Test func plainQueryIsUntouched() {
        #expect(SupabaseManager.searchPattern("berkay") == "berkay")
    }

    // MARK: - matches: what makes the permissive ilike exact again

    @Test(arguments: [
        ("Daft Punk", "daft punk"),
        ("BEYONCÉ", "beyonce"),
        ("Björk", "bjork")
    ])
    func matchesIgnoresCaseAndDiacritics(_ pair: (String, String)) {
        #expect(SupabaseManager.matches(pair.0, pair.1))
    }

    /// The `ilike` filter is a superset on purpose; this is the step that rejects the extras.
    @Test(arguments: [
        ("Daft Punk", "Daft Punk 2"),
        ("Drake", "Drak"),
        ("N_E_R_D", "NoERoD")
    ])
    func matchesRejectsNearMisses(_ pair: (String, String)) {
        #expect(SupabaseManager.matches(pair.0, pair.1) == false)
    }
}
