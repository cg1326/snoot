import SwiftUI
import SwiftData

struct ProfileHomeView: View {
    @Bindable var dog: Dog
    @Environment(AuthService.self) private var auth
    @Environment(NetworkMonitor.self) private var network
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var showSitter = false
    @State private var showShare = false
    @State private var showSitterLinks = false
    @State private var showVisitHistory = false
    @State private var showFamilyAccess = false
    @State private var showAuth = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false
    @State private var activeLinkCount = 0
    
    struct EditConfig: Identifiable {
        let id = UUID()
        let step: Int
        var readOnly: Bool = false
    }
    @State private var editConfig: EditConfig?
    @State private var latestVisit: VisitLog?
    @State private var familyCount = 0
    @State private var toastMessage: String?
    @State private var isSyncing = false
    @State private var editStartingStep = 1
    @State private var bioExpanded = false
    @State private var careCardHeight: CGFloat?
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

                    // Sync / feature rows
                    if auth.isAuthenticated && dog.supabaseId != nil {
                        featureRows
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
                        Button { editConfig = EditConfig(step: dog.isShared ? 4 : 1) } label: {
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
            Button("Delete", role: .destructive) {
                let sid = dog.supabaseId
                context.delete(dog)
                dismiss()
                if let id = sid {
                    Task { await SyncService.shared.deleteDog(id: id) }
                }
            }
        } message: {
            Text("This will permanently remove the profile from this device.")
        }
        .fullScreenCover(item: $editConfig) { config in
            OnboardingFlowView(editingDog: dog, startingStep: config.step, readOnly: config.readOnly) { editedDog in
                editConfig = nil
                // Sync updated profile. Owners do a full push (dogs + care_profile tables).
                // Editors only push care_profile — they must not overwrite dogs.owner_id.
                // Viewers are read-only; their local edits are never pushed.
                Task {
                    if auth.isAuthenticated {
                        if !editedDog.isShared {
                            try? await SyncService.shared.pushDog(editedDog, auth: auth)
                            await SyncService.shared.uploadPhotoIfNeeded(dog: editedDog, auth: auth)
                        } else if editedDog.sharedRole == "editor" {
                            await SyncService.shared.pushCareProfile(dog: editedDog, auth: auth)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSitter) { SitterView(dog: dog) }
        .sheet(isPresented: $showShare) { ShareModal(dog: dog) }
        .sheet(isPresented: $showSitterLinks, onDismiss: { Task { await loadFeatureData() } }) {
            NavigationStack { SitterLinksView(dog: dog) }
        }
        .sheet(isPresented: $showVisitHistory, onDismiss: {
            // Mark the latest visit as seen so the "New" badge clears for all users
            if let visit = latestVisit {
                let key = "seenVisitIds_\(dog.supabaseId ?? dog.id.uuidString)"
                var seen: Set<String>
                if let data = UserDefaults.standard.data(forKey: key),
                   let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                    seen = ids
                } else {
                    seen = []
                }
                seen.insert(visit.id)
                if let data = try? JSONEncoder().encode(seen) {
                    UserDefaults.standard.set(data, forKey: key)
                }
            }
            Task { await loadFeatureData() }
        }) {
            NavigationStack { VisitHistoryView(dog: dog) }
        }
        .sheet(isPresented: $showFamilyAccess, onDismiss: { Task { await loadFeatureData() } }) {
            NavigationStack { FamilyAccessView(dog: dog) }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showPaywall) { PaywallView(isPresented: $showPaywall) }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.jakarta(14, weight: .medium))
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
                await loadFeatureData()
            }
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Square anchor — sized first so clipped() operates on a
                // known square regardless of the original photo dimensions.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
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
                                        .font(.jakarta(60))
                                        .foregroundColor(.white.opacity(0.6))
                                )
                            }
                        }
                    )
                    .clipped()

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color(hex: "#1A1A1A").opacity(0.7), .clear],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(height: 120)
            }

            // Floating name card
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(dog.name)
                        .font(.jakarta(32, weight: .black))
                        .foregroundColor(.snootText1)
                        .tracking(-0.5)
                    
                    Spacer()
                    
                    if dog.isSample || dog.isShared {
                        Text(dog.isSample ? "Sample" : "Shared")
                            .font(.jakarta(12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.snootSage)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 12)

                Text("\(dog.breed) · \(dog.age) · \(Int(dog.weightLbs)) lbs\(dog.gender.isEmpty ? "" : " · \(dog.gender)")")
                    .font(.jakarta(15))
                    .foregroundColor(.snootText2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.bottom, 12)

                if !dog.personalityTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dog.personalityTags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.jakarta(14, weight: .medium))
                                    .foregroundColor(Color(hex: "#E8793A"))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Color(hex: "#FFF1EB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }

                if !dog.bio.isEmpty {
                    Text(dog.bio.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.jakarta(15))
                        .foregroundColor(.snootText2)
                        .lineLimit(bioExpanded ? nil : 3)
                        .onTapGesture { bioExpanded.toggle() }
                }

                Spacer(minLength: 26) // Guaranteed consistent bottom buffer
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .background(Color.snootCardBG)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .elevatedShadow()
            .padding(.horizontal, 16)
            .offset(y: -40)
            .padding(.bottom, -40)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Care profile grid
    private var careProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARE PROFILE")
                .font(.jakarta(12, weight: .bold))
                .foregroundColor(.snootOrange)
                .tracking(0.5)
                .padding(.leading, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(sectionData, id: \.title) { section in
                    CareCard(
                        icon: section.icon,
                        title: section.title,
                        summary: section.summary,
                        isComplete: section.isComplete,
                        minHeight: careCardHeight
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CareCardHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onTapGesture {
                        let ownerOnlyStep = dog.isShared && [1, 2, 3].contains(section.step)
                        editConfig = EditConfig(step: section.step, readOnly: !dog.canEdit || ownerOnlyStep)
                    }
                }
            }
            .onPreferenceChange(CareCardHeightKey.self) { value in
                if value > (careCardHeight ?? 0) {
                    careCardHeight = value
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
                subtitle: subscriptionService.isPro
                    ? (activeLinkCount == 0 ? "No active links" : "\(activeLinkCount) active link\(activeLinkCount == 1 ? "" : "s")")
                    : "Let your sitter log visits & get notified instantly",
                badge: subscriptionService.isPro ? nil : "PRO"
            ) {
                if subscriptionService.isPro { showSitterLinks = true }
                else { showPaywall = true }
            }

            ProfileFeatureRow(
                icon: "clock.badge.checkmark",
                iconColor: Color.snootSage,
                accentColor: Color.snootSage,
                title: "Visit log",
                subtitle: subscriptionService.isPro
                    ? (latestVisit.map { "Last: \($0.loggedByName) · \($0.visitedAtDate.formatted(.relative(presentation: .named)))" } ?? "No sitter visits yet")
                    : "Log visits manually · sitter logs with Pro",
                badge: latestVisitIsNew ? "New" : nil
            ) { showVisitHistory = true }

            ProfileFeatureRow(
                icon: "person.2.circle.fill",
                iconColor: Color.snootAmber,
                accentColor: Color.snootAmber,
                title: "Family access",
                subtitle: subscriptionService.isPro
                    ? (familyCount <= 1 ? "Only you" : "\(familyCount) people have access")
                    : "Invite family to view or edit",
                badge: subscriptionService.isPro ? nil : "PRO"
            ) {
                if subscriptionService.isPro { showFamilyAccess = true }
                else { showPaywall = true }
            }
        }
        .padding(.horizontal, 16)
    }

    private var syncButton: some View {
        Button { Task { await syncDog() } } label: {
            HStack(spacing: 12) {
                if isSyncing {
                    ProgressView().scaleEffect(0.9).tint(.snootOrange)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.jakarta(20))
                        .foregroundColor(.snootOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSyncing ? "Uploading profile…" : "Upload profile to enable sharing")
                        .font(.jakarta(15, weight: .semibold))
                        .foregroundColor(.snootText1)
                        .multilineTextAlignment(.leading)
                    Text("Enables sitter links, visit logs, and family access")
                        .font(.jakarta(13))
                        .foregroundColor(.snootText2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.snootText3).font(.jakarta(13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            // Preview is always available — no account needed
            Button { showSitter = true } label: {
                Label("Preview care guide", systemImage: "person.fill.questionmark")
                    .font(.jakarta(16, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.snootSage)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            }

            if auth.isAuthenticated {
                Button { showShare = true } label: {
                    Label("Export / share guide", systemImage: "doc.fill")
                        .font(.jakarta(16, weight: .heavy))
                        .foregroundColor(.snootOrange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.snootCardBG)
                        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                        .overlay(RoundedRectangle(cornerRadius: SnootRadius.medium).stroke(Color.snootOrange, lineWidth: 1.5))
                }

                Text("Sitters access care guides via a private link. No app needed.")
                    .font(.jakarta(12))
                    .foregroundColor(.snootText3)
                    .multilineTextAlignment(.center)
            } else {
                // Export locked — sign in required
                HStack(spacing: 10) {
                    lockedActionButton(label: "Export guide", icon: "doc.fill", color: Color.snootOrange)
                }

                Button { showAuth = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.jakarta(20))
                            .foregroundColor(.snootOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create a free account")
                                .font(.jakarta(15, weight: .heavy))
                                .foregroundColor(.snootText1)
                            Text("Export your guide, create sitter links, and invite family members with Pro.")
                                .font(.jakarta(12))
                                .foregroundColor(.snootText2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.jakarta(13))
                            .foregroundColor(.snootText3)
                    }
                    .padding(14)
                    .background(Color.snootCardBG)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
                    .cardShadow()
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func lockedActionButton(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.jakarta(14))
            Text(label).font(.jakarta(14, weight: .heavy))
            Image(systemName: "lock.fill").font(.jakarta(10))
        }
        .foregroundColor(color.opacity(0.45))
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .overlay(RoundedRectangle(cornerRadius: SnootRadius.medium).stroke(color.opacity(0.2), lineWidth: 1))
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
                toast("Profile uploaded. Sharing features unlocked!")
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

    private func healthSummary(for dog: Dog) -> String {
        let hasInput = !dog.vetName.isEmpty || !dog.medications.isEmpty
            || !dog.emergencyContact.isEmpty || dog.hasHealthConditions
        return hasInput ? "Input provided" : "Not filled in"
    }

    private func mealtimeSummary(for dog: Dog) -> String {
        guard dog.mealsPerDay > 0 else { return "Free feed" }
        var segments: [String] = []
        segments.append("\(dog.mealsPerDay) meal\(dog.mealsPerDay == 1 ? "" : "s")")
        let times = dog.mealTimesData.prefix(dog.mealsPerDay)
        if !times.isEmpty {
            segments.append(times.map { SitterView.timeFormatter.string(from: $0) }.joined(separator: ", "))
        }
        let portion = dog.portionSize.trimmingCharacters(in: .whitespaces)
        if !portion.isEmpty {
            segments.append("\(portion) \(dog.portionUnit)".trimmingCharacters(in: .whitespaces))
        }
        return segments.joined(separator: " · ")
    }

    var sectionData: [SectionInfo] {
        [
            .init(icon: "fork.knife", title: "Mealtime", step: 4,
                  isComplete: !dog.foodBrand.isEmpty || dog.mealsPerDay > 0,
                  summary: mealtimeSummary(for: dog)),
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
                  isComplete: !dog.vetName.isEmpty || !dog.medications.isEmpty || !dog.emergencyContact.isEmpty || dog.hasHealthConditions,
                  summary: healthSummary(for: dog)),
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
    var minHeight: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.jakarta(20))
                    .foregroundColor(Color.snootSage)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "#EBF4EA"))
                    .clipShape(Circle())
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.jakarta(18))
                        .foregroundColor(Color.snootSage)
                } else {
                    Circle()
                        .fill(Color.snootOrange)
                        .frame(width: 8, height: 8)
                }
            }
            Text(title)
                .font(.jakarta(14, weight: .heavy))
                .foregroundColor(.snootText1)
            Text(isComplete ? summary : "Tap to add")
                .font(.jakarta(12))
                .foregroundColor(isComplete ? .snootText2 : .snootOrange.opacity(0.8))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
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
                        .font(.jakarta(18))
                        .foregroundColor(iconColor)
                        .frame(width: 36, height: 36)
                        .background(iconColor.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.jakarta(15, weight: .heavy))
                            .foregroundColor(.snootText1)
                        Text(subtitle)
                            .font(.jakarta(13))
                            .foregroundColor(.snootText2)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let badge = badge {
                        Text(badge)
                            .font(.jakarta(11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.snootOrange)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.jakarta(13))
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

private struct CareCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
