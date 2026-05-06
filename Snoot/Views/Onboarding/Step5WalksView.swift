import SwiftUI

private let leashOptions = [
    "Pulls a lot","Reactive to dogs","Reactive to people",
    "Sniff-obsessed","Good on leash","Needs gentle leader/harness"
]

struct Step5WalksView: View {
    @Bindable var vm: OnboardingViewModel
    let durationOptions = [15, 30, 45, 60]

    var body: some View {
        OnboardingStep(
            title: "Walk time",
            subtitle: "When and how does \(vm.name.isEmpty ? "your dog" : vm.name) like to go out?",
            vm: vm,
            skipLabel: "Add later",
            onSkip: { vm.skip() }
        ) {
            VStack(spacing: 18) {
                // Walks per day
                VStack(alignment: .leading, spacing: 8) {
                    Label("Walks per day", systemImage: "figure.walk")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HStack {
                        Button { if vm.walksPerDay > 1 { vm.walksPerDay -= 1 } } label: {
                            Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(Color.snootOrange)
                        }
                        Spacer()
                        Text("\(vm.walksPerDay)").font(.system(size: 22, weight: .bold)).foregroundColor(Color.snootBrown)
                        Spacer()
                        Button { if vm.walksPerDay < 6 { vm.walksPerDay += 1; vm.ensureWalkTimesCount() } } label: {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(Color.snootOrange)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4)
                }

                // Walk times
                VStack(alignment: .leading, spacing: 8) {
                    Label("Walk times", systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    ForEach(0..<vm.walksPerDay, id: \.self) { i in
                        HStack {
                            Text("Walk \(i + 1)").font(.system(size: 14)).foregroundColor(Color.snootBrown)
                            Spacer()
                            DatePicker("", selection: Binding(
                                get: { vm.walkTimes.indices.contains(i) ? vm.walkTimes[i] : Date() },
                                set: { if vm.walkTimes.indices.contains(i) { vm.walkTimes[i] = $0 } }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        }
                        .padding(12).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    }
                }

                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Label("Typical duration", systemImage: "timer")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    SnootSegmentedControl(
                        options: durationOptions,
                        selection: $vm.walkDurationMinutes,
                        label: { $0 == 60 ? "1hr+" : "\($0)m" }
                    )
                }

                // Leash behaviour
                VStack(alignment: .leading, spacing: 8) {
                    Label("On the leash", systemImage: "link")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    TagChipGrid(options: leashOptions, selected: $vm.leashBehaviours)
                }

                // Off leash
                VStack(alignment: .leading, spacing: 8) {
                    Label("Trusted off-leash", systemImage: "checkmark.shield")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    Toggle("Can be trusted off-leash", isOn: $vm.offLeashTrusted)
                        .tint(Color.snootSage)
                        .padding(12).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    if !vm.offLeashTrusted {
                        HighContrastTextField(placeholder: "Notes (e.g. will chase squirrels)", text: $vm.offLeashNotes)
                            .fieldStyle()
                    }
                }
            }
        }
    }
}
