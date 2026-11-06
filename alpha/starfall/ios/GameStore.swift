import Foundation
import StoreKit
import Combine

/// One non-consumable purchase unlocks Starfall levels 11-100.
/// Set the live App Store Connect price to US $2.99 (or its localized equivalent).
@MainActor
final class GameStore: ObservableObject {
    static let productID = "com.agosllc.starfall.fullgame"

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = false

    weak var bridge: GameView.Bridge?
    private var updatesTask: Task<Void, Never>?
    private var hasCheckedEntitlements = false

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                if transaction.productID == Self.productID, transaction.revocationDate != nil {
                    self.isUnlocked = false
                    self.bridge?.reportEntitlement(owned: false)
                } else {
                    await self.apply(transaction)
                }
                await transaction.finish()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        product = try? await Product.products(for: [Self.productID]).first
        if let product { bridge?.reportPrice(product.displayPrice) }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID else { continue }
            if transaction.revocationDate == nil { owned = true }
        }
        isUnlocked = owned
        hasCheckedEntitlements = true
        bridge?.reportEntitlement(owned: owned)
    }

    func pushStateToPage() {
        if let product { bridge?.reportPrice(product.displayPrice) }
        if hasCheckedEntitlements { bridge?.reportEntitlement(owned: isUnlocked) }
    }

    func purchase(_ id: String) async {
        guard id == Self.productID else {
            bridge?.reportPurchase(success: false, message: "Unknown Starfall product.")
            return
        }
        if product == nil { await loadProducts() }
        guard let product else {
            bridge?.reportPurchase(
                success: false,
                message: "Could not reach the App Store. Try again in a moment."
            )
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    bridge?.reportPurchase(success: false, message: "That purchase could not be verified.")
                    return
                }
                await apply(transaction)
                await transaction.finish()
            case .userCancelled:
                bridge?.reportPurchase(success: false, message: "")
            case .pending:
                bridge?.reportPurchase(
                    success: false,
                    message: "Waiting on approval. Starfall will unlock automatically once it clears."
                )
            @unknown default:
                bridge?.reportPurchase(success: false, message: "")
            }
        } catch {
            bridge?.reportPurchase(success: false, message: error.localizedDescription)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            bridge?.reportPurchase(success: false, message: "")
            return
        } catch {
            // Cached StoreKit entitlements may still prove ownership.
        }
        await refreshEntitlements()
        bridge?.reportPurchase(
            success: isUnlocked,
            message: isUnlocked ? nil : "No previous Starfall full-game purchase was found on this Apple ID."
        )
    }

    private func apply(_ transaction: Transaction) async {
        guard transaction.productID == Self.productID,
              transaction.revocationDate == nil else { return }
        isUnlocked = true
        bridge?.reportEntitlement(owned: true)
        bridge?.reportPurchase(success: true, message: nil)
    }
}
