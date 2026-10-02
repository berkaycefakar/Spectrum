import Foundation

extension Date {
    /// "3 sa. önce" / "3 h ago" — in whatever language the device is set to, which is the same
    /// language the surrounding UI is drawn in. Spectrum ships English and Turkish, so this
    /// deliberately follows `Locale.current` rather than being pinned.
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// "12 Eyl 2026" / "12 Sep 2026", optionally with a time.
    func displayString(date: Date.FormatStyle.DateStyle = .abbreviated,
                       time: Date.FormatStyle.TimeStyle = .omitted) -> String {
        formatted(Date.FormatStyle(date: date, time: time))
    }
}
