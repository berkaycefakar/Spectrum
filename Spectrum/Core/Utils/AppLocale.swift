import Foundation

/// The one locale every user-visible date, number and relative time is formatted in.
///
/// Spectrum ships a single, unlocalised English UI, but `Locale.autoupdatingCurrent` does not
/// care about that: on a Turkish phone `RelativeDateTimeFormatter` returned "2 sa. önce" and
/// `Date.formatted()` returned "12 Eyl 2026", so half of a profile read as English and the
/// other half as Turkish. Pinning the display locale is what keeps one screen in one language
/// until there is a real localisation to switch to.
///
/// This is deliberately *not* `Locale.current`: it must not follow the device.
enum AppLocale {
    /// Formatting locale for everything the user reads.
    static let display = Locale(identifier: "en_US")
}

extension Date {
    /// "3 h ago". Pinned to `AppLocale.display` — the default formatter follows the device
    /// language, which is how Turkish timestamps ended up under English headings.
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocale.display
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// "12 Sep 2026", optionally with a time.
    func displayString(date: Date.FormatStyle.DateStyle = .abbreviated,
                       time: Date.FormatStyle.TimeStyle = .omitted) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(AppLocale.display))
    }
}
