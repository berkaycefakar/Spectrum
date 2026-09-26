import Foundation
import Testing
@testable import Spectrum

/// The stats screen's numbers. These are exactly the kind that look plausible while being
/// quietly wrong, so each one is pinned to a case with a hand-checkable answer.
@MainActor
struct ListeningStatsTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: iso)!
    }

    private func summary(
        _ entries: [(vibe: String, rating: Int, day: String)]
    ) -> SupabaseManager.UserLogSummary {
        SupabaseManager.UserLogSummary(entries: entries.map {
            .init(vibeColor: $0.vibe, rating: $0.rating, createdAt: date($0.day))
        })
    }

    // MARK: - Ratings

    /// Stored 0...10, shown 0...5, and a half star rounds up into its star.
    @Test func ratingsBucketIntoWholeStars() {
        let stats = ListeningStats(
            summary: summary([
                ("#FF3B30", 10, "2026-01-05"),  // 5.0 → 5
                ("#FF3B30", 9,  "2026-01-06"),  // 4.5 → 5
                ("#FF3B30", 8,  "2026-01-07"),  // 4.0 → 4
                ("#FF3B30", 1,  "2026-01-08")   // 0.5 → 1
            ]),
            calendar: calendar,
            now: date("2026-01-31")
        )
        let byStar = Dictionary(uniqueKeysWithValues: stats.ratingHistogram.map { ($0.stars, $0.count) })
        #expect(byStar[5] == 2)
        #expect(byStar[4] == 1)
        #expect(byStar[1] == 1)
    }

    /// An unrated log stores 0, which would otherwise open a "0 stars" column that isn't one
    /// of the five the chart draws.
    @Test func zeroRatingsLandInTheLowestStarNotOutsideTheChart() {
        let stats = ListeningStats(
            summary: summary([("#FF3B30", 0, "2026-01-05")]),
            calendar: calendar,
            now: date("2026-01-31")
        )
        #expect(stats.ratingHistogram.count == 5)
        #expect(stats.ratingHistogram.map(\.count).reduce(0, +) == 1)
    }

    @Test func histogramIsAlwaysFiveBucketsHighestFirst() {
        let stats = ListeningStats(summary: .empty, calendar: calendar, now: date("2026-01-31"))
        #expect(stats.ratingHistogram.map(\.stars) == [5, 4, 3, 2, 1])
        // No logs must not divide by zero.
        #expect(stats.ratingHistogram.allSatisfy { $0.share == 0 })
    }

    // MARK: - Months

    @Test func twelveMonthsAreAlwaysDrawnEndingWithTheCurrentOne() {
        let stats = ListeningStats(
            summary: summary([("#FF3B30", 8, "2026-01-05")]),
            calendar: calendar,
            now: date("2026-06-15")
        )
        #expect(stats.monthlyCounts.count == 12)
        let last = stats.monthlyCounts.last!
        #expect(calendar.component(.month, from: last.date) == 6)
        #expect(calendar.component(.year, from: last.date) == 2026)
    }

    /// A sparse history should show its gaps, not compress into a full chart.
    @Test func emptyMonthsStayInTheChartWithZero() {
        let stats = ListeningStats(
            summary: summary([
                ("#FF3B30", 8, "2026-06-01"),
                ("#FF3B30", 8, "2026-06-02"),
                ("#FF3B30", 8, "2026-03-01")
            ]),
            calendar: calendar,
            now: date("2026-06-15")
        )
        #expect(stats.monthlyCounts.filter { $0.count == 0 }.count == 10)
        #expect(stats.busiestMonth?.count == 2)
        #expect(calendar.component(.month, from: stats.busiestMonth!.date) == 6)
    }

    /// Logs older than the window must not leak into the first bucket.
    @Test func logsOlderThanTwelveMonthsAreExcluded() {
        let stats = ListeningStats(
            summary: summary([("#FF3B30", 8, "2020-01-05")]),
            calendar: calendar,
            now: date("2026-06-15")
        )
        #expect(stats.monthlyCounts.allSatisfy { $0.count == 0 })
        #expect(stats.busiestMonth == nil)
    }

    // MARK: - Streak

    @Test func streakCountsConsecutiveDays() {
        let days = ["2026-01-01", "2026-01-02", "2026-01-03", "2026-01-09"].map(date)
        #expect(ListeningStats.longestStreak(in: days, calendar: calendar) == 3)
    }

    /// Five logs in one evening is one day, not a five-day streak.
    @Test func severalLogsOnOneDayCountOnce() {
        let sameDay = Array(repeating: date("2026-01-01"), count: 5)
        #expect(ListeningStats.longestStreak(in: sameDay, calendar: calendar) == 1)
    }

    @Test func streakPicksTheLongestRunNotTheLatest() {
        let days = ["2026-01-01", "2026-01-02", "2026-01-03", "2026-02-01", "2026-02-02"].map(date)
        #expect(ListeningStats.longestStreak(in: days, calendar: calendar) == 3)
    }

    @Test func noLogsMeansNoStreak() {
        #expect(ListeningStats.longestStreak(in: [], calendar: calendar) == nil)
    }

    /// Out-of-order input is the normal case — the query returns newest first.
    @Test func streakDoesNotDependOnInputOrder() {
        let days = ["2026-01-03", "2026-01-01", "2026-01-02"].map(date)
        #expect(ListeningStats.longestStreak(in: days, calendar: calendar) == 3)
    }

    // MARK: - Vibes

    @Test func vibeSharesSumToOne() {
        let stats = ListeningStats(
            summary: summary([
                ("#FF3B30", 8, "2026-06-01"),
                ("#5AC8FA", 8, "2026-06-02"),
                ("#5AC8FA", 8, "2026-06-03")
            ]),
            calendar: calendar,
            now: date("2026-06-15")
        )
        #expect(stats.topVibe?.hex == "#5AC8FA")
        #expect(abs(stats.vibeShares.reduce(0) { $0 + $1.share } - 1.0) < 0.0001)
    }

    @Test func emptySummaryProducesNothingRatherThanCrashing() {
        let stats = ListeningStats(summary: .empty, calendar: calendar, now: date("2026-06-15"))
        #expect(stats.vibeShares.isEmpty)
        #expect(stats.topVibe == nil)
        #expect(stats.longestStreakDays == nil)
        #expect(stats.monthlyCounts.count == 12)
    }
}
