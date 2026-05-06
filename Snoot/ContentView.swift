import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth
    @Environment(NetworkMonitor.self) private var network
    @Query(sort: \Dog.createdAt) private var dogs: [Dog]
    @State private var showOnboarding = false
    @State private var selectedDog: Dog? = nil
    @State private var dogToDelete: Dog? = nil
    @State private var showAuth = false
    @State private var showSettings = false
    @State private var fabPressed = false

    var body: some View {
        NavigationStack {
            Group {
                if dogs.isEmpty {
                    EmptyStateView { showOnboarding = true }
                } else {
                    dogListView
                }
            }
            .navigationTitle("My Dogs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
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
                            .font(.system(size: 22, weight: .bold))
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
                selectedDog = dog
                Task {
                    if auth.isAuthenticated {
                        try? await SyncService.shared.pushDog(dog, auth: auth)
                        await SyncService.shared.uploadPhotoIfNeeded(dog: dog, auth: auth)
                    }
                }
            }
        }
        .sheet(item: $selectedDog) { dog in
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
        .alert("Remove \(dogToDelete?.name ?? "dog")?", isPresented: .init(
            get: { dogToDelete != nil },
            set: { if !$0 { dogToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let d = dogToDelete { context.delete(d) }
                dogToDelete = nil
            }
            Button("Cancel", role: .cancel) { dogToDelete = nil }
        } message: {
            Text("This will permanently delete the profile.")
        }
    }

    private var dogListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !network.isConnected {
                    OfflineBanner()
                        .padding(.top, 12)
                        .transition(.move(edge: .top))
                }
                if !auth.isAuthenticated {
                    AccountPromptBanner(showAuth: $showAuth)
                        .padding(.top, 12)
                }
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(dogs) { dog in
                        DogCard(dog: dog)
                            .onTapGesture { selectedDog = dog }
                            .contextMenu {
                                Button(role: .destructive) { dogToDelete = dog } label: {
                                    Label("Delete profile", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(16)
            }
        }
        .background(Color.snootCream.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: network.isConnected)
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
        if !dog.vetName.isEmpty || !dog.medications.isEmpty { completed += 1 }
        if !dog.bedtimeRoutine.isEmpty || !dog.nighttimeQuirks.isEmpty { completed += 1 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo or gradient fallback
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
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.8))
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

            // Name + breed bottom-left
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("\(dog.breed) · \(dog.age)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.0, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
        .cardShadow()
        .overlay(alignment: .topLeading) {
            // Sample / shared badge
            if dog.isSample || dog.isShared {
                Text(dog.isSample ? "Sample" : "Shared")
                    .font(.system(size: 10, weight: .bold))
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

// MARK: - Empty state
struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 80))
                .foregroundColor(.snootOrange)
            VStack(spacing: 8) {
                Text("Add your first pup")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.snootText1)
                Text("Build a care guide your sitter will actually use")
                    .font(.system(size: 16))
                    .foregroundColor(.snootText2)
                    .multilineTextAlignment(.center)
            }
            Button(action: onAdd) {
                Label("Add your first dog", systemImage: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 56)
                    .background(Color.snootOrange)
                    .clipShape(RoundedRectangle(cornerRadius: SnootRadius.medium))
            }
            Spacer()
        }
        .padding()
        .background(Color.snootCream.ignoresSafeArea())
    }
}
