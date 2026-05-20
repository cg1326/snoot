import SwiftUI

struct SitterLinksView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var links: [SitterLink] = []
    @State private var showCreate = false
    @State private var showPaywall = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if !subscriptionService.isPro && dog.canEdit {
                    // Pro gate — user can edit but doesn't have Pro
                    VStack(spacing: 16) {
                        Image(systemName: "lock.circle.fill")
                            .font(.jakarta(40))
                            .foregroundColor(.snootOrange.opacity(0.7))
                        Text("Sitter links are a Pro feature")
                            .font(.jakarta(15, weight: .semibold))
                            .foregroundColor(.snootBrown)
                        Text("Upgrade to Snoot Pro to create shareable care guide links for your sitter.")
                            .font(.jakarta(13))
                            .foregroundColor(.snootText2)
                            .multilineTextAlignment(.center)
                        Button {
                            showPaywall = true
                        } label: {
                            Text("Upgrade to Pro")
                                .font(.jakarta(14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.snootOrange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                } else if links.filter({ $0.active }).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.jakarta(36))
                            .foregroundColor(.snootOrange.opacity(0.6))
                        Text("No active links yet")
                            .font(.jakarta(15, weight: .semibold))
                            .foregroundColor(.snootBrown)
                        Text(dog.canEdit
                             ? "Create a sitter link to share \(dog.name)'s care guide with anyone. No app required."
                             : "No sitter links have been created yet.")
                            .font(.jakarta(13))
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
                HStack {
                    SectionHeader(title: "Active links")
                    Spacer()
                    if !subscriptionService.isPro {
                        Text("PRO")
                            .font(.jakarta(10, weight: .bold))
                            .foregroundColor(.snootOrange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.snootOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
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
                        if subscriptionService.isPro {
                            showCreate = true
                        } else {
                            showPaywall = true
                        }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
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
                        .font(.jakarta(13, weight: .semibold))
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
                        .font(.jakarta(13, weight: .semibold))
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
                            .font(.jakarta(13, weight: .semibold))
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
            .font(.jakarta(12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var expiryLabel: some View {
        Group {
            if let exp = link.expiresAtDate {
                Text("Expires \(exp.formatted(.relative(presentation: .named)))")
                    .font(.jakarta(11))
                    .foregroundColor(.snootText2)
            } else {
                Text("No expiry")
                    .font(.jakarta(11))
                    .foregroundColor(.snootText2)
            }
        }
    }
}
