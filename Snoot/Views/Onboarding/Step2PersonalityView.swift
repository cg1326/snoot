import SwiftUI

private let personalityOptions = [
    "Energetic","Cuddly","Goofy","Anxious","Foodie","Independent",
    "Velcro dog","Good with kids","Good with other dogs",
    "Reactive on leash","Shy with strangers","Loves fetch",
    "Couch potato","Escape artist"
]

struct Step2PersonalityView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingStep(
            title: "What's \(vm.name.isEmpty ? "their" : vm.name + "'s") vibe?",
            subtitle: "Pick everything that fits. No minimum.",
            vm: vm,
            onSkip: { vm.skip() }
        ) {
            TagChipGrid(
                options: personalityOptions,
                selected: $vm.personalityTags,
                customTag: $vm.customPersonalityTag,
                onAddCustom: {
                    let t = vm.customPersonalityTag.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { vm.personalityTags.insert(t) }
                    vm.customPersonalityTag = ""
                }
            )
        }
    }
}
