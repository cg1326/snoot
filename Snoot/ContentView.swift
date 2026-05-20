import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth
    @Environment(NetworkMonitor.self) private var network
    @Query(sort: \Dog.sortOrder) private var dogs: [Dog]
    @State private var showOnboarding = false
    @State private var selectedDog: Dog? = nil
    @State private var dogToDelete: Dog? = nil
    @State private var showAuth = false
    @State private var showSettings = false
    @State private var fabPressed = false
    @State private var pendingSignOutCleanup = false
    @State private var draggingId: UUID? = nil
    @State private var draggingOffset: CGFloat = 0
    @State private var hideDogsForSignOut = false

    var body: some View {
        NavigationStack {
            Group {
                if hideDogsForSignOut {
                    Color.snootCream.ignoresSafeArea()
                } else {
                    dogListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.jakarta(20))
                            .foregroundColor(.snootBrown)
                    }
                }
            }
            .background(Color.snootCream.ignoresSafeArea())
        }
        .safeAreaInset(edge: .bottom) {
            if !dogs.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            fabPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            fabPressed = false
                            showOnboarding = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.jakarta(22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.snootOrange)
                            .clipShape(Circle())
                            .shadow(color: Color.snootOrange.opacity(0.45), radius: 12, x: 0, y: 8)
                            .scaleEffect(fabPressed ? 0.93 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView { dog in
                showOnboarding = false
                // Place new dog after all existing ones
                let maxOrder = dogs.filter { $0.id != dog.id }.map(\.sortOrder).max() ?? -1
                dog.sortOrder = maxOrder + 1
                selectedDog = dog
                Task {
                    if auth.isAuthenticated {
                        try? await SyncService.shared.pushDog(dog, auth: auth)
                        await SyncService.shared.uploadPhotoIfNeeded(dog: dog, auth: auth)
                    }
                }
            }
        }
        .task { createSampleDogIfNeeded() }
        .sheet(item: $selectedDog, onDismiss: {
            if pendingSignOutCleanup {
                pendingSignOutCleanup = false
                performSignOutCleanup()
            }
        }) { dog in
            NavigationStack {
                ProfileHomeView(dog: dog)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selectedDog = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .onChange(of: auth.isAuthenticated) { _, isAuthed in
            if isAuthed {
                Task { await SyncService.shared.syncOnLaunch(context: context, auth: auth) }
            } else {
                draggingId = nil
                draggingOffset = 0
                dogToDelete = nil
                if selectedDog != nil {
                    // Sheet is open — wait for full dismissal before deleting,
                    // otherwise @Bindable dog ref in ProfileHomeView causes a crash.
                    selectedDog = nil
                    pendingSignOutCleanup = true
                } else {
                    // No sheet — hide the ForEach first so SwiftUI removes all dog
                    // view references, then delete on the next run-loop tick.
                    hideDogsForSignOut = true
                    DispatchQueue.main.async {
                        performSignOutCleanup()
                        hideDogsForSignOut = false
                    }
                }
            }
        }
        .alert("Remove \(dogToDelete?.name ?? "dog")?", isPresented: .init(
            get: { dogToDelete != nil },
            set: { if !$0 { dogToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let d = dogToDelete {
                    let sid = d.supabaseId
                    context.delete(d)
                    if let id = sid {
                        Task { await SyncService.shared.deleteDog(id: id) }
                    }
                }
                dogToDelete = nil
            }
            Button("Cancel", role: .cancel) { dogToDelete = nil }
        } message: {
            Text("This will permanently delete the profile.")
        }
    }

    private func moveDogs(from: IndexSet, to: Int) {
        var reordered = Array(dogs)
        reordered.move(fromOffsets: from, toOffset: to)
        for (index, dog) in reordered.enumerated() {
            dog.sortOrder = index
        }
        try? context.save()
    }

    private func performSignOutCleanup() {
        let allDogs = (try? context.fetch(FetchDescriptor<Dog>())) ?? []
        for dog in allDogs where dog.supabaseId != nil {
            context.delete(dog)
        }
        try? context.save()
        createSampleDogIfNeeded()
    }

    private func createSampleDogIfNeeded() {
        let remaining = (try? context.fetch(FetchDescriptor<Dog>())) ?? []
        guard remaining.isEmpty else { return }
        let sample = Dog(name: "Biscuit")
        sample.breed = "Golden Retriever"
        sample.gender = "Male"
        sample.dateOfBirth = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        sample.weightLbs = 25
        sample.personalityTags = ["Playful", "Friendly", "Energetic"]
        sample.bio = "Loves fetch, belly rubs, and stealing socks. Best dog ever."
        sample.foodBrand = "Purina Pro Plan"
        sample.mealsPerDay = 2
        sample.walkDurationMinutes = 30
        sample.walksPerDay = 2
        sample.sleepLocation = "Dog bed"
        sample.photoData = UIImage(named: "puppy").flatMap { $0.jpegData(compressionQuality: 0.8) }
        sample.isSample = true
        sample.supabaseId = nil
        sample.sortOrder = 0
        context.insert(sample)
        try? context.save()
    }

    private var dogListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed title — sits outside the scroll view so it doesn't scroll
            Text("My Dogs")
                .font(.jakarta(40, weight: .black))
                .foregroundColor(.snootText1)
                .tracking(-1.0)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)
                .background(Color.snootCream)

            ScrollView {
                VStack(spacing: 0) {
                    if !network.isConnected {
                        OfflineBanner()
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.move(edge: .top))
                    }
                    if !auth.isAuthenticated {
                        AccountPromptBanner(showAuth: $showAuth)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    ForEach(dogs) { dog in
                        let isDragging = draggingId == dog.id
                        DogCard(dog: dog)
                            .overlay(alignment: .trailing) {
                                // Drag handle — always visible, sits inside the card
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(14)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(
                                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                                .onChanged { value in
                                                    if draggingId == nil {
                                                        draggingId = dog.id
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    }
                                                    draggingOffset = value.translation.height
                                                    // Swap when the card passes 50% of the next card's height
                                                    let cardH = UIScreen.main.bounds.width - 16
                                                    guard let dId = draggingId,
                                                          let idx = dogs.firstIndex(where: { $0.id == dId })
                                                    else { return }
                                                    if draggingOffset > cardH * 0.5, idx < dogs.count - 1 {
                                                        moveDogs(from: IndexSet(integer: idx), to: idx + 2)
                                                        draggingOffset -= cardH
                                                    } else if draggingOffset < -cardH * 0.5, idx > 0 {
                                                        moveDogs(from: IndexSet(integer: idx), to: idx - 1)
                                                        draggingOffset += cardH
                                                    }
                                                }
                                                .onEnded { _ in
                                                    withAnimation(.spring(response: 0.3)) {
                                                        draggingId = nil
                                                        draggingOffset = 0
                                                    }
                                                }
                                        )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .offset(y: isDragging ? draggingOffset : 0)
                            .scaleEffect(isDragging ? 1.02 : 1.0)
                            .shadow(color: isDragging ? .black.opacity(0.15) : .clear, radius: 12, x: 0, y: 6)
                            .zIndex(isDragging ? 1 : 0)
                            .animation(.interactiveSpring(response: 0.3), value: isDragging)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDog = dog
                            }
                            .contextMenu {
                                Button(role: .destructive) { dogToDelete = dog } label: {
                                    Label("Delete profile", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDisabled(draggingId != nil)
            .background(Color.snootCream.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.2), value: network.isConnected)
            .task {
                // Assign sequential sortOrder on first launch (all default to 0)
                guard dogs.allSatisfy({ $0.sortOrder == 0 }), dogs.count > 1 else { return }
                for (i, dog) in dogs.enumerated() { dog.sortOrder = i }
                try? context.save()
            }
        }
        .background(Color.snootCream.ignoresSafeArea())
    }
}

// MARK: - Dog card (full redesign)
struct DogCard: View {
    let dog: Dog

    private var completionFraction: Double {
        var completed = 0
        let total = 6
        if !dog.foodBrand.isEmpty || dog.mealsPerDay > 0 { completed += 1 }
        if !dog.walkTimesData.isEmpty { completed += 1 }
        if !dog.personalityTags.isEmpty { completed += 1 }
        if !dog.fearTriggers.isEmpty || !dog.pottySignal.isEmpty { completed += 1 }
        if !dog.vetName.isEmpty || !dog.medications.isEmpty || !dog.emergencyContact.isEmpty || dog.hasHealthConditions { completed += 1 }
        if !dog.bedtimeRoutine.isEmpty || !dog.nighttimeQuirks.isEmpty { completed += 1 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Square anchor — sized first, image/gradient overlaid on top.
            // This ensures clipped() clips to a known square, not to the
            // image's natural dimensions.
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Group {
                        if let data = dog.photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [Color.snootOrange, Color(hex: "#F9A88B")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .overlay(
                                Image(systemName: "pawprint.fill")
                                    .font(.jakarta(48))
                                    .foregroundColor(.white.opacity(0.8))
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

            // Name + breed bottom-left
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(.jakarta(15, weight: .heavy))
                    .foregroundColor(.white)
                Text("\(dog.breed) · \(dog.age)\(dog.gender.isEmpty ? "" : " · \(dog.gender)")")
                    .font(.jakarta(11))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .cardShadow()
        .overlay(alignment: .topLeading) {
            // Sample / shared badge
            if dog.isSample || dog.isShared {
                Text(dog.isSample ? "Sample" : "Shared")
                    .font(.jakarta(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.snootSage)
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Completion arc
            if completionFraction < 1.0 {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: completionFraction)
                        .stroke(Color.snootOrange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)
                .padding(10)
            }
        }
    }
}

