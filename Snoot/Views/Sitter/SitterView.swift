import SwiftUI

struct SitterView: View {
    let dog: Dog
    @State private var mode: SitterMode = .daytime
    @Environment(\.dismiss) private var dismiss

    enum SitterMode: String, CaseIterable {
        case daytime = "Daytime"
        case overnight = "Overnight"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Mode toggle
                    Picker("", selection: $mode) {
                        ForEach(SitterMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    VStack(spacing: 16) {
                        // Quick intro
                        HStack(spacing: 12) {
                            if let data = dog.photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 56, height: 56).clipShape(Circle())
                            } else {
                                Circle().fill(Color.snootOrange.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                    .overlay(Image(systemName: "pawprint.fill").foregroundColor(Color.snootOrange))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dog.name).font(.system(size: 20, weight: .bold)).foregroundColor(Color.snootBrown)
                                Text("\(dog.breed) · \(dog.age)").font(.system(size: 14)).foregroundColor(.snootText2)
                            }
                            Spacer()
                        }
                        .padding(16).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 6)

                        // Feeding
                        SitterSection(icon: "fork.knife", title: "Mealtime", iconColor: Color.snootOrange) {
                            if dog.mealsPerDay == 0 {
                                InfoRow(label: "Feeding", value: "Free feed all day")
                            } else {
                                InfoRow(label: "Meals per day", value: "\(dog.mealsPerDay)")
                                let fmt = timeFormatter
                                ForEach(Array(dog.mealTimesData.enumerated()), id: \.offset) { i, t in
                                    InfoRow(label: "Meal \(i+1)", value: fmt.string(from: t))
                                }
                            }
                            if !dog.portionSize.isEmpty {
                                InfoRow(label: "Portion", value: "\(dog.portionSize) \(dog.portionUnit)")
                            }
                            if !dog.foodBrand.isEmpty {
                                InfoRow(label: "Food", value: dog.foodBrand)
                            }
                            if !dog.foodAllergies.isEmpty {
                                InfoRow(label: "Avoid", value: dog.foodAllergies.joined(separator: ", "), highlight: true)
                            }
                            InfoRow(label: "Treats", value: dog.treatsPolicy)
                        }

                        // Walks
                        SitterSection(icon: "figure.walk", title: "Walks", iconColor: Color.snootSage) {
                            InfoRow(label: "Walks today", value: "\(dog.walksPerDay)")
                            let fmt = timeFormatter
                            ForEach(Array(dog.walkTimesData.enumerated()), id: \.offset) { i, t in
                                InfoRow(label: "Walk \(i+1)", value: "\(fmt.string(from: t)) · \(dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes) min")")
                            }
                            if !dog.leashBehaviours.isEmpty {
                                InfoRow(label: "Leash notes", value: dog.leashBehaviours.joined(separator: ", "))
                            }
                            InfoRow(label: "Off-leash", value: dog.offLeashTrusted ? "Trusted ✓" : "Not trusted")
                            if !dog.offLeashNotes.isEmpty {
                                InfoRow(label: "", value: dog.offLeashNotes)
                            }
                        }

