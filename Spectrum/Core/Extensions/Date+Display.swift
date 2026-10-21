import Foundation

extension Date {
    /// "3 sa. önce" / "3 h ago", in whichever language the app is currently showing — which is
    /// the in-app choice when there is one, and the device otherwise.
    @MainActor
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LanguagePreference.shared.locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// "12 Eyl 2026" / "12 Sep 2026", optionally with a time.
    @MainActor
    func displayString(date: Date.FormatStyle.DateStyle = .abbreviated,
                       time: Date.FormatStyle.TimeStyle = .omitted) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(LanguagePreference.shared.locale))
    }
}
