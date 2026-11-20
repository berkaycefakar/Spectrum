import SwiftUI
import StoreKit

/// Spectrum+ sign-up. Only reachable when `PremiumStore.isOfferEnabled`.
///
/// Swipeable: one page per thing Spectrum+ adds, each with a picture of it, then a last page
/// listing all of it together. The button and price stay pinned underneath every page.
///
/// Everything sold here is built from the user's own logs or changes how their profile looks.
/// Nothing gates Apple Music content or access (Developer Program License Agreement
/// 3.3.6(D)), so e.g. "export a list to Apple Music" is deliberately not a perk.
struct PaywallView: View {
    /// The user's logged vibe colours, most frequent first. Empty draws the default palette.
    var vibeHexes: [String] = []

    @ObservedObject private var store = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var plan: PremiumStore.Plan = .yearly
    @State private var isBuying = false
    @State private var errorMessage: String?

    private var palette: [Color] {
        let hexes = vibeHexes.isEmpty ? VibePalette.colors : Array(vibeHexes.prefix(7))
        return hexes.map { Color(hex: $0) }
    }

    private struct Page {
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(title: "How was your year in music?",
             body: "A card of your year: what you played most, your average, your colours. Share it in one tap."),
        Page(title: "See your spectrum move.",
             body: "The colours you picked, month by month. Which season sounded like what, at a glance."),
        Page(title: "Stats on your own taste.",
             body: "Your most-logged artists, genres and decades, and how your ratings drift over time."),
        Page(title: "Find any log.",
             body: "Search what you wrote, and filter by rating, colour, year or genre."),
        Page(title: "Make your profile yours.",
             body: "An animated profile photo and cover, your own profile colour, other app icons and the Plus badge."),
        Page(title: "Everything in Spectrum+",
             body: "Logging, ratings, comments and lists stay free for everyone.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.vertical, 14)

            footer
        }
        .background(Color(hex: "#0B0B12").ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .padding(16)
            .accessibilityLabel(Text("Close", bundle: appStringsBundle))
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isPlus) { _, plus in if plus { dismiss() } }
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    // MARK: - Pages

    private func pageView(_ i: Int) -> some View {
        VStack(spacing: 22) {
            Group {
                switch i {
                case 0: YearCardArt(palette: palette)
                case 1: MonthlySpectrumArt(palette: palette)
                case 2: StatsArt()
                case 3: SearchArt(palette: palette)
                case 4: AppearanceArt(palette: palette)
                default: summaryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                Text(pages[i].title, bundle: appStringsBundle)
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(pages[i].body, bundle: appStringsBundle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 60)
    }

    /// The last page: every perk, one per line.
    private var summaryList: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow("rectangle.portrait.on.rectangle.portrait.angled", "Year in review card")
            summaryRow("chart.bar.fill", "Your spectrum, month by month")
            summaryRow("person.2.wave.2", "Top artists, genres and decades")
            summaryRow("chart.line.uptrend.xyaxis", "How your ratings change")
            summaryRow("magnifyingglass", "Search and filter your logs")
            summaryRow("sparkles.rectangle.stack", "Animated profile photo and cover")
            summaryRow("paintpalette", "Your own profile colour")
            summaryRow("app.badge", "Other app icons")
            summaryRow("seal", "Plus badge on your profile")
            summaryRow("star.bubble", "New features first")
        }
        .padding(20)
        .frame(maxWidth: 340, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 24)
    }

    private func summaryRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.spectrumAccent)
                .frame(width: 24)
            Text(text, bundle: appStringsBundle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.white : Color.white.opacity(0.3))
                    .frame(width: i == page ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy(duration: 0.25), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(page + 1) of \(pages.count)", bundle: appStringsBundle))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button { Task { await buy() } } label: {
                Group {
                    if isBuying { ProgressView().tint(.black) }
                    else { Text(ctaTitle).fontWeight(.bold) }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white, in: Capsule())
            }
            .disabled(isBuying || store.products[plan] == nil)

            priceLine

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(Color(hex: "#FF6B6B"))
            }

