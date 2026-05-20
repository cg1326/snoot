import SwiftUI
import SwiftData

struct LogVisitView: View {
    let dog: Dog
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Binding var isPresented: Bool

    @State private var loggedByName: String = ""
    @State private var fed: Bool = false
    @State private var walked: Bool = false
    @State private var walkDurationMins: Int = 30
    @State private var notes: String = ""

    private let durationOptions = [15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - Logged by
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logged by")
                            .font(.jakarta(13, weight: .semibold))
                            .foregroundColor(.snootText2)
                            .padding(.horizontal, 4)

                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.snootOrange)
                                .font(.jakarta(18))
                            TextField("Name", text: $loggedByName)
                                .font(.jakarta(16))
                                .foregroundColor(.snootText1)
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        .cardShadow()
                    }

                    // MARK: - Activities
                    VStack(spacing: 0) {
                        // Fed toggle
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.snootOrange)
                                    .frame(width: 22)
                                Text("Fed \(dog.name)")
                                    .font(.jakarta(16))
                                    .foregroundColor(.snootText1)
                            }
                            Spacer()
                            Toggle("", isOn: $fed)
                                .tint(.snootOrange)
                                .labelsHidden()
                        }
                        .padding(16)
                        .background(Color.white)

                        Divider()
                            .padding(.leading, 52)
                            .background(Color.white)

                        // Walked toggle
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.snootOrange)
                                    .frame(width: 22)
                                Text("Walked \(dog.name)")
                                    .font(.jakarta(16))
                                    .foregroundColor(.snootText1)
                            }
                            Spacer()
                            Toggle("", isOn: $walked)
                                .tint(.snootOrange)
                                .labelsHidden()
                        }
                        .padding(16)
                        .background(Color.white)

                        // Walk duration (shown only if walked)
                        if walked {
                            Divider()
                                .padding(.leading, 52)
                                .background(Color.white)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Walk duration")
                                    .font(.jakarta(13, weight: .semibold))
                                    .foregroundColor(.snootText2)

                                HStack(spacing: 8) {
                                    ForEach(durationOptions, id: \.self) { mins in
                                        Button {
                                            walkDurationMins = mins
                                        } label: {
                                            Text(mins == 60 ? "1hr+" : "\(mins)min")
                                                .font(.jakarta(14, weight: .semibold))
                                                .foregroundColor(walkDurationMins == mins ? .white : .snootOrange)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 9)
                                                .background(walkDurationMins == mins ? Color.snootOrange : Color.snootOrange.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                    .cardShadow()

                    // MARK: - Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.jakarta(13, weight: .semibold))
                            .foregroundColor(.snootText2)
                            .padding(.horizontal, 4)

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Anything to mention about the visit…")
                                    .font(.jakarta(15))
                                    .foregroundColor(.snootText2.opacity(0.5))
                                    .padding(14)
                            }
                            TextEditor(text: $notes)
                                .font(.jakarta(15))
                                .foregroundColor(.snootText1)
                                .frame(minHeight: 90)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        .cardShadow()
                    }

                    // MARK: - Log visit button
                    Button {
                        saveVisit()
                    } label: {
                        Text("Log visit")
                            .font(.jakarta(17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(canSave ? Color.snootOrange : Color.snootOrange.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                    }
                    .disabled(!canSave)
                }
                .padding(16)
                .padding(.bottom, 8)
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle("Log visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.snootOrange)
                }
            }
            .onAppear {
                loggedByName = auth.currentUser?.displayName ?? "Me"
                if loggedByName.isEmpty { loggedByName = "Me" }
            }
        }
    }

    private var canSave: Bool {
        !loggedByName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveVisit() {
        let visit = ManualVisit(dogLocalId: dog.id, loggedByName: loggedByName.trimmingCharacters(in: .whitespaces))
        visit.fed = fed
        visit.walked = walked
        visit.walkDurationMins = walked ? walkDurationMins : 0
        visit.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(visit)
        try? modelContext.save()
        isPresented = false
    }
}
