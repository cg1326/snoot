import SwiftUI

struct ShareModal: View {
    let dog: Dog
    @State private var mode: ShareMode = .daytime
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isRenderingPDF = false
    @State private var isGeneratingLink = false
    @State private var isPDFShare = false
    @State private var exportError: String?
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    enum ShareMode: String, CaseIterable {
        case daytime = "Daytime"
        case overnight = "Overnight"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode picker
                    Picker("", selection: $mode) {
                        ForEach(ShareMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // What's included card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's included")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.snootText2)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            includedRow(icon: "fork.knife", label: "Mealtime",
                                detail: dog.mealsPerDay == 0 ? "Free feed" : "\(dog.mealsPerDay) meals/day")
                            Divider()
                            includedRow(icon: "figure.walk", label: "Walks",
                                detail: "\(dog.walksPerDay) walks · \(dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes)min")")
                            if !dog.medications.isEmpty {
                                Divider()
                                includedRow(icon: "pill", label: "Medications",
                                    detail: "\(dog.medications.count) listed")
                            }
                            if !dog.fearTriggers.isEmpty {
                                Divider()
                                includedRow(icon: "exclamationmark.triangle", label: "Heads up",
                                    detail: dog.fearTriggers.prefix(2).joined(separator: ", "))
                            }
                            Divider()
                            includedRow(icon: "phone.fill", label: "Emergency contacts",
                                detail: dog.emergencyContact.isEmpty ? "Vet info" : "Owner + vet")
                            if mode == .overnight {
                                Divider()
                                includedRow(icon: "moon.stars", label: "Bedtime",
                                    detail: dog.sleepLocation)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                    // Share via text message (Primary)
                    Button {
                        Task { await shareViaMessage() }
                    } label: {
                        Group {
                            if isGeneratingLink {
                                ProgressView().tint(.white)
                            } else {
                                Label(dog.canEdit ? "Share via text message" : "Sharing restricted", systemImage: "message.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(dog.canEdit ? Color.snootOrange : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(isGeneratingLink || !dog.canEdit)

                    // Send as PDF file (Secondary)
                    Button {
                        Task { await exportPDF() }
                    } label: {
                        Group {
                            if isRenderingPDF {
                                ProgressView().tint(.snootOrange)
                            } else {
                                Label("Send as PDF file", systemImage: "doc.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.snootOrange)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.snootOrange, lineWidth: 1.5))
                    }
                    .padding(.horizontal)
                    .disabled(isRenderingPDF)
                    .padding(.bottom, 32)
                }
                .padding(.top, 16)
            }
            .background(Color.snootCream.ignoresSafeArea())
            .navigationTitle("Share \(dog.name)'s guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(
                    items: shareItems,
                    excludedActivityTypes: isPDFShare
                        ? [UIActivity.ActivityType(rawValue: "com.apple.UIKit.activity.MarkupAsPDF")]
                        : []
                )
            }
            .alert("Export failed", isPresented: .init(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    // MARK: - Helpers

    private func includedRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.snootOrange)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.snootBrown)
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(.snootText2)
                .lineLimit(1)
        }
    }

    @MainActor
    private func shareViaMessage() async {
        guard let dogId = dog.supabaseId, auth.isAuthenticated, let uid = auth.currentUser?.id else {
            // Fallback to text if not synced
            shareItems = [buildMessageText()]
            isPDFShare = false
            showShareSheet = true
            return
        }

        isGeneratingLink = true
        defer { isGeneratingLink = false }

        do {
            let apiMode = mode == .overnight ? "overnight" : "daytime"
            let existingLinks = try await SyncService.shared.fetchSitterLinks(dogId: dogId)
            let activeLink = existingLinks.first { $0.mode == apiMode && $0.active }
            
            let link: SitterLink
            if let existing = activeLink {
                link = existing
            } else {
                link = try await SyncService.shared.createSitterLink(dogId: dogId, mode: apiMode, expiresAt: nil, createdBy: uid)
            }
            
            if let url = link.shareURL {
                shareItems = ["🐾 View \(dog.name)'s care guide: \(url.absoluteString)"]
                isPDFShare = false
                showShareSheet = true
            }
        } catch {
            exportError = "Failed to create link: \(error.localizedDescription)"
        }
    }

    // MARK: - PDF via ImageRenderer

    @MainActor
    private func exportPDF() async {
        isRenderingPDF = true
        defer { isRenderingPDF = false }

        let content = CareGuidePrintView(dog: dog, isOvernight: mode == .overnight)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return }

        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: image.size))
        let data = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(at: .zero)
        }

        let filename = "\(dog.name.replacingOccurrences(of: " ", with: "_"))_care_guide.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            exportError = error.localizedDescription
            return
        }
        shareItems = [url]
        isPDFShare = true
        showShareSheet = true
    }

