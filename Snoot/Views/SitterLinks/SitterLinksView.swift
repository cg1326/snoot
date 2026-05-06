import SwiftUI

struct SitterLinksView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @State private var links: [SitterLink] = []
    @State private var showCreate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if links.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.snootOrange.opacity(0.6))
                        Text("No active links yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.snootBrown)
                        Text(dog.canEdit
                             ? "Create a sitter link to share \(dog.name)'s care guide with anyone — no app required."
                             : "No sitter links have been created yet.")
                            .font(.system(size: 13))
                            .foregroundColor(.snootText2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(links.filter { $0.active }) { link in
                        ActiveLinkRow(link: link, canManage: dog.canEdit) {
                            await deactivate(link)
                        }
                        .listRowBackground(Color.white)
                    }
                }
            } header: {
                SectionHeader(title: "Active links")
            }

        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.snootCream.ignoresSafeArea())
        .navigationTitle("Sitter links")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if dog.canEdit {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.snootOrange)
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await loadLinks() } }) {
            CreateLinkView(dog: dog)
        }
        .task { await loadLinks() }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadLinks() async {
        guard auth.isAuthenticated else { return }
        guard let dogId = dog.supabaseId else {
            errorMessage = "\(dog.name)'s profile hasn't synced yet. Open the app while connected and try again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            links = try await SyncService.shared.fetchSitterLinks(dogId: dogId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivate(_ link: SitterLink) async {
        do {
            try await SyncService.shared.deactivateSitterLink(id: link.id)
            await loadLinks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Active link row
struct ActiveLinkRow: View {
    let link: SitterLink
    let canManage: Bool
    let onDeactivate: () async -> Void

    @State private var showShareSheet = false
    @State private var showDeactivateAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                modeBadge
                Spacer()
                expiryLabel
            }

            if let url = link.shareURL {
                Text(url.absoluteString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.snootText2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 10) {
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.snootOrange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)

                Button {
                    if let url = link.shareURL {
                        UIPasteboard.general.url = url
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundColor(.snootOrange)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.snootOrange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)

                Spacer()

                if canManage {
                    Button {
                        showDeactivateAlert = true
                    } label: {
                        Text("Deactivate")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showShareSheet) {
            if let url = link.shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Deactivate this link?", isPresented: $showDeactivateAlert) {
            Button("Deactivate", role: .destructive) { Task { await onDeactivate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The sitter will see a message that the link is no longer active.")
        }
    }

    private var modeBadge: some View {
        let color: Color = link.mode == "overnight" ? Color(red: 0.4, green: 0.3, blue: 0.7) : .snootSage
        let label = link.mode == "both" ? "Daytime + Overnight" : link.mode.capitalized
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var expiryLabel: some View {
        Group {
            if let exp = link.expiresAtDate {
                Text("Expires \(exp.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 11))
                    .foregroundColor(.snootText2)
            } else {
                Text("No expiry")
                    .font(.system(size: 11))
                    .foregroundColor(.snootText2)
            }
        }
    }
}
