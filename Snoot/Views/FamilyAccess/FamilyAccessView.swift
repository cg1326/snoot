import SwiftUI
import Supabase

struct FamilyAccessView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @State private var owners: [DogOwner] = []
    @State private var isLoading = false
    @State private var showInvite = false
    @State private var errorMessage: String?
    @State private var inviteEmail = ""
    @State private var inviteRole = "editor"
    @State private var isInviting = false
    @State private var inviteSuccess = false
    @State private var dogOwnerId: String? = nil
    @State private var dogOwnerEmail: String? = nil
    @State private var dogOwnerName: String? = nil

    var allMembers: [DogOwner] {
        var list = owners
        // If we have the original owner info, add them to the top if they aren't already there
        if let ownerId = dogOwnerId, !owners.contains(where: { $0.userId == ownerId }) {
            let owner = DogOwner(
                id: "owner-\(ownerId)",
                dogId: dog.supabaseId ?? "",
                userId: ownerId,
                role: "owner",
                invitedEmail: dogOwnerEmail,
                accepted: true,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                user: SupabaseUser(id: ownerId, email: dogOwnerEmail ?? "", displayName: dogOwnerName ?? "Owner")
            )
            list.insert(owner, at: 0)
        }
        return list
    }

    var body: some View {
        List {
            Section {
                ForEach(allMembers) { owner in
                    FamilyMemberRow(
                        owner: owner,
                        isCurrentUser: owner.userId == auth.currentUser?.id,
                        canManage: dog.canEdit && (owner.role != "owner"),
                        onRemove: { await removeMember(owner) },
                        onRoleChange: { newRole in await updateRole(owner, role: newRole) }
                    )
                }
            } header: {
                SectionHeader(title: "Family members")
            } footer: {
                if !dog.canEdit {
                    Text("You have view-only access to this family.")
                        .font(.system(size: 12))
                        .foregroundColor(.snootOrange)
                } else {
                    Text("Editors can update all care sections. Viewers can only read the profile.")
                        .font(.system(size: 12))
                        .foregroundColor(.snootText2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.snootCream.ignoresSafeArea())
        .navigationTitle("Family access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if dog.canEdit {
                    Button {
                        showInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.snootOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            inviteSheet
        }
        .task { await loadOwners() }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var inviteSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.snootOrange)
                        Text("Invite someone")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.snootBrown)
                        Text("Share the app with them — they'll see \(dog.name)'s profile when they sign in with this email.")
                            .font(.system(size: 14))
                            .foregroundColor(.snootText2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    if inviteSuccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.snootSage)
                            Text("Invite sent to \(inviteEmail)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.snootBrown)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.snootSage.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 14) {
                            SnootTextField(icon: "envelope", placeholder: "Email address", text: $inviteEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Role")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.snootText2)
                                Picker("Role", selection: $inviteRole) {
                                    Text("Editor").tag("editor")
                                    Text("Viewer").tag("viewer")
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                Task { await sendInvite() }
                            } label: {
                                Group {
                                    if isInviting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Send invite")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.snootOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isInviting || inviteEmail.isEmpty)
                        }
                    }
                }
                .padding()
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle("Invite someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showInvite = false
                        inviteEmail = ""
                        inviteSuccess = false
                        Task { await loadOwners() }
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func loadOwners() async {
        guard let dogId = dog.supabaseId, auth.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        // Reset to avoid showing stale members while reloading
        owners = []
        // Accept any pending invites before loading so the current user's status is fresh
        if let user = auth.currentUser {
            await SyncService.shared.acceptPendingInvites(user: user)
        }
        do {
            // Fetch the dog's own fields only — no users join so dogOwnerId is always
            // set regardless of whether the users visibility policy covers this member role.
            let serverDog: SupabaseDog = try await SyncService.shared.supabase
                .from("dogs")
                .select("*")
                .eq("id", value: dogId)
                .single()
                .execute()
                .value

            // Best-effort: fetch the owner's profile separately.
            let ownerProfile: SupabaseUser? = try? await SyncService.shared.fetchUserProfile(userId: serverDog.ownerId)

            await MainActor.run {
                self.dogOwnerId = serverDog.ownerId
                self.dogOwnerEmail = ownerProfile?.email
                self.dogOwnerName = ownerProfile?.displayName
            }

            // Fetch invited members (no users join — avoids PostgREST array/object decode mismatch).
            // Exclude any spurious row where the primary dog owner also appears in dog_owners.
            let fetchedOwners = try await SyncService.shared.fetchDogOwners(dogId: dogId)
            let filtered = fetchedOwners.filter { $0.userId != serverDog.ownerId }

            // Enrich each member row with their user profile (best-effort per-row).
            var enriched: [DogOwner] = []
            for var owner in filtered {
                if let uid = owner.userId {
                    owner.user = try? await SyncService.shared.fetchUserProfile(userId: uid)
                }
                enriched.append(owner)
            }
            owners = enriched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendInvite() async {
        guard let dogId = dog.supabaseId, let userId = auth.currentUser?.id else { return }
        isInviting = true
        defer { isInviting = false }
        do {
            try await SyncService.shared.inviteFamilyMember(
                dogId: dogId,
                email: inviteEmail,
                role: inviteRole,
                createdBy: userId
            )
            withAnimation { inviteSuccess = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeMember(_ owner: DogOwner) async {
        do {
            try await SyncService.shared.removeFamilyMember(ownerId: owner.id)
            await loadOwners()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateRole(_ owner: DogOwner, role: String) async {
        do {
            try await SyncService.shared.updateFamilyRole(ownerId: owner.id, role: role)
            await loadOwners()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Family member row
struct FamilyMemberRow: View {
    let owner: DogOwner
    let isCurrentUser: Bool
    let canManage: Bool
    let onRemove: () async -> Void
    let onRoleChange: (String) async -> Void

    @State private var showRemoveAlert = false
    @State private var showRolePicker = false

    var displayName: String {
        let name = owner.user?.displayName ?? ""
        if !name.isEmpty { return name }
        return owner.invitedEmail ?? "Unknown"
    }

    var subtitle: String {
        let email = owner.user?.email ?? owner.invitedEmail ?? ""
        if !owner.accepted {
            return "Invite pending · \(email)"
        }
        // If display name is the same as email, don't show it twice
        if displayName.lowercased() == email.lowercased() {
            return ""
        }
        return email
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(avatarColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.snootBrown)
                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 11))
                            .foregroundColor(.snootText2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.snootText2.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.snootText2)
                        .lineLimit(1)
                }
            }
            Spacer()

            // Role badge (tappable for owner to change)
            if canManage && !isCurrentUser && owner.role != "owner" {
                Menu {
                    Button("Editor") { Task { await onRoleChange("editor") } }
                    Button("Viewer") { Task { await onRoleChange("viewer") } }
                    Divider()
                    Button("Remove access", role: .destructive) { showRemoveAlert = true }
                } label: {
                    roleBadge
                }
            } else {
                roleBadge
            }
        }
        .padding(.vertical, 4)
        .alert("Remove access?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) { Task { await onRemove() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(displayName) will no longer have access to this dog's profile.")
        }
    }

    private var roleBadge: some View {
        let color: Color = owner.role == "owner" ? .snootOrange : owner.role == "editor" ? .snootSage : .secondary
        return Text(owner.accepted ? owner.role.capitalized : "Pending")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var avatarColor: Color {
        let colors: [Color] = [.snootOrange, .snootSage, .purple, .blue, .pink]
        let index = abs(displayName.hashValue) % colors.count
        return colors[index]
    }
}
