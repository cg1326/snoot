import SwiftUI

struct ProgressBarView: View {
    let currentStep: Int
    let totalSteps: Int

    private var progress: Double { Double(currentStep) / Double(totalSteps) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.snootDivider).frame(height: 3)
                Capsule()
                    .fill(Color.snootOrange)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 3)
    }
}
