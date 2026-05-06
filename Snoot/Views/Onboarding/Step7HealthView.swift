import SwiftUI

struct Step7HealthView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingStep(
            title: "Health & meds",
            subtitle: "Anything a sitter needs to know medically?",
            vm: vm,
            skipLabel: "All healthy — skip",
            onSkip: { vm.skip() }
        ) {
            VStack(spacing: 18) {
                // Health conditions toggle
                VStack(alignment: .leading, spacing: 8) {
                    Label("Health conditions", systemImage: "cross.case")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    Toggle("Has ongoing health conditions", isOn: $vm.hasHealthConditions)
                        .tint(Color.snootSage)
                        .padding(12).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                    if vm.hasHealthConditions {
                        HighContrastTextField(placeholder: "Describe the condition(s)", text: $vm.healthConditions)
                            .fieldStyle()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.hasHealthConditions)

                // Medications
                VStack(alignment: .leading, spacing: 8) {
                    Label("Medications", systemImage: "pill")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    ForEach(vm.medications) { med in
                        if let index = vm.medications.firstIndex(where: { $0.id == med.id }) {
                            MedicationCard(entry: $vm.medications[index]) {
                                vm.medications.remove(at: index)
                            }
                        }
                    }
                    Button {
                        vm.medications.append(OnboardingViewModel.MedEntry())
                    } label: {
                        Label("Add medication", systemImage: "plus.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.snootOrange)
                            .padding(12).frame(maxWidth: .infinity)
                            .background(Color.snootOrange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Warning signs
                VStack(alignment: .leading, spacing: 6) {
                    Label("Warning signs", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. if she skips two meals in a row, call the vet", text: $vm.warningSigns)
                        .fieldStyle()
                }

                // Vet info
                VStack(alignment: .leading, spacing: 8) {
                    Label("Vet contact", systemImage: "stethoscope")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "Vet name", text: $vm.vetName).fieldStyle()
                    HighContrastTextField(placeholder: "Clinic name", text: $vm.vetClinic).fieldStyle()
                    HighContrastTextField(placeholder: "Phone number", text: $vm.vetPhone)
                        .keyboardType(.phonePad).fieldStyle()
                }

                // Emergency contact
                VStack(alignment: .leading, spacing: 6) {
                    Label("Owner emergency contact", systemImage: "phone")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "Phone number", text: $vm.emergencyContact)
                        .keyboardType(.phonePad).fieldStyle()
                }
            }
        }
    }
}

struct MedicationCard: View {
    @Binding var entry: OnboardingViewModel.MedEntry
    let onDelete: () -> Void

    let timingOptions = ["Morning","Evening","With meals"]
    let methodOptions = ["With food","Hidden in treat","Direct"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Medication").font(.system(size: 13, weight: .semibold)).foregroundColor(Color.snootBrown)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red.opacity(0.7)).font(.system(size: 13))
                }
            }
            HighContrastTextField(placeholder: "Name (e.g. Apoquel)", text: $entry.name).fieldStyle()
            HighContrastTextField(placeholder: "Dose (e.g. 5.4mg)", text: $entry.dose).fieldStyle()
            VStack(alignment: .leading, spacing: 4) {
                Text("When").font(.caption).foregroundColor(.snootText2)
                SnootSegmentedControl(
                    options: timingOptions,
                    selection: $entry.timing,
                    label: { $0 }
                )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("How").font(.caption).foregroundColor(.snootText2)
                SnootSegmentedControl(
                    options: methodOptions,
                    selection: $entry.method,
                    label: { $0 }
                )
            }
        }
        .padding(14)
        .background(Color.snootOrange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.snootOrange.opacity(0.2), lineWidth: 1))
    }
}
