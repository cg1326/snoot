import SwiftUI

struct AccountPromptBanner: View {
    @Binding var showAuth: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            LinearGradient(
                colors: [Color.snootOrange, Color.snootOrange.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 4)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0))

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.snootOrange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlock live sharing")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.snootText1)
                    Text("Create sitter links, track visits, invite family members.")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText2)
                        .lineLimit(2)
                }

                Spacer()

                Button("Get started") { showAuth = true }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(height: 36)
                    .padding(.horizontal, 14)
                    .background(Color.snootOrange)
                    .clipShape(Capsule())
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .elevatedShadow()
        .padding(.horizontal, 16)
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#A07800"))
            VStack(alignment: .leading, spacing: 1) {
                Text("You're offline")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#A07800"))
                Text("Changes will sync when you reconnect.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#8A6600"))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#F9C74F").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
