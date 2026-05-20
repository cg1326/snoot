import Foundation
import StoreKit
import Observation

// MARK: - Errors
enum SubscriptionError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed. Please try again."
        }
    }
}

// MARK: - SubscriptionService
@Observable
final class SubscriptionService {
    // MARK: - Product IDs
    static let monthlyProductId = "com.snoot.pro.monthly"
    static let yearlyProductId  = "com.snoot.pro.yearly"

    // MARK: - State
    var isPro: Bool = false
    var products: [Product] = []
    var isLoadingProducts: Bool = false
    var productsLoadFailed: Bool = false

    // MARK: - Private
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init / Deinit
    init() {
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load products
    func loadProducts() async {
        await MainActor.run {
            isLoadingProducts = true
            productsLoadFailed = false
        }
        do {
            let fetched = try await Product.products(for: [
                Self.monthlyProductId,
                Self.yearlyProductId
            ])
            let sorted = fetched.sorted { $0.price < $1.price }
            await MainActor.run {
                products = sorted
                isLoadingProducts = false
                productsLoadFailed = sorted.isEmpty
            }
        } catch {
            await MainActor.run {
                isLoadingProducts = false
                productsLoadFailed = true
            }
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshStatus()
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshStatus()
    }

    // MARK: - Refresh entitlement status
    @MainActor
    func refreshStatus() async {
        var hasActiveSub = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable &&
                   transaction.revocationDate == nil {
                    hasActiveSub = true
                }
            }
        }
        isPro = hasActiveSub
    }

    // MARK: - Background transaction listener
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await self.refreshStatus()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - Convenience accessors
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductId }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductId }
    }
}
