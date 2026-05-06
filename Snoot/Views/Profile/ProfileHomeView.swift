import SwiftUI
import SwiftData

struct ProfileHomeView: View {
    @Bindable var dog: Dog
    @Environment(AuthService.self) private var auth
    @Environment(NetworkMonitor.self) private var network

    @State private var showSitter = false
    @State private var showShare = false
    @State private var showSitterLinks = false
    @State private var showVisitHistory = false
    @State private var showFamilyAccess = false
    @State private var showAuth = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var activeLinkCount = 0
    
    struct EditConfig: Identifiable {
        let id = UUID()
        let step: Int
    }
    @State private var editConfig: EditConfig?
    @State private var latestVisit: VisitLog?
    @State private var familyCount = 0
    @State private var toastMessage: String?
    @State private var isSyncing = false
    @State private var editStartingStep = 1
    @State private var bioExpanded = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                heroSection

                VStack(spacing: 20) {
                    // Offline notice
                    if !network.isConnected {
                        OfflineBanner()
                    }

                    // Care profile grid
                    careProfileSection

                    // Sync / feature rows / sign-in prompt
                    if auth.isAuthenticated && dog.supabaseId != nil {
                        featureRows
                    } else if !auth.isAuthenticated {
                        signInPrompt
                    } else if auth.isAuthenticated && dog.supabaseId == nil {
                        syncButton
                    }

                    // Action buttons
                    actionButtons
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.snootCream.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if dog.canEdit {
                        Button { editConfig = EditConfig(step: 1) } label: {
                            Label("Edit profile", systemImage: "pencil")
                        }
                    }
                    if !dog.isShared {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete profile", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .confirmationDialog("Delete \(dog.name)'s profile?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { context.delete(dog); dismiss() }
        } message: {
            Text("This will permanently remove the profile from this device.")
        }
        .fullScreenCover(item: $editConfig) { config in
            OnboardingFlowView(editingDog: dog, startingStep: config.step) { editedDog in
                editConfig = nil
                // Sync updated profile
                Task {
                    if auth.isAuthenticated {
                        try? await SyncService.shared.pushDog(editedDog, auth: auth)
                        await SyncService.shared.uploadPhotoIfNeeded(dog: editedDog, auth: auth)
                    }
                }
            }
        }
        .sheet(isPresented: $showSitter) { SitterView(dog: dog) }
        .sheet(isPresented: $showShare) { ShareModal(dog: dog) }
        .sheet(isPresented: $showSitterLinks, onDismiss: { Task { await loadFeatureData() } }) {
            NavigationStack { SitterLinksView(dog: dog) }
        }
        .sheet(isPresented: $showVisitHistory, onDismiss: { Task { await loadFeatureData() } }) {
            NavigationStack { VisitHistoryView(dog: dog) }
        }
        .sheet(isPresented: $showFamilyAccess, onDismiss: { Task { await loadFeatureData() } }) {
            NavigationStack { FamilyAccessView(dog: dog) }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
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
        .task {
            if auth.isAuthenticated && dog.supabaseId != nil {
                try? await SyncService.shared.pushDog(dog, auth: auth)
                await loadFeatureData()
            }
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Photo or fallback
                Group {
                    if let data = dog.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [Color.snootOrange, Color(hex: "#F9A88B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.6))
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color(hex: "#1A1A1A").opacity(0.7), .clear],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(height: 120) 
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fill)

            // Floating name card
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dog.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.snootText1)
                            .tracking(-0.3)
                        Text("\(dog.breed) · \(dog.age) · \(Int(dog.weightLbs)) lbs")
                            .font(.system(size: 13))
                            .foregroundColor(.snootText2)
                    }
                    Spacer()
                    if dog.isSample || dog.isShared {
                        Text(dog.isSample ? "SAMPLE" : "SHARED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.snootSage)
                            .clipShape(Capsule())
                    }
                }

                if !dog.personalityTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(dog.personalityTags.prefix(8), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.snootOrange)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.snootOrange.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.small))
                            }
                        }
                    }
                }

                if !dog.bio.isEmpty {
                    Text(dog.bio)
                        .font(.system(size: 14))
                        .foregroundColor(.snootText2)
                        .lineLimit(bioExpanded ? nil : 3)
                        .onTapGesture {
                            bioExpanded.toggle()
                        }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.snootCardBG)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 24))
            .elevatedShadow()
            .offset(y: -24)
            .padding(.bottom, -24)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Care profile grid
    private var careProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARE PROFILE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.snootOrange)
                .tracking(0.5)
                .padding(.leading, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(sectionData, id: \.title) { section in
                    CareCard(
                        icon: section.icon,
                        title: section.title,
                        summary: section.summary,
                        isComplete: section.isComplete
                    )
                    .onTapGesture {
                        if !dog.isShared || dog.sharedRole == "editor" {
                            editConfig = EditConfig(step: section.step)
                        } else {
                            toast("You only have view access.")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Feature rows
    private var featureRows: some View {
        VStack(spacing: 10) {
            ProfileFeatureRow(
                icon: "link.circle.fill",
                iconColor: Color.snootOrange,
                accentColor: Color.snootOrange,
                title: "Sitter links",
                subtitle: activeLinkCount == 0 ? "No active links" : "\(activeLinkCount) active link\(activeLinkCount == 1 ? "" : "s")",
                badge: nil
            ) { showSitterLinks = true }

            ProfileFeatureRow(
                icon: "clock.badge.checkmark",
                iconColor: Color.snootSage,
                accentColor: Color.snootSage,
                title: "Recent visits",
                subtitle: latestVisit.map { "Last: \($0.loggedByName) · \($0.visitedAtDate.formatted(.relative(presentation: .named)))" } ?? "No visits yet",
                badge: latestVisitIsNew ? "New" : nil
            ) { showVisitHistory = true }

            ProfileFeatureRow(
                icon: "person.2.circle.fill",
                iconColor: Color.snootAmber,
                accentColor: Color.snootAmber,
                title: "Family access",
                subtitle: familyCount <= 1 ? "Only you" : "\(familyCount) people have access",
                badge: nil
            ) { showFamilyAccess = true }
        }
        .padding(.horizontal, 16)
    }

    private var signInPrompt: some View {
        Button { showAuth = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.snootOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to unlock sharing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.snootText1)
                    Text("Create sitter links, track visits, invite family")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.snootText3).font(.system(size: 13))
            }
            .padding(16)
            .background(Color.snootCardBG)
            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            .cardShadow()
            .padding(.horizontal, 16)
        }
    }

    private var syncButton: some View {
        Button { Task { await syncDog() } } label: {
            HStack(spacing: 12) {
                if isSyncing {
                    ProgressView().scaleEffect(0.9).tint(.snootOrange)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(.snootOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSyncing ? "Uploading profile…" : "Upload profile to enable sharing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.snootText1)
                    Text("Enables sitter links, visit logs, and family access")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.snootText3).font(.system(size: 13))
            }
            .padding(16)
            .background(Color.snootCardBG)
            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            .cardShadow()
            .padding(.horizontal, 16)
        }
        .disabled(isSyncing)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { showSitter = true } label: {
                Label("Preview care guide", systemImage: "person.fill.questionmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.snootSage)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            }

            Button { showShare = true } label: {
                Label("Export / share guide", systemImage: "doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.snootOrange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.snootCardBG)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                    .overlay(RoundedRectangle(cornerRadius: SnootRadius.medium).stroke(Color.snootOrange, lineWidth: 1.5))
            }

            Text("Sitters access care guides via a private link — no app needed.")
                .font(.system(size: 12))
                .foregroundColor(.snootText3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers (keep logic exactly as-is)
    private var latestVisitIsNew: Bool {
        guard let visit = latestVisit else { return false }
        let key = "seenVisitIds_\(dog.supabaseId ?? dog.id.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let seen = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return true }
        return !seen.contains(visit.id)
    }

    private func syncDog() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await SyncService.shared.pushDog(dog, auth: auth)
            await SyncService.shared.uploadPhotoIfNeeded(dog: dog, auth: auth)
            if dog.supabaseId != nil {
                await loadFeatureData()
                toast("Profile uploaded — sharing features unlocked!")
            }
        } catch {
            toast("Upload failed: \(error.localizedDescription)")
        }
    }

    private func loadFeatureData() async {
        guard let dogId = dog.supabaseId else { return }

        // Sitter links + visits run concurrently
        async let linksTask = SyncService.shared.fetchSitterLinks(dogId: dogId)
        async let visitsTask = SyncService.shared.fetchVisitLogs(dogId: dogId)
        do {
            let (links, visits) = try await (linksTask, visitsTask)
            await MainActor.run {
                activeLinkCount = links.filter { $0.active }.count
                latestVisit = visits.first
            }
        } catch { }

        // Family count runs separately so a failure here doesn't affect links/visits.
        // familyCount = invited members + 1 (the primary owner from dogs.owner_id).
        // For the owner: exclude any spurious dog_owners row they may have for themselves.
        // For a viewer: count all dog_owners rows — their own row IS a valid invited member.
        do {
            let owners = try await SyncService.shared.fetchDogOwners(dogId: dogId)
            let currentUserId = auth.currentUser?.id
            let invitedCount = dog.isShared
                ? owners.count                                            // viewer: all rows are invitees
                : owners.filter { $0.userId != currentUserId }.count     // owner: drop own spurious row
            await MainActor.run {
                familyCount = invitedCount + 1
            }
        } catch { }
    }

    private func toast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }

    struct SectionInfo {
        let icon: String; let title: String; let step: Int; let isComplete: Bool; let summary: String
    }

    var sectionData: [SectionInfo] {
        [
            .init(icon: "fork.knife", title: "Mealtime", step: 4,
                  isComplete: !dog.foodBrand.isEmpty || dog.mealsPerDay > 0,
                  summary: dog.mealsPerDay == 0 ? "Free feed" : "\(dog.mealsPerDay) meal\(dog.mealsPerDay > 1 ? "s" : "") a day"),
            .init(icon: "figure.walk", title: "Walks", step: 5,
                  isComplete: !dog.walkTimesData.isEmpty,
                  summary: "\(dog.walksPerDay) walk\(dog.walksPerDay > 1 ? "s" : "") · \(dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes)min")"),
            .init(icon: "heart", title: "Personality", step: 2,
                  isComplete: !dog.personalityTags.isEmpty,
                  summary: dog.personalityTags.prefix(3).joined(separator: ", ")),
            .init(icon: "bolt", title: "Quirks & Behaviour", step: 6,
                  isComplete: !dog.fearTriggers.isEmpty || !dog.pottySignal.isEmpty,
                  summary: dog.fearTriggers.isEmpty ? (dog.pottySignal.isEmpty ? "Not filled in" : dog.pottySignal) : dog.fearTriggers.prefix(2).joined(separator: ", ")),
            .init(icon: "cross.case", title: "Health & Meds", step: 7,
                  isComplete: !dog.vetName.isEmpty || !dog.medications.isEmpty,
                  summary: dog.medications.isEmpty ? (dog.vetName.isEmpty ? "Not filled in" : "Vet: \(dog.vetName)") : "\(dog.medications.count) medication\(dog.medications.count > 1 ? "s" : "")"),
            .init(icon: "moon.stars", title: "Bedtime", step: 8,
                  isComplete: !dog.bedtimeRoutine.isEmpty || !dog.nighttimeQuirks.isEmpty,
                  summary: dog.bedtimeRoutine.isEmpty ? (dog.nighttimeQuirks.isEmpty ? "Not filled in" : dog.nighttimeQuirks) : dog.bedtimeRoutine.prefix(2).joined(separator: ", "))
        ]
    }
}

// MARK: - Care card
struct CareCard: View {
    let icon: String
    let title: String
    let summary: String
    let isComplete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color.snootSage)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "#EBF4EA"))
                    .clipShape(Circle())
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.snootSage)
                } else {
                    Circle()
                        .fill(Color.snootOrange)
                        .frame(width: 8, height: 8)
                }
            }
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.snootText1)
            Text(isComplete ? summary : "Tap to add")
                .font(.system(size: 12))
                .foregroundColor(isComplete ? .snootText2 : .snootOrange.opacity(0.8))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.snootCardBG)
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .subtleShadow()
    }
}

// MARK: - Feature row with accent bar
struct ProfileFeatureRow: View {
    let icon: String
    let iconColor: Color
    let accentColor: Color
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar
                accentColor
                    .frame(width: 4)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: SnootRadius.medium, bottomLeadingRadius: SnootRadius.medium, bottomTrailingRadius: 0, topTrailingRadius: 0))

                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .frame(width: 36, height: 36)
                        .background(iconColor.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.snootText1)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.snootText2)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.snootOrange)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText3)
                }
                .padding(16)
            }
            .background(Color.snootCardBG)
            .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            .cardShadow()
        }
    }
}

// Keep HeroCard name for any remaining references (now replaced by heroSection above)
struct HeroCard: View {
    let dog: Dog
    var body: some View { EmptyView() }
}
