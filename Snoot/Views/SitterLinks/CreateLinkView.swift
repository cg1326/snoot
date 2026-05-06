import SwiftUI

struct CreateLinkView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: LinkMode = .daytime
    @State private var expiry: ExpiryOption = .none
    @State private var isCreating = false
    @State private var createdLink: SitterLink?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    enum LinkMode: String, CaseIterable {
        case daytime = "Daytime"
        case overnight = "Overnight"

        var apiValue: String {
            switch self {
            case .daytime: return "daytime"
            case .overnight: return "overnight"
            }
        }
    }

    enum ExpiryOption: String, CaseIterable {
        case none = "No expiry"
        case week = "1 week"
        case month = "1 month"

        var date: Date? {
            let cal = Calendar.current
            switch self {
            case .none:  return nil
            case .week:  return cal.date(byAdding: .day, value: 7, to: Date())
            case .month: return cal.date(byAdding: .month, value: 1, to: Date())
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let link = createdLink {
                        // ── Success state ──
                        successView(link: link)
                    } else {
                        // ── Create form ──
                        if isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            createForm
                        }
                    }
                }
                .padding()
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle("Create sitter link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Create form
    private var createForm: some View {
        VStack(spacing: 20) {
            // Illustration
            VStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.snootOrange)
                Text("Share \(dog.name)'s care guide")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.snootBrown)
                Text("Anyone with the link can view the guide — no app required.")
                    .font(.system(size: 14))
                    .foregroundColor(.snootText2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Care mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.snootText2)
                Picker("Mode", selection: $mode) {
                    ForEach(LinkMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4)

            // Expiry picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Link expiry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.snootText2)
                ForEach(ExpiryOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation { expiry = option }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                                .font(.system(size: 16))
                                .foregroundColor(Color.snootBrown)
                            Spacer()
                            if expiry == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.snootOrange)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if option != ExpiryOption.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Create button
            Button {
                Task { await createLink() }
            } label: {
                Group {
                    if isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create link")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.snootOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isCreating)
        }
    }

    // MARK: - Success view
    private func successView(link: SitterLink) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.snootSage)
                Text("Link created!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.snootBrown)
            }
            .padding(.top, 8)

            // URL card
            VStack(spacing: 8) {
                if let url = link.shareURL {
                    Text(url.absoluteString)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.snootBrown)
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.snootOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        UIPasteboard.general.url = url
                    } label: {
                        Label("Copy link", systemImage: "doc.on.doc")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.snootOrange)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.snootOrange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4)

            Button {
                showShareSheet = true
            } label: {
                Label("Share via iMessage / Email", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.snootOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.snootOrange)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = createdLink?.shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Create action
    private func createLink() async {
        guard let dogId = dog.supabaseId, let userId = auth.currentUser?.id else {
            errorMessage = "Please finish syncing your dog profile first."
            return
        }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let link = try await SyncService.shared.createSitterLink(
                dogId: dogId,
                mode: mode.apiValue,
                expiresAt: expiry.date,
                createdBy: userId
            )
            withAnimation { createdLink = link }
        } catch {
            if error.localizedDescription.contains("row-level security policy") {
                errorMessage = "You don't have permission to create links. Please ask an owner or editor."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
