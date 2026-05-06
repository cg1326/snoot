import SwiftUI

struct Step4FeedingView: View {
    @Bindable var vm: OnboardingViewModel

    let mealOptions = ["Free feed", "1", "2", "3", "4"]
    let treatOptions = ["Freely", "Limited", "Not allowed"]
    let unitOptions = ["cups", "grams"]

    var body: some View {
        OnboardingStep(
            title: "Mealtime",
            subtitle: "How does \(vm.name.isEmpty ? "your dog" : vm.name) eat?",
            vm: vm,
            skipLabel: "Add later",
            onSkip: { vm.skip() }
        ) {
            VStack(spacing: 18) {
                // Meals per day
                VStack(alignment: .leading, spacing: 8) {
                    Label("Meals per day", systemImage: "fork.knife")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    SnootSegmentedControl(
                        options: [0, 1, 2, 3, 4],
                        selection: $vm.mealsPerDay,
                        label: { $0 == 0 ? "Free feed" : "\($0)" }
                    )
                    .onChange(of: vm.mealsPerDay) { _, _ in vm.ensureMealTimesCount() }
                }

                // Meal times
                if vm.mealsPerDay > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meal times", systemImage: "clock")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                        ForEach(0..<vm.mealsPerDay, id: \.self) { i in
                            HStack {
                                Text("Meal \(i + 1)")
                                    .font(.system(size: 14)).foregroundColor(.snootBrown)
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { vm.mealTimes.indices.contains(i) ? vm.mealTimes[i] : Date() },
                                    set: { if vm.mealTimes.indices.contains(i) { vm.mealTimes[i] = $0 } }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 4)
                        }
                    }
                }

                // Portion
                VStack(alignment: .leading, spacing: 8) {
                    Label("Portion size", systemImage: "cup.and.saucer")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HStack(spacing: 10) {
                        HighContrastTextField(placeholder: "e.g. 1.5", text: $vm.portionSize)
                            .keyboardType(.decimalPad)
                            .fieldStyle()
                        SnootSegmentedControl(
                            options: unitOptions,
                            selection: $vm.portionUnit,
                            label: { $0 }
                        )
                        .frame(width: 140)
                    }
                }

                // Food brand
                VStack(alignment: .leading, spacing: 6) {
                    Label("Food brand / type", systemImage: "bag")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. Royal Canin Medium Adult", text: $vm.foodBrand)
                        .fieldStyle()
                }

                // Allergies
                VStack(alignment: .leading, spacing: 8) {
                    Label("Allergies / foods to avoid", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    if !vm.foodAllergies.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(vm.foodAllergies, id: \.self) { tag in
                                TagChipView(tag: tag, isSelected: true) {
                                    vm.foodAllergies.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        HighContrastTextField(placeholder: "Add allergy…", text: $vm.newAllergyTag)
                            .font(.system(size: 14))
                            .fieldStyle()
                            .submitLabel(.done)
                            .onSubmit { addAllergy() }
                        if !vm.newAllergyTag.isEmpty {
                            Button(action: addAllergy) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.snootOrange).font(.title3)
                            }
                        }
                    }
                }

                // Treats
                VStack(alignment: .leading, spacing: 8) {
                    Label("Treats", systemImage: "star")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    SnootSegmentedControl(
                        options: treatOptions,
                        selection: $vm.treatsPolicy,
                        label: { $0 }
                    )
                }
            }
        }
    }

    private func addAllergy() {
        let t = vm.newAllergyTag.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty && !vm.foodAllergies.contains(t) { vm.foodAllergies.append(t) }
        vm.newAllergyTag = ""
    }
}

