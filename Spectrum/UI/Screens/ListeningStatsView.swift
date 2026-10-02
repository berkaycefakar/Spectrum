import SwiftUI

/// "Your Spectrum" in full — the year in colour.
///
/// Every number here comes out of the three columns `fetchUserLogSummary` already reads, so
/// the screen costs one query and no MusicKit round-trips at all. That constraint is why it
/// talks about *how and when* somebody logs rather than about artists: resolving a lifetime
/// of track ids back into names would be hundreds of catalog lookups for a screen nobody
/// opens twice a day.
struct ListeningStatsView: View {
    let summary: SupabaseManager.UserLogSummary
    let albumCount: Int
    let artistCount: Int

    @Environment(\.dismiss) private var dismiss

    private var stats: ListeningStats { ListeningStats(summary: summary) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if summary.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            headlineRow
                            vibeSection
                            ratingSection
                            monthSection
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Your Spectrum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing to summarise yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Log a few songs and your spectrum starts taking shape.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Headline numbers

    private var headlineRow: some View {
        // Wraps rather than scrolls so nothing is hidden off the right edge at large text.
        FlowLayout(spacing: 10, lineSpacing: 10, alignment: .leading) {
            StatTile(value: "\(summary.entries.count)", label: String(localized: "songs logged"))
            StatTile(value: "\(albumCount)", label: String(localized: "albums"))
            StatTile(value: "\(artistCount)", label: String(localized: "artists"))
            StatTile(value: String(format: "%.1f", summary.averageRating), label: String(localized: "average"))
            if let streak = stats.longestStreakDays, streak > 1 {
                StatTile(value: "\(streak)", label: String(localized: "day streak"))
            }
        }
    }

    // MARK: - Vibes

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(String(localized: "Your colours"))

            if let top = stats.topVibe {
                Text("Mostly **\(VibePalette.label(for: top.hex))**")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            // One bar, split by share — the palette is the point, so it reads better as a
            // single spectrum than as separate rows.
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(stats.vibeShares) { share in
                        Color(hex: share.hex)
                            .frame(width: max(2, proxy.size.width * share.share))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 14)

            FlowLayout(spacing: 8, lineSpacing: 8, alignment: .leading) {
                ForEach(stats.vibeShares) { share in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: share.hex))
                            .frame(width: 8, height: 8)
                        Text("\(share.label) \(share.percentText)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ratings

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(String(localized: "How you rate"))

            ForEach(stats.ratingHistogram) { bucket in
                HStack(spacing: 10) {
                    Text(bucket.label)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 34, alignment: .leading)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color(hex: "#FF00FF").opacity(0.75))
                            // `max(…, 0)` because an empty bucket must draw nothing, not a
                            // negative width — Capsule traps on one.
                            .frame(width: max(0, proxy.size.width * bucket.share))
                    }
                    .frame(height: 10)

                    Text("\(bucket.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 34, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "\(bucket.label) stars, \(bucket.count) logs"))
            }
        }
    }

    // MARK: - Months

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(String(localized: "Last 12 months"))

            if let busiest = stats.busiestMonth {
                Text("Busiest: **\(busiest.label)** — \(busiest.count) logs")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(stats.monthlyCounts) { month in
                    VStack(spacing: 5) {
                        // Height is a share of the busiest month, with a visible floor so a
                        // month with one log still reads as "something happened".
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                month.count == 0
                                    ? Color.white.opacity(0.08)
                                    : Color(hex: "#5AC8FA").opacity(0.85)
                            )
                            .frame(height: max(3, 70 * month.share))

                        Text(month.shortLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(month.label), \(month.count) logs")
                }
            }
            .frame(height: 88, alignment: .bottom)
        }
    }
}

// MARK: - Small pieces

private struct SectionHeading: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
