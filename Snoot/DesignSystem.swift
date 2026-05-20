import SwiftUI

// MARK: - Colors
extension Color {
    static let snootCream       = Color(hex: "#FDFAF6")
    static let snootOrange      = Color(hex: "#F4845F")
    static let snootSage        = Color(hex: "#7DAF7A")
    static let snootAmber       = Color(hex: "#F9C74F")
    static let snootBrown       = Color(hex: "#3D2B1F")
    static let snootText1       = Color(hex: "#1A1A1A")
    static let snootText2       = Color(hex: "#1A1A1A") // Same as Text1 for robustness
    static let snootText3       = Color(hex: "#555555") // Dark gray for placeholders and tertiary text
    static let snootDivider     = Color(hex: "#F0EDE8")
    static let snootCardBG      = Color(hex: "#FFFFFF")
    static let snootDestructive = Color(hex: "#E05C5C")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography
struct SnootType {
    static let display = Font.jakarta(34, weight: .bold)
    static let title1  = Font.jakarta(28, weight: .bold)
    static let title2  = Font.jakarta(22, weight: .semibold)
    static let title3  = Font.jakarta(18, weight: .semibold)
    static let body    = Font.jakarta(16, weight: .regular)
    static let caption = Font.jakarta(13, weight: .regular)
    static let label   = Font.jakarta(12, weight: .medium)
    static let mono    = Font.system(.caption, design: .monospaced) // Keep monospaced as system font
}

extension Font {
    func fallback(_ fallback: Font) -> Font {
        // Simple helper to handle custom font fallbacks
        self
    }

    /// Returns the appropriate Plus Jakarta Sans variant for the given size and weight.
    static func jakarta(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:             name = "PlusJakartaSans-ExtraBold"
        case .bold:                      name = "PlusJakartaSans-Bold"
        case .semibold:                  name = "PlusJakartaSans-SemiBold"
        case .medium:                    name = "PlusJakartaSans-Medium"
        case .light:                     name = "PlusJakartaSans-Light"
        case .ultraLight, .thin:         name = "PlusJakartaSans-ExtraLight"
        default:                         name = "PlusJakartaSans-Regular"
        }
        return .custom(name, size: size).weight(weight)
    }
}

// MARK: - Corner Radii
struct SnootRadius {
    static let small:  CGFloat = 8
    static let medium: CGFloat = 16
    static let large:  CGFloat = 24
    static let full:   CGFloat = 9999
}

// MARK: - Shadows
struct SnootShadow {
    static func card() -> some View { EmptyView() }
}
extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Field style (bottom-border only)
extension View {
    func bottomBorderFieldStyle(focused: Bool = false) -> some View {
        self.modifier(BottomBorderFieldModifier(focused: focused))
    }
    // Keep old fieldStyle for any remaining uses during migration
    func fieldStyle() -> some View {
        self
            .foregroundColor(.snootText1)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .subtleShadow()
    }
}

struct BottomBorderFieldModifier: ViewModifier {
    let focused: Bool
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, 12)
                .padding(.horizontal, 0)
            Rectangle()
                .fill(focused ? Color.snootOrange : Color.snootDivider)
                .frame(height: 1.5)
                .animation(.easeInOut(duration: 0.2), value: focused)
        }
    }
}

// MARK: - Custom Section Header
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.jakarta(17, weight: .heavy))
            .foregroundColor(.snootText1)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }
}

// MARK: - Custom Segmented Control
struct SnootSegmentedControl<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.jakarta(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selection == option ? Color.white : Color.clear)
                        .foregroundColor(selection == option ? .snootOrange : .snootText1)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(2)
                }
            }
        }
        .background(Color.snootDivider)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - High Contrast TextField
struct HighContrastTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.jakarta(16))
                    .foregroundColor(.snootText3)
                    .padding(.leading, 4)
            }
            if isSecure {
                SecureField("", text: $text)
                    .font(.jakarta(16))
                    .foregroundColor(.snootText1)
            } else {
                TextField("", text: $text)
                    .font(.jakarta(16))
                    .foregroundColor(.snootText1)
            }
        }
    }
}
