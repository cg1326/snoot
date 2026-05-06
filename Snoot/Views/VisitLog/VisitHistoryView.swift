import SwiftUI
import UserNotifications

struct VisitHistoryView: View {
    let dog: Dog
    @Environment(AuthService.self) private var auth
    @State private var visits: [VisitLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
            } else if visits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color.snootSage.opacity(0.7))
                    Text("No visits yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.snootBrown)
                    Text("When a sitter logs a visit via your share link, it'll appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    Toggle(isOn: $showArchived) {
                        Label(showArchived ? "Showing archived" : "Hide archived", systemImage: showArchived ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .tint(.snootOrange)
                }
                .listRowBackground(Color.white)

                let filteredVisits = visits.filter { showArchived ? archivedIds.contains($0.id) : !archivedIds.contains($0.id) }

                if filteredVisits.isEmpty {
                    Text(showArchived ? "No archived visits" : "No active visits")
                        .font(.system(size: 14))
                        .foregroundColor(.snootText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredVisits) { visit in
                        Section {
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
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.04), radius: 4)
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.snootCream.ignoresSafeArea())
        .navigationTitle("Visit history")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadSeenIds()
            loadArchivedIds()
            await loadVisits()
            computeNewVisits()
            markAllSeen()
        }
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

    // Called after loadVisits(), before markAllSeen() — captures what's genuinely new
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
                    archivedIds.remove(visit.id) // Cleanup if it was archived
                    if let data = try? JSONEncoder().encode(archivedIds) {
                        UserDefaults.standard.set(data, forKey: archivedKey)
                    }
                }
            } catch {
                errorMessage = "Failed to delete visit: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Visit row
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.snootBrown)
                }
                Spacer()
                if isNew {
                    Text("New")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.snootOrange)
                        .clipShape(Capsule())
                }
            }

            Text(visit.visitedAtDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.system(size: 13))
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
                    .font(.system(size: 14))
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
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
