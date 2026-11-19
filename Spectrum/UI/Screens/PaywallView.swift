import SwiftUI
import StoreKit

/// Spectrum+ sign-up. Only reachable when `PremiumStore.isOfferEnabled`.
struct PaywallView: View {
    @ObservedObject private var store = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var plan: PremiumStore.Plan = .yearly
    @State private var isBuying = false
    @State private var errorMessage: String?

    private let perks: [(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("waveform.path.ecg", "Your spectrum over time", "Month by month, and this year against last."),
        ("rectangle.portrait.on.rectangle.portrait", "Year in review card", "Your year in music, ready to share."),
        ("chart.bar.xaxis", "Deeper stats", "Top artists, genres and decades."),
        ("magnifyingglass", "Search your logs", "Filter by rating, vibe and year."),
        ("music.note.list", "Lists to Apple Music", "Turn any list into a playlist."),
        ("paintpalette", "Your accent colour", "Pick it from your own spectrum, plus a Spectrum+ badge."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            SpectrumMark(size: 34)
                            Text("Spectrum+")
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        Text("Logging, lists and reviews stay free. Spectrum+ is for going deeper.", bundle: appStringsBundle)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(perks.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: perks[i].icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.spectrumAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(perks[i].title, bundle: appStringsBundle).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text(perks[i].detail, bundle: appStringsBundle).font(.footnote).foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        planRow(.yearly)
                        planRow(.monthly)
                    }

                    Button {
                        Task { await buy() }
                    } label: {
                        Group {
                            if isBuying { ProgressView().tint(.black) }
                            else { Text(ctaTitle).fontWeight(.bold) }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isBuying || store.products[plan] == nil)

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(Color(hex: "#FF6B6B"))
                    }

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
                .padding(24)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("Close", bundle: appStringsBundle))
                }
            }
            .onChange(of: store.isPlus) { _, plus in if plus { dismiss() } }
        }
        .preferredColorScheme(.dark)
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    private var ctaTitle: String {
        if plan == .yearly, store.products[.yearly]?.subscription?.introductoryOffer != nil {
            return String(localized: "Start free week", bundle: appStringsBundle)
        }
        return String(localized: "Subscribe", bundle: appStringsBundle)
    }

    private func planRow(_ p: PremiumStore.Plan) -> some View {
        let product = store.products[p]
        let selected = plan == p
        return Button { plan = p } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(p == .yearly ? "Yearly" : "Monthly", bundle: appStringsBundle)
                        .font(.headline).foregroundStyle(.white)
                    if p == .yearly, product?.subscription?.introductoryOffer != nil {
                        Text("1 week free, then billed yearly", bundle: appStringsBundle)
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Text(product?.displayPrice ?? "—")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(.white.opacity(selected ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.spectrumAccent : .white.opacity(0.08), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