                        // Medications
                        if !dog.medications.isEmpty {
                            SitterSection(icon: "pill", title: "Medications", iconColor: .purple.opacity(0.7)) {
                                ForEach(dog.medications) { med in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(med.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Color.snootBrown)
                                        Text("\(med.dose) · \(med.timing) · \(med.method)")
                                            .font(.system(size: 13)).foregroundColor(.snootText2)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        // Behaviour flags
                        if !dog.fearTriggers.isEmpty || dog.separationAnxiety != "None" {
                            SitterSection(icon: "exclamationmark.triangle", title: "Heads up", iconColor: .orange) {
                                if !dog.fearTriggers.isEmpty {
                                    InfoRow(label: "Fears / triggers", value: dog.fearTriggers.joined(separator: ", "), highlight: true)
                                }
                                if dog.separationAnxiety != "None" && dog.separationAnxiety != "none" {
                                    InfoRow(label: "Separation anxiety", value: dog.separationAnxiety, highlight: dog.separationAnxiety == "Moderate" || dog.separationAnxiety == "Severe")
                                    if !dog.separationAnxietyNotes.isEmpty {
                                        InfoRow(label: "What helps", value: dog.separationAnxietyNotes)
                                    }
                                }
                                if !dog.pottySignal.isEmpty {
                                    InfoRow(label: "Potty signal", value: dog.pottySignal)
                                }
                            }
                        }

                        // Personality highlights
                        if !dog.personalityTags.isEmpty {
                            SitterSection(icon: "heart", title: "Personality", iconColor: Color.snootOrange) {
                                FlowLayout(spacing: 8) {
                                    ForEach(dog.personalityTags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(Color.snootOrange.opacity(0.1))
                                            .foregroundColor(Color.snootOrange)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Emergency contacts
                        SitterSection(icon: "phone.fill", title: "Emergency contacts", iconColor: .red.opacity(0.7)) {
                            if !dog.emergencyContact.isEmpty {
                                InfoRow(label: "Owner", value: dog.emergencyContact)
                            }
                            if !dog.vetName.isEmpty || !dog.vetPhone.isEmpty {
                                InfoRow(label: "Vet", value: [dog.vetName, dog.vetClinic, dog.vetPhone].filter { !$0.isEmpty }.joined(separator: " · "))
                            }
                            if dog.emergencyContact.isEmpty && dog.vetPhone.isEmpty {
                                Text("No contacts added yet").font(.system(size: 14)).foregroundColor(.snootText2)
                            }
                        }

                        // --- Overnight extras ---
                        if mode == .overnight {
                            SitterSection(icon: "moon.stars", title: "Bedtime", iconColor: Color(red: 0.4, green: 0.3, blue: 0.7)) {
                                InfoRow(label: "Sleeps", value: dog.sleepLocation)
                                InfoRow(label: "Bedtime", value: timeFormatter.string(from: dog.bedtimeDate))
                                if !dog.bedtimeRoutine.isEmpty {
                                    InfoRow(label: "Routine", value: dog.bedtimeRoutine.joined(separator: ", "))
                                }
                                if !dog.nighttimeQuirks.isEmpty {
                                    InfoRow(label: "Quirks", value: dog.nighttimeQuirks, highlight: true)
                                }
                            }

                            SitterSection(icon: "star.fill", title: "First 24 hours with \(dog.name)", iconColor: Color.snootSage) {
                                ForEach(first24Hours, id: \.self) { bullet in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•").foregroundColor(Color.snootSage)
                                        Text(bullet).font(.system(size: 14)).foregroundColor(Color.snootBrown)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle(mode == .daytime ? "Daytime care" : "Overnight care")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Auto-generated first 24 hours
    var first24Hours: [String] {
        var bullets: [String] = []
        if !dog.personalityTags.isEmpty {
            let top = dog.personalityTags.prefix(2).joined(separator: " and ")
            bullets.append("\(dog.name) is \(top) — give them a few minutes to sniff around and settle in.")
        }
        if dog.mealsPerDay > 0 && !dog.mealTimesData.isEmpty {
            let t = timeFormatter.string(from: dog.mealTimesData[0])
            bullets.append("First meal is at \(t)\(dog.portionSize.isEmpty ? "" : " — \(dog.portionSize) \(dog.portionUnit) of \(dog.foodBrand.isEmpty ? "their regular food" : dog.foodBrand)").")
        }
        if dog.walksPerDay > 0 && !dog.walkTimesData.isEmpty {
            let t = timeFormatter.string(from: dog.walkTimesData[0])
            bullets.append("First walk is around \(t) (\(dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes) min")).")
        }
        if !dog.comfortItems.isEmpty {
            bullets.append("If \(dog.name) seems unsettled, their comfort items are: \(dog.comfortItems).")
        } else if dog.separationAnxiety == "Moderate" || dog.separationAnxiety == "Severe" {
            bullets.append("\(dog.name) can get anxious when left alone\(dog.separationAnxietyNotes.isEmpty ? "" : " — \(dog.separationAnxietyNotes)").")
        }
        if bullets.count < 3 {
            bullets.append("When in doubt, give \(dog.name) a treat and a belly rub. Works every time.")
        }
        return Array(bullets.prefix(4))
    }

    var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
}

// MARK: - Reusable sitter section
struct SitterSection<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.snootBrown)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }
}

// MARK: - Info row
struct InfoRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.snootText2)
                    .frame(width: 95, alignment: .leading)
            }
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(highlight ? Color(red: 0.8, green: 0.2, blue: 0.1) : Color.snootBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
