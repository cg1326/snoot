import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let editingDog: Dog?
    let startingStep: Int
    let readOnly: Bool
    let onComplete: (Dog) -> Void
    @State private var vm: OnboardingViewModel

    init(editingDog: Dog? = nil, startingStep: Int = 1, readOnly: Bool = false, onComplete: @escaping (Dog) -> Void) {
        self.editingDog = editingDog
        self.startingStep = startingStep
        self.readOnly = readOnly
        self.onComplete = onComplete

        let initialVM = OnboardingViewModel()
        if let dog = editingDog { initialVM.load(from: dog) }
        initialVM.currentStep = startingStep
        initialVM.readOnly = readOnly
        _vm = State(initialValue: initialVM)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.snootCream.ignoresSafeArea()
                stepView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(vm.currentStep)
            }
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.currentStep > 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                vm.currentStep -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.snootBrown)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if editingDog != nil && !vm.readOnly {
                            finish()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.snootText3)
                            .font(.jakarta(24))
                    }
                }
            }
            .onChange(of: vm.currentStep) { _, step in
                if step > vm.totalSteps { finish() }
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch vm.currentStep {
        case 1: Step1BasicsView(vm: vm)
        case 2: Step2PersonalityView(vm: vm)
        case 3: Step3BioView(vm: vm)
        case 4: Step4FeedingView(vm: vm)
        case 5: Step5WalksView(vm: vm)
        case 6: Step6BehaviourView(vm: vm)
        case 7: Step7HealthView(vm: vm)
        case 8: Step8BedtimeFinisher(vm: vm, onFinish: finish)
        default: Step1BasicsView(vm: vm)
        }
    }

    private func finish() {
        if vm.readOnly {
            dismiss()
            return
        }
        if let existing = editingDog {
            vm.applyEdits(to: existing, context: context)
            onComplete(existing)
        } else {
            let dog = vm.saveDog(context: context)
            onComplete(dog)
        }
    }
}

// Step 8 wrapper that calls finish instead of advancing past totalSteps
private struct Step8BedtimeFinisher: View {
    @Bindable var vm: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        OnboardingStep(
            title: "Bedtime",
            subtitle: "How does \(vm.name.isEmpty ? "your dog" : vm.name) wind down?",
            vm: vm,
            skipLabel: "Skip to finish",
            onSkip: onFinish,
            continueLabel: "Finish profile ✓",
            onContinue: onFinish
        ) {
            Step8BedtimeContent(vm: vm)
        }
    }
}

private struct Step8BedtimeContent: View {
    @Bindable var vm: OnboardingViewModel
    private let bedtimeRoutineOptions = [
        "Last walk first","Settle with a chew","Needs a specific toy",
        "Gets a treat at bedtime","Lights off","TV / white noise on"
    ]
    private let sleepOptions = ["Crate","Dog bed","Owner's bed","Anywhere"]

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Where they sleep", systemImage: "moon.stars")
                    .font(.jakarta(13, weight: .semibold)).foregroundColor(.snootText2)
                SnootSegmentedControl(
                    options: sleepOptions,
                    selection: $vm.sleepLocation,
                    label: { $0 }
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Approximate bedtime", systemImage: "clock.fill")
                    .font(.jakarta(13, weight: .semibold)).foregroundColor(.snootText2)
                DatePicker("", selection: $vm.bedtimeDate, displayedComponents: .hourAndMinute)
                    .labelsHidden().padding(12).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Bedtime routine", systemImage: "checkmark.circle")
                    .font(.jakarta(13, weight: .semibold)).foregroundColor(.snootText2)
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
            VStack(alignment: .leading, spacing: 6) {
                Label("Night-time quirks", systemImage: "moon.zzz")
                    .font(.jakarta(13, weight: .semibold)).foregroundColor(.snootText2)
                HighContrastTextField(placeholder: "e.g. wakes up around 5am, barks at the neighbour's cat", text: $vm.nighttimeQuirks)
                    .fieldStyle()
            }
        }
    }
}
