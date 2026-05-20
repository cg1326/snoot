import SwiftUI
import SwiftData
import UserNotifications

struct VisitHistoryView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.modelContext) private var context
    @State private var visits: [VisitLog] = []
    @State private var manualVisits: [ManualVisit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogVisit = false
    @State private var showPaywall = false

    // Track which visit IDs are genuinely new this session, per dog
    @State private var newVisitIds: Set<String> = []
    @State private var seenIds: Set<String> = []
    @State private var archivedIds: Set<String> = []
    @State private var showArchived = false

    private var storageKey: String {
        "seenVisitIds_\(dog.supabaseId ?? dog.id.uuidString)"
    }
    private var archivedKey: String {
        "archivedVisitIds_\(dog.supabaseId ?? dog.id.uuidString)"
    }

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if manualVisits.isEmpty && visits.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // MARK: - Manual visits section (free, always shown)
                if !manualVisits.isEmpty || dog.canEdit {
                    Section {
                        if manualVisits.isEmpty {
                            Text("No logged visits yet. Tap + to log your first visit.")
                                .font(.jakarta(14))
                                .foregroundColor(.snootText2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(manualVisits) { visit in
                                ManualVisitRow(visit: visit)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if dog.canEdit {
                                            Button(role: .destructive) {
                                                deleteManualVisit(visit)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.04), radius: 4)
                                    )
                            }
                        }
                    } header: {
                        SectionHeader(title: "Logged visits")
                    }
                }

                // MARK: - Sitter visits section (Pro only)
                Section {
                    if subscriptionService.isPro && auth.isAuthenticated {
                        // Pro + authenticated: show sitter visits from Supabase
                        if visits.isEmpty {
                            Text("No sitter visits yet. Share a sitter link to get started.")
                                .font(.jakarta(14))
                                .foregroundColor(.snootText2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .listRowBackground(Color.clear)
                        } else {
                            // Archive toggle
                            Toggle(isOn: $showArchived) {
                                Label(showArchived ? "Showing archived" : "Hide archived",
                                      systemImage: showArchived ? "archivebox.fill" : "archivebox")
                                    .font(.jakarta(14, weight: .medium))
                            }
                            .tint(.snootOrange)
                            .listRowBackground(Color.white)

                            let filteredVisits = visits.filter {
                                showArchived ? archivedIds.contains($0.id) : !archivedIds.contains($0.id)
                            }

                            if filteredVisits.isEmpty {
                                Text(showArchived ? "No archived visits" : "No active visits")
                                    .font(.jakarta(14))
                                    .foregroundColor(.snootText2)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(filteredVisits) { visit in
                                    VisitRow(visit: visit, isNew: newVisitIds.contains(visit.id))
                                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if dog.canEdit {
                                                Button(role: .destructive) {
                                                    deleteVisit(visit)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                Button {
                                                    toggleArchive(visit)
                                                } label: {
                                                    Label(archivedIds.contains(visit.id) ? "Unarchive" : "Archive",
                                                          systemImage: archivedIds.contains(visit.id) ? "tray.and.arrow.up" : "archivebox")
                                                }
                                                .tint(.snootOrange)
                                            }
                                        }
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white)
                                                .shadow(color: .black.opacity(0.04), radius: 4)
                                        )
                                }
                            }
                        }
                    } else {
                        // Not Pro: show Pro gate callout
                        proGateCallout
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                } header: {
                    HStack {
                        SectionHeader(title: "Sitter visits")
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.snootCream.ignoresSafeArea())
        .navigationTitle("Visits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if dog.canEdit {
                    Button {
                        showLogVisit = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.snootOrange)
                            .font(.title2)
                    }
                }
            }
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showLogVisit, onDismiss: { loadManualVisits() }) {
            LogVisitView(dog: dog, isPresented: $showLogVisit)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        .task {
            loadSeenIds()
            loadArchivedIds()
            loadManualVisits()
            if subscriptionService.isPro && auth.isAuthenticated {
                await loadVisits()
                computeNewVisits()
                markAllSeen()
            }
        }
    }

    // MARK: - Empty state
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.jakarta(40))
                .foregroundColor(Color.snootSage.opacity(0.7))

            if !subscriptionService.isPro || !auth.isAuthenticated {
                Text("No visits yet")
                    .font(.jakarta(16, weight: .semibold))
                    .foregroundColor(Color.snootBrown)
                Text("No visits yet. Log your first visit below.")
                    .font(.jakarta(13))
                    .foregroundColor(.snootText2)
                    .multilineTextAlignment(.center)
                if dog.canEdit {
                    Button {
                        showLogVisit = true
                    } label: {
                        Text("Log a visit")
                            .font(.jakarta(15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.snootOrange)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No visits yet")
                    .font(.jakarta(16, weight: .semibold))
                    .foregroundColor(Color.snootBrown)
                Text("When a sitter logs a visit via your share link, it'll appear here.")
                    .font(.jakarta(13))
                    .foregroundColor(.snootText2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowBackground(Color.clear)
    }

    // MARK: - Pro gate callout
    private var proGateCallout: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.jakarta(28))
                    .foregroundColor(.snootOrange.opacity(0.8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sitter visit logs are a Snoot Pro feature")
                        .font(.jakarta(14, weight: .semibold))
                        .foregroundColor(.snootBrown)
                    Text("Get notified when your sitter logs a visit via your care guide link.")
                        .font(.jakarta(12))
                        .foregroundColor(.snootText2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.jakarta(14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.snootOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .cardShadow()
        .padding(.horizontal, 16)
    }

    // MARK: - Data loading
    private func loadManualVisits() {
        let dogId = dog.id
        let predicate = #Predicate<ManualVisit> { $0.dogLocalId == dogId }
        let descriptor = FetchDescriptor<ManualVisit>(
            predicate: predicate,
            sortBy: [.init(\.visitedAt, order: .reverse)]
        )
        manualVisits = (try? context.fetch(descriptor)) ?? []
    }

    private func loadVisits() async {
        guard let dogId = dog.supabaseId, auth.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            visits = try await SyncService.shared.fetchVisitLogs(dogId: dogId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSeenIds() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            seenIds = ids
        }
    }

    private func computeNewVisits() {
        newVisitIds = Set(visits.map(\.id)).subtracting(seenIds)
    }

    private func markAllSeen() {
        seenIds = seenIds.union(Set(visits.map(\.id)))
        if let data = try? JSONEncoder().encode(seenIds) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadArchivedIds() {
        if let data = UserDefaults.standard.data(forKey: archivedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            archivedIds = ids
        }
    }

    private func toggleArchive(_ visit: VisitLog) {
        if archivedIds.contains(visit.id) {
            archivedIds.remove(visit.id)
        } else {
            archivedIds.insert(visit.id)
        }
        if let data = try? JSONEncoder().encode(archivedIds) {
            UserDefaults.standard.set(data, forKey: archivedKey)
        }
    }

    private func deleteVisit(_ visit: VisitLog) {
        Task {
            do {
                try await SyncService.shared.deleteVisitLog(id: visit.id)
                await MainActor.run {
                    visits.removeAll { $0.id == visit.id }
                    archivedIds.remove(visit.id)
                    if let data = try? JSONEncoder().encode(archivedIds) {
                        UserDefaults.standard.set(data, forKey: archivedKey)
                    }
                }
            } catch {
                errorMessage = "Failed to delete visit: \(error.localizedDescription)"
            }
        }
    }

    private func deleteManualVisit(_ visit: ManualVisit) {
        context.delete(visit)
        try? context.save()
        loadManualVisits()
    }
}

// MARK: - Manual visit row
struct ManualVisitRow: View {
    let visit: ManualVisit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.snootSage)
                    Text(visit.loggedByName.isEmpty ? "Me" : visit.loggedByName)
                        .font(.jakarta(16, weight: .semibold))
                        .foregroundColor(Color.snootBrown)
                }
                Spacer()
                Text("Manual")
                    .font(.jakarta(11, weight: .semibold))
                    .foregroundColor(.snootText2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.snootText2.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(visit.visitedAt.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.jakarta(13))
                .foregroundColor(.snootText2)

            HStack(spacing: 12) {
                activityPill(icon: "fork.knife", label: visit.fed ? "Fed" : "Not fed", active: visit.fed)
                if visit.walked {
                    let dur = visit.walkDurationMins == 60 ? "1hr+" : "\(visit.walkDurationMins)min"
                    activityPill(icon: "figure.walk", label: "Walked \(dur)", active: true)
                } else {
                    activityPill(icon: "figure.walk", label: "Not walked", active: false)
                }
            }

            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.jakarta(14))
                    .foregroundColor(Color.snootBrown.opacity(0.8))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.snootCream)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }

    private func activityPill(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.jakarta(11))
            Text(label).font(.jakarta(12, weight: .semibold))
        }
        .foregroundColor(active ? Color(hex: "#3A7A37") : Color.snootText2)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background((active ? Color.snootSage : Color.snootText2).opacity(0.13))
        .clipShape(Capsule())
    }
}