    // MARK: - Message text (readable in iMessage / WhatsApp / email)

    private func buildMessageText() -> String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        var lines: [String] = []

        lines += ["🐾 \(dog.name)'s care guide"]
        lines += ["\(dog.breed)  ·  \(dog.age)  ·  \(Int(dog.weightLbs)) lbs"]
        lines += [""]

        // Feeding
        lines += ["🍖 FEEDING"]
        if dog.mealsPerDay == 0 {
            lines += ["Free feed throughout the day"]
        } else {
            let times = dog.mealTimesData.prefix(dog.mealsPerDay).map { fmt.string(from: $0) }.joined(separator: " & ")
            lines += ["\(dog.mealsPerDay) meal\(dog.mealsPerDay == 1 ? "" : "s")/day\(times.isEmpty ? "" : " — \(times)")"]
        }
        if !dog.portionSize.isEmpty {
            lines += ["\(dog.portionSize) \(dog.portionUnit) of \(dog.foodBrand.isEmpty ? "their food" : dog.foodBrand)"]
        }
        if !dog.foodAllergies.isEmpty {
            lines += ["⚠️ Avoid: \(dog.foodAllergies.joined(separator: ", "))"]
        }
        lines += ["Treats: \(dog.treatsPolicy.lowercased())"]
        lines += [""]

