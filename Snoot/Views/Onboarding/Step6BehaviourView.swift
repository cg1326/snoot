import SwiftUI

private let fearOptions = [
    "Thunderstorms","Fireworks","Strangers at door","Skateboards / bikes",
    "Loud noises","Vacuums","Car rides","Being left alone"
]

struct Step6BehaviourView: View {
    @Bindable var vm: OnboardingViewModel
    let anxietyOptions = ["None","Mild","Moderate","Severe"]

    var showAnxietyNotes: Bool {
        vm.separationAnxiety != "None"
    }

    var body: some View {
        OnboardingStep(
            title: "Quirks & feelings",
            subtitle: "What should a sitter know about \(vm.name.isEmpty ? "them" : vm.name)?",
            vm: vm,
            skipLabel: "Add later",
            onSkip: { vm.skip() }
        ) {
            VStack(spacing: 18) {
                // Fears / triggers
                VStack(alignment: .leading, spacing: 8) {
                    Label("Fears / triggers", systemImage: "bolt")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    TagChipGrid(
                        options: fearOptions,
                        selected: $vm.fearTriggers,
                        customTag: $vm.customFearTag,
                        onAddCustom: {
                            let t = vm.customFearTag.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty { vm.fearTriggers.insert(t) }
                            vm.customFearTag = ""
                        }
                    )
                }

                // Separation anxiety
                VStack(alignment: .leading, spacing: 8) {
                    Label("Separation anxiety", systemImage: "heart.slash")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    SnootSegmentedControl(
                        options: anxietyOptions,
                        selection: $vm.separationAnxiety,
                        label: { $0 }
                    )
                    if showAnxietyNotes {
                        HighContrastTextField(placeholder: "What helps? (e.g. leave the TV on)", text: $vm.separationAnxietyNotes)
                            .fieldStyle()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showAnxietyNotes)

                // Potty signal
                VStack(alignment: .leading, spacing: 6) {
                    Label("Potty signal", systemImage: "figure.stand")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. goes to the door and stares", text: $vm.pottySignal)
                        .fieldStyle()
                }

                // Comfort items
                VStack(alignment: .leading, spacing: 6) {
                    Label("Comfort items", systemImage: "teddybear")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. blue rope toy, worn blanket", text: $vm.comfortItems)
                        .fieldStyle()
                }
            }
        }
    }
}
