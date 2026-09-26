import Testing
@testable import Spectrum

/// The filter sits on the only write path for reviews, usernames and bios, so a false
/// positive is a user who cannot save their text at all. Every case below is a regression
/// that either shipped or was caught one edit before shipping.
struct ProfanityFilterTests {

    // MARK: - False positives that actually shipped

    /// `ı→i` and `ş→s` folding made the term "sik" swallow two of the most ordinary words a
    /// Turkish music review can contain. The term was removed; these must stay clean.
    @Test(arguments: [
        "sık sık dinliyorum",
        "bu şarkı çok şık",
        "sıkıldım biraz",
        "şıkır şıkır bir albüm"
    ])
    func turkishEverydayWordsAreClean(_ text: String) {
        #expect(ProfanityFilter.firstMatch(in: text) == nil)
    }

    /// "amina" was a substring term and matched inside these. Substring matching is now
    /// reserved for strings that cannot appear inside an innocent word.
    @Test(arguments: [
        "great stamina on this record",
        "an examination of grief",
        "contamination of the mix"
    ])
    func innocentWordsContainingTermsAreClean(_ text: String) {
        #expect(ProfanityFilter.firstMatch(in: text) == nil)
    }

    /// Deliberately absent from the word list: real words in other contexts. A review that
    /// refuses to save over a false positive is worse than a mild insult getting through.
    @Test(arguments: ["mal", "bu albüm mal gibi", "oc"])
    func deliberatelyAllowedMildWords(_ text: String) {
        #expect(ProfanityFilter.contains(text) == false)
    }

    @Test func emptyTextIsClean() {
        #expect(ProfanityFilter.firstMatch(in: "") == nil)
        #expect(ProfanityFilter.contains("") == false)
    }

    // MARK: - What must still be caught

    @Test(arguments: ["fuck this", "what a piece of shit", "siktir git", "orospu"])
    func plainProfanityIsCaught(_ text: String) {
        #expect(ProfanityFilter.contains(text))
    }

    /// Leet-speak folding: digits and symbols map to their letter equivalents.
    /// Only the substitutions in the folding table are covered — there is no digit that maps
    /// to `u`, so "f4ck" (4→a, giving "fack") is deliberately *not* caught.
    @Test(arguments: ["s1kt1r", "sh1t", "$hit", "5hit", "b1tch"])
    func leetSpeakIsCaught(_ text: String) {
        #expect(ProfanityFilter.contains(text))
    }

    /// Repeated-letter runs collapse, so padding a word out doesn't dodge the list.
    @Test(arguments: ["fuuuuck", "shiiiit", "siiiktir"])
    func repeatedLettersAreCaught(_ text: String) {
        #expect(ProfanityFilter.contains(text))
    }

    /// Turkish characters fold to ASCII, so every spelling hits the same entry.
    @Test(arguments: ["şiktir", "siktir", "Siktir"])
    func turkishCharactersFoldToTheSameTerm(_ text: String) {
        #expect(ProfanityFilter.contains(text))
    }

    /// Turkish `İ` (U+0130) lowercases to `i` + U+0307, a two-scalar grapheme that is neither
    /// a plain `i` nor a key in the folding table. Normalisation lowercased *before* folding,
    /// so "SİKTİR" came out as "si̇ktir" and the filter passed it — caps was a free bypass on
    /// every Turkish term in the list.
    @Test(arguments: ["SİKTİR", "ORospu", "AMİNA", "Siktİr git"])
    func turkishCapitalDottedIDoesNotBypassTheFilter(_ text: String) {
        #expect(ProfanityFilter.contains(text))
    }

    /// The same bypass in reverse: shouting a clean word must stay clean.
    @Test(arguments: ["SIK SIK DİNLİYORUM", "ÇOK ŞIK BİR ALBÜM"])
    func shoutedTurkishEverydayWordsStayClean(_ text: String) {
        #expect(ProfanityFilter.contains(text) == false)
    }

    /// Substring terms are the answer to word-boundary dodging.
    @Test func substringTermsAreCaughtInsideLongerRuns() {
        #expect(ProfanityFilter.contains("fuckthisalbum"))
    }

    @Test func firstMatchReturnsTheOffendingWordNotTheWholeText() {
        #expect(ProfanityFilter.firstMatch(in: "the mix is shit honestly") == "shit")
    }

    // MARK: - Masking

    /// Rows written before the filter existed still live in the database, so reads mask
    /// rather than reject. Everything around the offending word must survive intact.
    @Test func maskingReplacesOnlyTheOffendingWord() {
        #expect(ProfanityFilter.masked("this is shit honestly") == "this is **** honestly")
    }

    @Test func maskingLeavesCleanTextUntouched() {
        let clean = "sık sık dinliyorum, çok şık bir albüm"
        #expect(ProfanityFilter.masked(clean) == clean)
    }

    @Test func maskingPreservesPunctuationAndSpacing() {
        let masked = ProfanityFilter.masked("wow, shit! amazing.")
        #expect(masked == "wow, ****! amazing.")
    }

    @Test func maskingPreservesLength() {
        let masked = ProfanityFilter.masked("fuuuuck")
        #expect(masked == "*******")
        #expect(masked.count == "fuuuuck".count)
    }
}
