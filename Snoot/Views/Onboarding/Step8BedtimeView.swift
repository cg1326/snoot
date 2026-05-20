import SwiftUI

private let bedtimeRoutineOptions = [
    "Last walk first","Settle with a chew","Needs a specific toy",
    "Gets a treat at bedtime","Lights off","TV / white noise on"
]

struct Step8BedtimeView: View {
    @Bindable var vm: OnboardingViewModel

    let sleepOptions = ["Crate","Dog bed","Owner's bed","Anywhere"]

    var body: some View {
        OnboardingStep(
            title: "Bedtime",
            subtitle: "How does \(vm.name.isEmpty ? "your dog" : vm.name) wind down?",
            vm: vm,
            skipLabel: "Skip for now",
            onSkip: { vm.skip() },
            continueLabel: "All done!"
        ) {
            VStack(spacing: 18) {
                // Sleep location
                VStack(alignment: .leading, spacing: 8) {
                    Label("Where they sleep", systemImage: "moon.stars")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    SnootSegmentedControl(
                        options: sleepOptions,
                        selection: $vm.sleepLocation,
                        label: { $0 }
                    )
                }

                // Bedtime
                VStack(alignment: .leading, spacing: 8) {
                    Label("Approximate bedtime", systemImage: "clock.fill")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    DatePicker("", selection: $vm.bedtimeDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .padding(12).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                }

                // Bedtime routine
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bedtime routine", systemImage: "checkmark.circle")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    TagChipGrid(
                        options: bedtimeRoutineOptions,
                        selected: $vm.bedtimeRoutine,
                        customTag: $vm.customBedtimeTag,
                        onAddCustom: {
                            let t = vm.customBedtimeTag.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty { vm.bedtimeRoutine.insert(t) }
                            vm.customBedtimeTag = ""
                        }
                    )
                }

                // Night quirks
                VStack(alignment: .leading, spacing: 6) {
                    Label("Night-time quirks", systemImage: "moon.zzz")
                        .font(.jakarta(13, weight: .bold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. wakes up around 5am, barks at the neighbour's cat", text: $vm.nighttimeQuirks)
                        .fieldStyle()
                }
            }
        }
    }
}
