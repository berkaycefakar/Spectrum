import Foundation
import SwiftUI

/// Everything the stats screen draws, derived from a user's song logs.
///
/// A plain value type with no dependencies so it can be tested directly: the numbers on this
/// screen are the kind that look plausible while being quietly wrong, and "looks about right
/// on my own profile" is not a check.
struct ListeningStats {

    struct RatingBucket: Identifiable {
        /// Whole stars, 1...5.
        let stars: Int
        let count: Int
        /// 0...1 against the busiest bucket, for the bar width.
        let share: CGFloat

        var id: Int { stars }
        var label: String { String(repeating: "★", count: stars) }
    }

    struct MonthBucket: Identifiable {
        let date: Date
        let count: Int
        /// 0...1 against the busiest month.
        let share: CGFloat

        var id: Date { date }

        var label: String { date.formatted(.dateTime.month(.wide).year()) }
        var shortLabel: String { date.formatted(.dateTime.month(.narrow)) }
    }

    let vibeShares: [VibeShare]
    let ratingHistogram: [RatingBucket]
    let monthlyCounts: [MonthBucket]
    /// Longest run of consecutive calendar days with at least one log.
    let longestStreakDays: Int?

    var topVibe: VibeShare? { vibeShares.first }
    var busiestMonth: MonthBucket? {
        monthlyCounts.filter { $0.count > 0 }.max { $0.count < $1.count }
    }

    init(
        summary: SupabaseManager.UserLogSummary,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        let entries = summary.entries

        // --- Vibes -----------------------------------------------------------------
        var vibeCounts: [String: Int] = [:]
        for entry in entries {
            vibeCounts[VibePalette.snap(entry.vibeColor), default: 0] += 1
        }
        let vibeTotal = CGFloat(max(entries.count, 1))
        vibeShares = vibeCounts
            // Ties resolve by hex so the order can't flicker between two loads.
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { VibeShare(hex: $0.key, count: $0.value, share: CGFloat($0.value) / vibeTotal) }

        // --- Ratings ---------------------------------------------------------------
        // Stored 0...10, shown 0...5. A half star rounds *up* into its star: someone who
        // gave 3.5 was closer to liking it, and a "0 stars" column made of unrated logs
        // would dominate the chart.
        var starCounts: [Int: Int] = [:]
        for entry in entries {
            let stars = max(1, min(5, Int((Double(entry.rating) / 2.0).rounded(.up))))
            starCounts[stars, default: 0] += 1
        }
        let busiestStar = CGFloat(starCounts.values.max() ?? 1)
        ratingHistogram = (1...5).reversed().map { stars in
            let count = starCounts[stars] ?? 0
            return RatingBucket(
                stars: stars,
                count: count,
                share: busiestStar == 0 ? 0 : CGFloat(count) / busiestStar
            )
        }

        // --- Months ----------------------------------------------------------------
        // Twelve buckets ending with the current month, always — a sparse history should
        // show its gaps rather than compress three scattered months into a full-width chart.
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let months: [Date] = (0..<12).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }

        var monthCounts: [Date: Int] = [:]
        for entry in entries {
            guard let bucket = calendar.dateInterval(of: .month, for: entry.createdAt)?.start
            else { continue }
            monthCounts[bucket, default: 0] += 1
        }
        let busiestMonthCount = CGFloat(months.map { monthCounts[$0] ?? 0 }.max() ?? 0)
        monthlyCounts = months.map { month in
            let count = monthCounts[month] ?? 0
            return MonthBucket(
                date: month,
                count: count,
                share: busiestMonthCount == 0 ? 0 : CGFloat(count) / busiestMonthCount
            )
        }

        // --- Streak ----------------------------------------------------------------
        longestStreakDays = Self.longestStreak(
            in: entries.map(\.createdAt),
            calendar: calendar
        )
    }

    /// Longest run of consecutive days containing at least one log.
    ///
    /// Days, not logs: five logs in one evening is one day, and that is the honest reading of
    /// "streak". Returns nil when there is nothing to count.
    static func longestStreak(in dates: [Date], calendar: Calendar) -> Int? {
        guard !dates.isEmpty else { return nil }

        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()

        var longest = 1
        var current = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
