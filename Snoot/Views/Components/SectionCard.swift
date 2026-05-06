import SwiftUI

// MARK: - SectionCard (kept for any remaining uses)
struct SectionCard<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    @ViewBuilder let content: Content

    init(icon: String, title: String, iconColor: Color = .snootOrange, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.snootText1)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snootCardBG)
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .cardShadow()
    }
}

// MARK: - Onboarding step wrapper
struct OnboardingStep<Content: View>: View {
    let title: String
    let subtitle: String?
    let vm: OnboardingViewModel
    let skipLabel: String
    let onSkip: () -> Void
    let onContinue: (() -> Void)?
    let continueLabel: String
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        vm: OnboardingViewModel,
        skipLabel: String = "Add later",
        onSkip: @escaping () -> Void,
        continueLabel: String = "Continue",
        onContinue: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.vm = vm
        self.skipLabel = skipLabel
        self.onSkip = onSkip
        self.continueLabel = continueLabel
        self.onContinue = onContinue
        self.content = content()
    }

    // Per-step illustration symbol
    private var stepSymbol: String {
        switch vm.currentStep {
        case 1: return "pawprint.fill"
        case 2: return "heart.fill"
        case 3: return "text.bubble.fill"
        case 4: return "fork.knife"
        case 5: return "figure.walk"
        case 6: return "bolt.fill"
        case 7: return "cross.case.fill"
        case 8: return "moon.stars.fill"
        default: return "pawprint.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress pills
            ProgressBarView(currentStep: vm.currentStep, totalSteps: vm.totalSteps)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Illustration zone
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.snootOrange.opacity(0.18), Color.snootOrange.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    ))
                    .frame(width: 110, height: 110)
                Image(systemName: stepSymbol)
                    .font(.system(size: 52))
                    .foregroundColor(.snootOrange)
            }
            .padding(.bottom, 20)

            // Title + subtitle
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.snootText1)
                    .multilineTextAlignment(.center)
                    .tracking(-0.3)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 15))
                        .foregroundColor(.snootText1)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Bottom card with inputs
            ScrollView {
                VStack(spacing: 0) {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    // CTA + skip
                    VStack(spacing: 12) {
                        Button(action: { if let c = onContinue { c() } else { vm.advance() } }) {
                            Text(continueLabel)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.snootOrange)
                                .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        }
                        .buttonStyle(SpringButtonStyle())

                        Button(action: onSkip) {
                            Text(skipLabel)
                                .font(.system(size: 15))
                                .foregroundColor(.snootText2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.white)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24))
        }
        .background(Color.snootCream.ignoresSafeArea())
    }
}

// MARK: - Reusable icon text field
struct SnootTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.snootText3)
                .frame(width: 20)
            
            HighContrastTextField(placeholder: placeholder, text: $text)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.snootDivider, lineWidth: 1.5))
    }
}

// MARK: - Spring button style
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
