import Foundation

/// Filters objectionable language out of user-written text.
///
/// App Store Review Guideline 1.2 requires any app with user-generated content to filter
/// objectionable material. This runs in two places:
///
/// * **On write** — `firstMatch(in:)` rejects a review before it reaches the database.
/// * **On read** — `masked(_:)` covers anything written before the filter existed, so old rows
///   don't keep showing through the feed.
///
/// The list is deliberately short and unambiguous. A long list is worse than a short one: it
/// starts eating innocent words, and a review that silently fails to save is its own bug.
enum ProfanityFilter {

    /// Words rejected as whole words only. Substring matching on these would flag ordinary
    /// text — the classic example being "Scunthorpe" for a word contained inside it.
    private static let wholeWordTerms: Set<String> = [
        // English
        "fuck", "fucks", "fucked", "fucker", "fuckers", "fucking", "motherfucker",
        "shit", "shits", "shitty", "bullshit", "bitch", "bitches", "cunt", "cunts",
        "asshole", "assholes", "dickhead", "bastard", "whore", "slut", "faggot", "fag",
        "nigger", "nigga", "retard", "retarded", "rape", "rapist",
        // Turkish
        "amk", "aq", "sik", "siktir", "sikeyim", "sikerim", "orospu", "kahpe",
        "amina", "aminakoyayim", "yavsak", "gavat", "pezevenk", "pust", "ibne",
        "gotveren", "serefsiz", "salak", "gerizekali", "ananisikeyim"
        // Deliberately absent: "mal", "oc" — real words in other contexts, and a review that
        // refuses to save over a false positive is worse than a mild insult getting through.
    ]

    /// Words unambiguous enough that they can be caught inside a longer run of characters —
    /// the usual way people dodge a word-boundary filter ("fuuuckthis").
    private static let substringTerms: [String] = [
        "fuck", "motherfuck", "cunt", "nigger", "nigga", "faggot",
        "orospu", "siktir", "amina", "pezevenk"
    ]

    /// Leet-speak and Turkish characters folded to their plain ASCII equivalent, so "s1kt1r"
    /// and "şiktir" both reduce to the same token.
    private static let characterFolding: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s",
        "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
        "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
        "â": "a", "î": "i", "û": "u", "é": "e", "á": "a"
    ]

    // MARK: - Public API

    /// Returns the first offending word found, or nil when the text is clean.
    /// The caller uses the word to explain *what* was rejected rather than just refusing.
    static func firstMatch(in text: String) -> String? {
        guard !text.isEmpty else { return nil }

        for token in tokens(in: text) {
            let normalized = normalize(token)
            guard !normalized.isEmpty else { continue }

            if wholeWordTerms.contains(normalized) { return token }
            // Repeated letters squeezed out: "fuuuck" and "shiiit" reduce to the real word.
            if wholeWordTerms.contains(collapseRuns(normalized)) { return token }

            let collapsed = collapseRuns(normalized)
            for term in substringTerms where normalized.contains(term) || collapsed.contains(term) {
                return token
            }
        }
        return nil
    }

    static func contains(_ text: String) -> Bool {
        firstMatch(in: text) != nil
    }

    /// Replaces offending words with asterisks, leaving the rest of the text intact. Used when
    /// displaying content that predates the write-time check.
    static func masked(_ text: String) -> String {
        guard contains(text) else { return text }

        var result = ""
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            result += contains(current) ? String(repeating: "*", count: current.count) : current
            current = ""
        }

        for character in text {
            if character.isLetter || character.isNumber || character == "@" || character == "$" {
                current.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }

    // MARK: - Normalisation

    private static func tokens(in text: String) -> [String] {
        text.split { character in
            !(character.isLetter || character.isNumber || character == "@" || character == "$")
        }
        .map(String.init)
    }

    private static func normalize(_ token: String) -> String {
        var result = ""
        for character in token.lowercased() {
            if let folded = characterFolding[character] {
                result.append(folded)
            } else if character.isLetter || character.isNumber {
                result.append(character)
            }
        }
        return result
    }

    /// Squeezes every repeated run down to one character: "fuuuck" → "fuck". Exact spellings
    /// are still checked separately, so collapsing a genuine double letter costs nothing.
    private static func collapseRuns(_ value: String) -> String {
        var result = ""
        var previous: Character?
        var runLength = 0

        for character in value {
            if character == previous {
                runLength += 1
                if runLength < 2 { result.append(character) }
            } else {
                result.append(character)
                previous = character
                runLength = 1
            }
        }
        return result
    }
}
