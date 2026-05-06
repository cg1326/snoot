import SwiftUI

struct Step3BioView: View {
    @Bindable var vm: OnboardingViewModel

    var placeholder: String {
        let n = vm.name.isEmpty ? "your dog" : vm.name
        return "Hi! I'm \(n). I take my snack schedule very seriously."
    }

    var body: some View {
        OnboardingStep(
            title: "A word from \(vm.name.isEmpty ? "the pup" : vm.name)",
            subtitle: "Write a quick note in their own voice. Totally optional.",
            vm: vm,
            skipLabel: "Skip — add later",
            onSkip: { vm.skip() }
        ) {
            ZStack(alignment: .topLeading) {
                if vm.bio.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color.snootText3)
                        .padding(14)
                        .font(.system(size: 16))
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.bio)
                    .font(.system(size: 16))
                    .foregroundColor(.snootText1)
                    .padding(10)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6)
        }
    }
}
