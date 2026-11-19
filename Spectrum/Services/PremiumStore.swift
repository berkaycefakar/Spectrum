import Foundation
import StoreKit
import Combine

/// Spectrum+ subscription state, on StoreKit 2. See docs/PREMIUM_PLAN.md.
///
/// Everything premium is behind `isOfferEnabled`. It stays false until the subscription
/// products exist in App Store Connect and the paid features are built, so no build shows a
/// paywall for products that can't be bought.
@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    /// Master switch. Debug builds can flip it with `-spectrum.plus YES` to test the flow
    /// against `Spectrum.storekit`.
    static var isOfferEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "spectrum.plus")
        #else
        false
        #endif
    }

    enum Plan: String, CaseIterable {
        case yearly = "berkay.Spectrum.plus.yearly"
        case monthly = "berkay.Spectrum.plus.monthly"
    }

    @Published private(set) var products: [Plan: Product] = [:]
    @Published private(set) var isPlus = false
    @Published private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        guard Self.isOfferEnabled else { return }
        updatesTask = Task { [weak self] in
            // Renewals, refunds and purchases made on another device arrive here.
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    func loadProducts() async {
        guard Self.isOfferEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Plan.allCases.map(\.rawValue))
            var map: [Plan: Product] = [:]
            for product in fetched {
                if let plan = Plan(rawValue: product.id) { map[plan] = product }
            }
            products = map
        } catch {
            debugLog("Spectrum+: product load failed: \(error)")
        }
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Plan(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
    }

    enum PurchaseOutcome { case purchased, pending, cancelled }

    func purchase(_ plan: Plan) async throws -> PurchaseOutcome {
        guard let product = products[plan] else { throw StoreKitError.notAvailableInStorefront }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return .cancelled }
            await transaction.finish()
            await refreshEntitlement()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