            HStack(spacing: 16) {
                Button { Task { await store.restore() } } label: {
                    Text("Restore Purchases", bundle: appStringsBundle)
                }
                Link(String(localized: "Terms of Service", bundle: appStringsBundle), destination: LegalLinks.terms)
                Link(String(localized: "Privacy Policy", bundle: appStringsBundle), destination: LegalLinks.privacy)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))

            Text("Renews automatically until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions.", bundle: appStringsBundle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    /// "Then 699 ₺/year · or monthly 99 ₺": the other plan is one tap away.
    private var priceLine: some View {
        let yearly = store.products[.yearly]?.displayPrice ?? "—"
        let monthly = store.products[.monthly]?.displayPrice ?? "—"
        return HStack(spacing: 4) {
            Button { plan = .yearly } label: {
                Text("\(yearly) a year", bundle: appStringsBundle)
                    .fontWeight(plan == .yearly ? .bold : .regular)
                    .foregroundStyle(plan == .yearly ? .white : .white.opacity(0.55))
            }
            Text("·").foregroundStyle(.white.opacity(0.4))
            Button { plan = .monthly } label: {
                Text("\(monthly) a month", bundle: appStringsBundle)
                    .fontWeight(plan == .monthly ? .bold : .regular)
                    .foregroundStyle(plan == .monthly ? .white : .white.opacity(0.55))
            }
        }
        .font(.footnote)
        .buttonStyle(.plain)
    }

    private var ctaTitle: String {
        if plan == .yearly, store.products[.yearly]?.subscription?.introductoryOffer != nil {
            return String(localized: "Try 1 week free", bundle: appStringsBundle)
        }
        return String(localized: "Subscribe", bundle: appStringsBundle)
    }

    private func buy() async {
        isBuying = true
        defer { isBuying = false }
        do {
            _ = try await store.purchase(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Page art

/// The shareable year card, fanned over two coloured cards.
private struct YearCardArt: View {
    let palette: [Color]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(palette[4 % palette.count].opacity(0.55))
                .rotationEffect(.degrees(7)).offset(x: 18, y: 6)
            RoundedRectangle(cornerRadius: 26).fill(palette[6 % palette.count].opacity(0.6))
                .rotationEffect(.degrees(-5)).offset(x: -14, y: 4)
            VStack(alignment: .leading, spacing: 14) {
                Text(String(Calendar.current.component(.year, from: .now)))
                    .font(.system(size: 42, weight: .black).monospacedDigit())
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(palette[(i * 2) % palette.count].opacity(0.45))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(.white.opacity(0.25)).frame(width: 90, height: 8)
                    Capsule().fill(.white.opacity(0.7)).frame(width: 140, height: 12)
                }
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(Array(palette.prefix(4).enumerated()), id: \.offset) { i, c in
                        c.frame(maxWidth: .infinity)
                            .layoutPriority(Double(4 - i))
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
            }
            .padding(20)
            .background(Color(hex: "#16161F"), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
        }
        .frame(width: 220, height: 320)
        .accessibilityHidden(true)
    }
}

/// Twelve months, each a column of the colours picked that month.
private struct MonthlySpectrumArt: View {
    let palette: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<12, id: \.self) { m in
                    VStack(spacing: 2) {
                        ForEach(palette.indices, id: \.self) { b in
                            palette[b]
                                .frame(height: max(1, 210 * height(m) * weight(b, m) / total(m) - 2))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 210, alignment: .bottom)
            HStack {
                ForEach(["Jan", "Apr", "Jul", "Oct", "Dec"], id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 28)
        .accessibilityHidden(true)
    }

    private func weight(_ b: Int, _ m: Int) -> Double {
        max(0.2, 1.2 + sin(Double(m) * 0.7 + Double(b) * 1.3) + 0.4 * cos(Double(m) * 1.3 - Double(b)))
    }
    private func total(_ m: Int) -> Double { palette.indices.reduce(0) { $0 + weight($1, m) } }
    private func height(_ m: Int) -> Double { 0.55 + 0.42 * abs(sin(Double(m) * 0.9 + 1)) }
}

/// Bars for top artists and four tiles: an illustration, not real numbers.
private struct StatsArt: View {
    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach([1.0, 0.72, 0.5, 0.38], id: \.self) { w in
                    HStack(spacing: 10) {
                        Circle().fill(.white.opacity(0.15)).frame(width: 26, height: 26)
                        GeometryReader { g in
                            Capsule().fill(Color.spectrumAccent).frame(width: g.size.width * w, height: 10)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 26)
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            HStack(spacing: 10) {
                tile("guitars", "Genres")
                tile("calendar", "Decades")
                tile("chart.line.uptrend.xyaxis", "Ratings")
            }
        }
        .padding(.horizontal, 28)
        .accessibilityHidden(true)
    }

    private func tile(_ symbol: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
            Text(label, bundle: appStringsBundle).font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// A search field, filter chips and three results.
private struct SearchArt: View {
    let palette: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Capsule().fill(.white.opacity(0.35)).frame(width: 70, height: 8)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 6) {
                chip { Text("4★+").font(.caption.weight(.semibold)) }
                    .foregroundStyle(.black)
                    .background(.white, in: Capsule())
                chip { HStack(spacing: 4) { ForEach(0..<2, id: \.self) { Circle().fill(palette[($0 * 3 + 4) % palette.count]).frame(width: 10, height: 10) } } }
                    .background(.white.opacity(0.08), in: Capsule())
                chip { Text(String(Calendar.current.component(.year, from: .now) - 1)).font(.caption.weight(.semibold)) }
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8).fill(palette[(i * 2 + 1) % palette.count].opacity(0.45))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(.white.opacity(0.7)).frame(width: 120, height: 9)
                        Capsule().fill(.white.opacity(0.3)).frame(width: 80, height: 7)
                    }
                    Spacer()
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Color(hex: "#FFCC00"))
                }
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 28)
        .accessibilityHidden(true)
    }

    private func chip<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content().padding(.horizontal, 12).frame(height: 30)
    }
}