        // Walks
        lines += ["🦮 WALKS"]
        let walkTimes = dog.walkTimesData.prefix(dog.walksPerDay).map { fmt.string(from: $0) }.joined(separator: " & ")
        let dur = dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes)min"
        lines += ["\(dog.walksPerDay) walk\(dog.walksPerDay == 1 ? "" : "s")/day\(walkTimes.isEmpty ? "" : " — \(walkTimes)"), \(dur) each"]
        if !dog.leashBehaviours.isEmpty {
            lines += ["Leash: \(dog.leashBehaviours.joined(separator: ", "))"]
        }
        lines += [dog.offLeashTrusted ? "Off-leash: trusted ✓" : "Keep on leash at all times"]
        lines += [""]

        // Medications
        if !dog.medications.isEmpty {
            lines += ["💊 MEDICATIONS"]
            for m in dog.medications {
                lines += ["\(m.name) — \(m.dose), \(m.timing.lowercased()), \(m.method.lowercased())"]
            }
            lines += [""]
        }

        // Heads up
        if !dog.fearTriggers.isEmpty || (dog.separationAnxiety != "None" && dog.separationAnxiety != "none") {
            lines += ["⚠️ HEADS UP"]
            if !dog.fearTriggers.isEmpty {
                lines += ["Scared of: \(dog.fearTriggers.joined(separator: ", "))"]
            }
            if dog.separationAnxiety != "None" && dog.separationAnxiety != "none" {
                lines += ["Separation anxiety: \(dog.separationAnxiety.lowercased())"]
                if !dog.separationAnxietyNotes.isEmpty {
                    lines += ["What helps: \(dog.separationAnxietyNotes)"]
                }
            }
            if !dog.pottySignal.isEmpty {
                lines += ["Potty signal: \(dog.pottySignal)"]
            }
            lines += [""]
        }

        // Overnight
        if mode == .overnight {
            lines += ["🌙 BEDTIME"]
            lines += ["Sleeps: \(dog.sleepLocation)"]
            lines += ["Bedtime: \(fmt.string(from: dog.bedtimeDate))"]
            if !dog.bedtimeRoutine.isEmpty {
                lines += ["Routine: \(dog.bedtimeRoutine.joined(separator: ", "))"]
            }
            if !dog.nighttimeQuirks.isEmpty {
                lines += ["Quirks: \(dog.nighttimeQuirks)"]
            }
            lines += [""]
        }

        // Emergency contacts
        lines += ["📞 EMERGENCY CONTACTS"]
        if !dog.emergencyContact.isEmpty { lines += ["Owner: \(dog.emergencyContact)"] }
        if !dog.vetName.isEmpty || !dog.vetPhone.isEmpty {
            let vetParts = [dog.vetName, dog.vetClinic, dog.vetPhone].filter { !$0.isEmpty }
            lines += ["Vet: \(vetParts.joined(separator: " · "))"]
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Styled print view for PDF rendering

struct CareGuidePrintView: View {
    let dog: Dog
    let isOvernight: Bool

    private var fmt: DateFormatter {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                if let data = dog.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 64, height: 64).clipShape(Circle())
                } else {
                    Circle().fill(Color.snootOrange.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "pawprint.fill").foregroundColor(.snootOrange))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(dog.name)'s Care Guide")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.snootBrown)
                    Text("\(dog.breed)  ·  \(dog.age)  ·  \(Int(dog.weightLbs)) lbs")
                        .font(.system(size: 13))
                        .foregroundColor(.snootText2)
                    Text(isOvernight ? "Daytime + Overnight" : "Daytime care")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.snootSage)
                }
                Spacer()
            }
            .padding(20)
            .background(Color.white)

            Color.snootOrange.opacity(0.15).frame(height: 1)

            // Sections
            VStack(alignment: .leading, spacing: 12) {
                printSection(emoji: "🍖", title: "Mealtime") {
                    if dog.mealsPerDay == 0 {
                        printRow("Feeding", "Free feed all day")
                    } else {
                        printRow("Meals/day", "\(dog.mealsPerDay)")
                        ForEach(Array(dog.mealTimesData.prefix(dog.mealsPerDay).enumerated()), id: \.offset) { i, t in
                            printRow("Meal \(i+1)", fmt.string(from: t))
                        }
                    }
                    if !dog.portionSize.isEmpty { printRow("Portion", "\(dog.portionSize) \(dog.portionUnit)") }
                    if !dog.foodBrand.isEmpty { printRow("Food", dog.foodBrand) }
                    if !dog.foodAllergies.isEmpty { printRow("⚠️ Avoid", dog.foodAllergies.joined(separator: ", "), highlight: true) }
                    printRow("Treats", dog.treatsPolicy)
                }

                printSection(emoji: "🦮", title: "Walks") {
                    printRow("Walks/day", "\(dog.walksPerDay)")
                    ForEach(Array(dog.walkTimesData.prefix(dog.walksPerDay).enumerated()), id: \.offset) { i, t in
                        let dur = dog.walkDurationMinutes == 60 ? "1hr+" : "\(dog.walkDurationMinutes)min"
                        printRow("Walk \(i+1)", "\(fmt.string(from: t)) · \(dur)")
                    }
                    if !dog.leashBehaviours.isEmpty { printRow("Leash", dog.leashBehaviours.joined(separator: ", ")) }
                    printRow("Off-leash", dog.offLeashTrusted ? "Trusted ✓" : "Not trusted")
                }

                if !dog.medications.isEmpty {
                    printSection(emoji: "💊", title: "Medications") {
                        ForEach(dog.medications) { m in
                            printRow(m.name, "\(m.dose) · \(m.timing) · \(m.method)")
                        }
                    }
                }

                if !dog.fearTriggers.isEmpty || (dog.separationAnxiety != "None" && dog.separationAnxiety != "none") {
                    printSection(emoji: "⚠️", title: "Heads up") {
                        if !dog.fearTriggers.isEmpty { printRow("Fears", dog.fearTriggers.joined(separator: ", "), highlight: true) }
                        if dog.separationAnxiety != "None" && dog.separationAnxiety != "none" {
                            printRow("Separation", dog.separationAnxiety)
                            if !dog.separationAnxietyNotes.isEmpty { printRow("What helps", dog.separationAnxietyNotes) }
                        }
                        if !dog.pottySignal.isEmpty { printRow("Potty signal", dog.pottySignal) }
                    }
                }

                if isOvernight {
                    printSection(emoji: "🌙", title: "Bedtime") {
                        printRow("Sleeps", dog.sleepLocation)
                        printRow("Bedtime", fmt.string(from: dog.bedtimeDate))
                        if !dog.bedtimeRoutine.isEmpty { printRow("Routine", dog.bedtimeRoutine.joined(separator: ", ")) }
                        if !dog.nighttimeQuirks.isEmpty { printRow("Quirks", dog.nighttimeQuirks, highlight: true) }
                    }
                }

                printSection(emoji: "📞", title: "Emergency contacts") {
                    if !dog.emergencyContact.isEmpty { printRow("Owner", dog.emergencyContact) }
                    if !dog.vetName.isEmpty || !dog.vetPhone.isEmpty {
                        let parts = [dog.vetName, dog.vetClinic, dog.vetPhone].filter { !$0.isEmpty }
                        printRow("Vet", parts.joined(separator: " · "))
                    }
                    if dog.emergencyContact.isEmpty && dog.vetPhone.isEmpty {
                        Text("No contacts added").font(.system(size: 13)).foregroundColor(.snootText2)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 390)
        .background(Color(red: 0.99, green: 0.97, blue: 0.95))
    }

    @ViewBuilder
    private func printSection<Content: View>(emoji: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 13))
                Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.snootBrown)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func printRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.snootText2)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(highlight ? Color(red: 0.75, green: 0.15, blue: 0.1) : .snootBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType] = []

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
