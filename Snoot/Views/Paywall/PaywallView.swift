import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var selectedProductId: String = SubscriptionService.yearlyProductId
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isRestoring: Bool = false

    private var selectedProduct: Product? {
        subscriptionService.products.first { $0.id == selectedProductId }
    }

    private let features: [(icon: String, text: String)] = [
        ("checkmark.circle.fill", "Shareable sitter care guide links"),
        ("checkmark.circle.fill", "Sitter visit logs & notifications"),
        ("checkmark.circle.fill", "Family access: editors & viewers")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: - Header
                    VStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.jakarta(44))
                            .foregroundColor(.snootOrange)

                        Text("Snoot Pro")
                            .font(.jakarta(30, weight: .bold))
                            .foregroundColor(.snootBrown)

                        Text("Everything your sitter needs, in one link.")
                            .font(.jakarta(16))
                            .foregroundColor(.snootText2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // MARK: - Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.text) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.jakarta(18, weight: .semibold))
                                    .foregroundColor(.snootSage)
                                    .frame(width: 24)
                                Text(feature.text)
                                    .font(.jakarta(16))
                                    .foregroundColor(.snootText1)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                    .cardShadow()

                    // MARK: - Plan cards
                    HStack(spacing: 12) {
                        // Monthly card
                        planCard(
                            title: "Monthly",
                            price: subscriptionService.monthlyProduct?.displayPrice ?? "$3.99",
                            period: "per month",
                            badge: nil,
                            savingsNote: nil,
                            product: subscriptionService.monthlyProduct,
                            fallbackId: SubscriptionService.monthlyProductId
                        )

                        // Yearly card
                        planCard(
                            title: "Yearly",
                            price: subscriptionService.yearlyProduct?.displayPrice ?? "$24.99",
                            period: "per year",
                            badge: "Best value",
                            savingsNote: "Save ~48%",
                            product: subscriptionService.yearlyProduct,
                            fallbackId: SubscriptionService.yearlyProductId
                        )
                    }

                    // MARK: - CTA button
                    if subscriptionService.productsLoadFailed {
                        Button {
                            Task { await subscriptionService.loadProducts() }
                        } label: {
                            Text("Retry Loading Plans")
                                .font(.jakarta(18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.snootOrange)
                                .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        }
                    } else {
                        Button {
                            if let product = selectedProduct {
                                Task { await doPurchase(product) }
                            }
                        } label: {
                            Group {
                                if isPurchasing || subscriptionService.isLoadingProducts {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Start Pro")
                                        .font(.jakarta(18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.snootOrange)
                            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        }
                        .disabled(isPurchasing || subscriptionService.isLoadingProducts || selectedProduct == nil)
                    }

                    // MARK: - Restore purchases
                    Button {
                        Task { await doRestore() }
                    } label: {
                        if isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Restore purchases")
                                .font(.jakarta(15))
                                .foregroundColor(.snootText2)
                                .underline()
                        }
                    }
                    .disabled(isRestoring)

                    // MARK: - Legal footer
                    VStack(spacing: 4) {
                        Text("Subscription auto-renews. Cancel anytime in App Store Settings.")
                            .foregroundColor(.snootText2.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Text("By continuing, you agree to our [Terms of Use](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) and [Privacy Policy](https://tinyurl.com/snootcareguide).")
                            .multilineTextAlignment(.center)
                            .tint(.snootOrange)
                    }
                    .font(.jakarta(11))
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.jakarta(22))
                            .foregroundColor(.snootText2.opacity(0.5))
                    }
                }
            }
            .alert("Something went wrong", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: subscriptionService.isPro) { isPro in
                if isPro { isPresented = false }
            }
        }
    }

    // MARK: - Plan card
    @ViewBuilder
    private func planCard(
        title: String,
        price: String,
        period: String,
        badge: String?,
        savingsNote: String?,
        product: Product?,
        fallbackId: String
    ) -> some View {
        let isSelected = selectedProductId == fallbackId

        Button {
            selectedProductId = fallbackId
        } label: {
            VStack(spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.jakarta(11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.snootOrange)
                        .clipShape(Capsule())
                } else {
                    Text("Billed monthly")
                        .font(.jakarta(11))
                        .foregroundColor(.snootText2.opacity(0.6))
                }

                Text(price)
                    .font(.jakarta(26, weight: .bold))
                    .foregroundColor(.snootBrown)

                Text(period)
                    .font(.jakarta(13))
                    .foregroundColor(.snootText2)

                if let savingsNote {
                    Text(savingsNote)
                        .font(.jakarta(12, weight: .semibold))
                        .foregroundColor(.snootSage)
                } else {
                    Text(" ")
                        .font(.jakarta(12))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: SnootRadius.medium)
                    .stroke(isSelected ? Color.snootOrange : Color.clear, lineWidth: 2.5)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
    private func doPurchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await subscriptionService.purchase(product)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func doRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isPro {
                isPresented = false
            } else {
                errorMessage = "No active Snoot Pro subscription found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