// MARK: - Sitter visit row (unchanged)
struct VisitRow: View {
    let visit: VisitLog
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.snootOrange)
                    Text(visit.loggedByName)
                        .font(.jakarta(16, weight: .semibold))
                        .foregroundColor(Color.snootBrown)
                }
                Spacer()
                if isNew {
                    Text("New")
                        .font(.jakarta(11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.snootOrange)
                        .clipShape(Capsule())
                }
            }

            Text(visit.visitedAtDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.jakarta(13))
                .foregroundColor(.snootText2)

            HStack(spacing: 12) {
                activityPill(icon: "fork.knife", label: visit.fed ? "Fed" : "Not fed", active: visit.fed)
                if visit.walked {
                    let dur = visit.walkDurationMins.map { $0 == 60 ? "1hr+" : "\($0)min" } ?? ""
                    activityPill(icon: "figure.walk", label: "Walked \(dur)".trimmingCharacters(in: .whitespaces), active: true)
                } else {
                    activityPill(icon: "figure.walk", label: "Not walked", active: false)
                }
            }

            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.jakarta(14))
                    .foregroundColor(Color.snootBrown.opacity(0.8))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.snootCream)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }

    private func activityPill(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.jakarta(11))
            Text(label).font(.jakarta(12, weight: .semibold))
        }
        .foregroundColor(active ? Color(hex: "#3A7A37") : Color.snootText2)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background((active ? Color.snootSage : Color.snootText2).opacity(0.13))
        .clipShape(Capsule())
    }
}

// MARK: - Notification helpers
extension VisitHistoryView {
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func scheduleVisitNotification(sitterName: String, dogName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(sitterName) just logged a visit"
        content.body = "\(dogName) is in good hands."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
