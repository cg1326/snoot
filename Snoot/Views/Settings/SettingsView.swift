import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var dogs: [Dog]

    @State private var displayName = ""
    @State private var showPasswordChange = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var notificationsEnabled = true
    @State private var showDeleteAccount = false
    @State private var showSignOutConfirm = false
    @State private var isSavingName = false
    @State private var nameSaved = false
    @State private var toastMessage: String?

    var body: some View {
        List {
            // MARK: - Account
            Section("Account") {
                if auth.isAuthenticated {
                    // Display name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.snootText2)
                        HStack {
                            HighContrastTextField(placeholder: "Your name", text: $displayName)
                                .font(.system(size: 16))
                                .onSubmit { Task { await saveName() } }
                            if isSavingName {
                                ProgressView().scaleEffect(0.8)
                            } else if nameSaved {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.snootSage)
                            }
                        }
                    }

                    // Email (read-only)
                    LabeledContent("Email") {
                        Text(auth.currentUser?.email ?? "")
                            .foregroundColor(.snootText2)
                    }

                    // Change password
                    Button("Change password") { showPasswordChange = true }
                        .foregroundColor(.snootOrange)

                    // Sign out
                    Button("Sign out") { showSignOutConfirm = true }
                        .foregroundColor(.red)
                } else {
                    Text("Not signed in")
                        .foregroundColor(.snootText2)
                }
            }

            // MARK: - Notifications
            Section("Notifications") {
                Toggle("Visit log alerts", isOn: $notificationsEnabled)
                    .tint(.snootOrange)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            VisitHistoryView.requestNotificationPermission()
                        }
                    }
                Text("Get notified when a sitter logs a visit.")
                    .font(.system(size: 12))
                    .foregroundColor(.snootText2)
            }

            // MARK: - Data
            Section("Data") {
                Button {
                    exportData()
                } label: {
                    Label("Export all data as JSON", systemImage: "square.and.arrow.up")
                        .foregroundColor(.snootOrange)
                }

                if auth.isAuthenticated {
                    Button("Delete account") { showDeleteAccount = true }
                        .foregroundColor(.red)
                }
            }

            // MARK: - About
            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.snootText2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.snootCream.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = auth.currentUser?.displayName ?? ""
        }
        // Change password sheet
        .sheet(isPresented: $showPasswordChange) {
            changePasswordSheet
        }
        // Confirm sign out
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
        }
        // Confirm delete account
        .confirmationDialog("Delete your account?", isPresented: $showDeleteAccount, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task {
                    await auth.deleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete your account. Your local dog profiles will remain on this device.")
        }
        // Toast overlay
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.snootBrown.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Change password sheet
    private var changePasswordSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PasswordField(placeholder: "New password", text: $newPassword, show: .constant(false))
                PasswordField(placeholder: "Confirm password", text: $confirmPassword, show: .constant(false))

                if newPassword != confirmPassword && !confirmPassword.isEmpty {
                    Text("Passwords don't match")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }

                Button("Update password") {
                    Task {
                        await auth.updatePassword(newPassword)
                        showPasswordChange = false
                        toast("Password updated")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.snootOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(newPassword.count < 6 || newPassword != confirmPassword)

                Spacer()
            }
            .padding()
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasswordChange = false }
                }
            }
        }
    }

    // MARK: - Actions
    private func saveName() async {
        isSavingName = true
        await auth.updateDisplayName(displayName)
        isSavingName = false
        nameSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { nameSaved = false }
    }

    private func exportData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let allDogs = dogs.map { dog -> [String: Any] in
            let d: [String: Any] = [
                "name": dog.name, "breed": dog.breed,
                "dateOfBirth": dog.dateOfBirth.ISO8601Format(),
                "weightLbs": dog.weightLbs, "bio": dog.bio,
                "personalityTags": dog.personalityTags,
                "mealsPerDay": dog.mealsPerDay, "foodBrand": dog.foodBrand,
                "walksPerDay": dog.walksPerDay,
                "fearTriggers": dog.fearTriggers,
                "separationAnxiety": dog.separationAnxiety,
                "vetName": dog.vetName, "vetPhone": dog.vetPhone,
                "sleepLocation": dog.sleepLocation
            ]
            return d
        }
        guard let data = try? JSONSerialization.data(withJSONObject: allDogs, options: [.prettyPrinted]) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snoot_export.json")
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?
            .present(vc, animated: true)
    }

    private func toast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
}