/// A profile with a spectrum ring, the Plus badge, colour swatches and icon choices.
private struct AppearanceArt: View {
    let palette: [Color]

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [palette[5 % palette.count].opacity(0.5), palette[6 % palette.count].opacity(0.35)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 110)
                Circle()
                    .fill(AngularGradient(colors: palette + [palette[0]], center: .center))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().fill(Color(hex: "#2A2230")).padding(5))
                    .overlay(Circle().stroke(Color(hex: "#0B0B12"), lineWidth: 3).padding(4))
                    .offset(y: 44)
            }
            .padding(.bottom, 44)
            HStack(spacing: 6) {
                Capsule().fill(.white.opacity(0.8)).frame(width: 80, height: 12)
                Text("PLUS").font(.caption2.weight(.heavy)).foregroundStyle(.black)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.spectrumAccent, in: Capsule())
            }
            HStack(spacing: 10) {
                ForEach(Array(palette.prefix(5).enumerated()), id: \.offset) { i, c in
                    Circle().fill(c).frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white, lineWidth: i == 0 ? 2 : 0).padding(-4))
                }
            }
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12).fill(.black)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.25)))
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#F2EDE4"))
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [palette[0], palette[palette.count - 1]],
                                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .frame(width: 180, height: 50)
        }
        .padding(.horizontal, 36)
        .accessibilityHidden(true)
    }
}

// MARK: - Spectrum stream (also drawn on the profile's paywall entry row)

/// Stacked colour bands drifting over twelve months: an illustration of "spectrum over time".
struct SpectrumStream: View {
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            let months = 12
            let n = max(colors.count, 1)
            // Deterministic wobble per band so the picture is stable between renders.
            func weight(_ band: Int, _ month: Double) -> Double {
                1 + 0.6 * sin(month * 0.7 + Double(band) * 1.3) + 0.3 * cos(month * 1.4 - Double(band))
            }
            var lower = [Double](repeating: 0, count: months + 1)
            let totals = (0...months).map { m in (0..<n).reduce(0.0) { $0 + weight($1, Double(m)) } }
            for band in 0..<n {
                var upper = lower
                for m in 0...months { upper[m] = lower[m] + weight(band, Double(m)) / totals[m] }
                var path = Path()
                let x = { (m: Int) in size.width * CGFloat(m) / CGFloat(months) }
                path.move(to: CGPoint(x: 0, y: size.height * (1 - upper[0])))
                for m in 1...months {
                    let p0 = CGPoint(x: x(m - 1), y: size.height * (1 - upper[m - 1]))
                    let p1 = CGPoint(x: x(m), y: size.height * (1 - upper[m]))
                    path.addCurve(to: p1, control1: CGPoint(x: (p0.x + p1.x) / 2, y: p0.y),
                                  control2: CGPoint(x: (p0.x + p1.x) / 2, y: p1.y))
                }
                for m in stride(from: months, through: 0, by: -1) {
                    path.addLine(to: CGPoint(x: x(m), y: size.height * (1 - lower[m])))
                }
                path.closeSubpath()
                context.fill(path, with: .color(colors[band % colors.count]))
                lower = upper
            }
        }
        .background(Color.black)
        .accessibilityHidden(true)
    }
}
