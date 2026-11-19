import SwiftUI
import StoreKit

/// Spectrum+ sign-up. Only reachable when `PremiumStore.isOfferEnabled`.
///
/// Built around the reader's own spectrum: the hero is their vibe colours flowing over the
/// months, which is the headline thing Spectrum+ adds. Everything sold here is built from the
/// user's own logs. Nothing gates Apple Music content or access (Developer Program License
/// Agreement 3.3.6(D)), so e.g. "export a list to Apple Music" is deliberately not a perk.
struct PaywallView: View {
    /// The user's logged vibe colours, most frequent first. Empty draws the default palette.
    var vibeHexes: [String] = []

    @ObservedObject private var store = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var plan: PremiumStore.Plan = .yearly
    @State private var isBuying = false
    @State private var errorMessage: String?

    private var palette: [Color] {
        let hexes = vibeHexes.isEmpty ? VibePalette.colors : Array(vibeHexes.prefix(6))
        return hexes.map { Color(hex: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero

                VStack(alignment: .leading, spacing: 12) {
                    perk("Your year in review", "A card of your year in music, made to share.",
                         preview: AnyView(yearCardPreview))
                    perk("Deeper stats", "Top artists, genres and decades, and how your ratings move.",
                         preview: AnyView(statsPreview))
                    perk("Search your own logs", "Find any log by rating, vibe or year.",
                         preview: AnyView(searchPreview))
                    perk("Make it yours", "Pick your accent colour from your spectrum, and wear the Spectrum+ mark.",
                         preview: AnyView(badgePreview))
                }

                plans

                Button { Task { await buy() } } label: {
                    Group {
                        if isBuying { ProgressView().tint(.black) }
                        else { Text(ctaTitle).fontWeight(.bold) }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                }
                .disabled(isBuying || store.products[plan] == nil)

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(Color(hex: "#FF6B6B"))
                }

                legal
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(16)
            .accessibilityLabel(Text("Close", bundle: appStringsBundle))
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isPlus) { _, plus in if plus { dismiss() } }
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    // MARK: - Hero

    /// The user's colours as a stream over twelve months: the "spectrum over time" view.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            SpectrumStream(colors: palette)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(alignment: .bottomLeading) {
                    HStack {
                        ForEach(["Jan", "Apr", "Jul", "Oct"], id: \.self) { m in
                            Text(m).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(12)
                }
                .padding(.top, 60)

            Text("See your spectrum move.", bundle: appStringsBundle)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(.white)
            Text("Spectrum+ turns your logs into the story of how you listen, month by month. Logging, lists and reviews stay free.", bundle: appStringsBundle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: - Perks

    private func perk(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, preview: AnyView) -> some View {
        HStack(spacing: 14) {
            preview
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(title, bundle: appStringsBundle).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail, bundle: appStringsBundle).font(.footnote).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }

    private var yearCardPreview: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: Array(palette.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(Calendar.current.component(.year, from: .now)))
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
                .padding(7)
        }
    }

    private var statsPreview: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array([0.45, 0.8, 0.6, 1.0, 0.7].enumerated()), id: \.offset) { i, h in
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette[i % palette.count])
                    .frame(width: 7, height: 44 * h)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.06))
    }

    private var searchPreview: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.06))
    }

    private var badgePreview: some View {
        Circle()
            .fill(AngularGradient(colors: palette + [palette.first ?? .white], center: .center))
            .frame(width: 40, height: 40)
            .overlay(Image(systemName: "sparkles").font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.06))
    }

    // MARK: - Plans

    private var plans: some View {
        HStack(spacing: 10) {
            planTile(.yearly)
            planTile(.monthly)
        }
    }

    private func planTile(_ p: PremiumStore.Plan) -> some View {
        let product = store.products[p]
        let selected = plan == p
        let hasTrial = p == .yearly && product?.subscription?.introductoryOffer != nil
        return Button { plan = p } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(p == .yearly ? "Yearly" : "Monthly", bundle: appStringsBundle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(product?.displayPrice ?? "—")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                Text(hasTrial ? "1 week free" : (p == .yearly ? "per year" : "per month"), bundle: appStringsBundle)
                    .font(.caption)
                    .foregroundStyle(hasTrial ? Color.spectrumAccent : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(selected ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(selected ? Color.spectrumAccent : .white.opacity(0.08), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Button { Task { await store.restore() } } label: {
                Text("Restore Purchases", bundle: appStringsBundle).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.8))
            Text("Renews automatically until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions.", bundle: appStringsBundle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link(String(localized: "Terms of Service", bundle: appStringsBundle), destination: LegalLinks.terms)
                Link(String(localized: "Privacy Policy", bundle: appStringsBundle), destination: LegalLinks.privacy)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var ctaTitle: String {
        if plan == .yearly, store.products[.yearly]?.subscription?.introductoryOffer != nil {
            return String(localized: "Start free week", bundle: appStringsBundle)
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
