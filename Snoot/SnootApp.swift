import SwiftUI
import SwiftData
import UserNotifications

@main
struct SnootApp: App {
    let container: ModelContainer
    @State private var authService = AuthService()
    @State private var networkMonitor = NetworkMonitor.shared

    init() {
        do {
            container = try ModelContainer(for: Dog.self, Medication.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environment(authService)
                .environment(networkMonitor)
                .task {
                    await SampleData.seedIfNeeded(context: container.mainContext)
                    // Background sync on launch
                    await SyncService.shared.syncOnLaunch(
                        context: container.mainContext,
                        auth: authService
                    )
                }
                .onAppear {
                    // Request notification permission on first launch
                    VisitHistoryView.requestNotificationPermission()
                }
        }
        .modelContainer(container)
    }
}

// MARK: - Sample data
enum SampleData {
    @MainActor
    static func seedIfNeeded(context: ModelContext) async {
        let descriptor = FetchDescriptor<Dog>()
        guard (try? context.fetch(descriptor))?.isEmpty == true else { return }

        let biscuit = Dog(name: "Biscuit")
        biscuit.breed = "Golden Retriever"
        biscuit.dateOfBirth = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 12)) ?? Date()
        biscuit.weightLbs = 68
        biscuit.personalityTags = ["Energetic","Cuddly","Foodie","Good with kids","Loves fetch"]
        biscuit.bio = "Hi! I'm Biscuit. I take my snack schedule very seriously and consider fetch a spiritual practice. I require at least three belly rubs before 9am."
        biscuit.mealsPerDay = 2
        biscuit.mealTimesData = [
            Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
            Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
        ]
        biscuit.portionSize = "1.5"
        biscuit.portionUnit = "cups"
        biscuit.foodBrand = "Royal Canin Adult Golden Retriever"
        biscuit.foodAllergies = ["Chicken by-product"]
        biscuit.treatsPolicy = "Freely"
        biscuit.walksPerDay = 2
        biscuit.walkTimesData = [
            Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(),
            Calendar.current.date(from: DateComponents(hour: 17, minute: 30)) ?? Date()
        ]
        biscuit.walkDurationMinutes = 30
        biscuit.leashBehaviours = ["Sniff-obsessed","Pulls a lot"]
        biscuit.offLeashTrusted = false
        biscuit.offLeashNotes = "Will sprint after squirrels with zero remorse"
        biscuit.fearTriggers = ["Thunderstorms","Fireworks","Vacuums"]
        biscuit.separationAnxiety = "Mild"
        biscuit.separationAnxietyNotes = "Leave the TV on – he likes nature documentaries"
        biscuit.pottySignal = "Goes to the back door and does a little spin"
        biscuit.comfortItems = "His orange duck toy and the worn blue blanket"
        biscuit.hasHealthConditions = false
        biscuit.vetName = "Dr. Sarah Chen"
        biscuit.vetClinic = "Paws & Claws Animal Hospital"
        biscuit.vetPhone = "(555) 234-5678"
        biscuit.emergencyContact = "(555) 867-5309"
        biscuit.sleepLocation = "Owner's bed"
        biscuit.bedtimeDate = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        biscuit.bedtimeRoutine = ["Last walk first","Gets a treat at bedtime"]
        biscuit.nighttimeQuirks = "Starts at the foot of the bed, migrates to the pillow by 3am"
        biscuit.onboardingComplete = true
        biscuit.isSample = true

        context.insert(biscuit)

        let med = Medication(name: "Omega-3 supplement", dose: "1 capsule", timing: "Morning", method: "With food")
        med.dog = biscuit
        context.insert(med)
        biscuit.medications.append(med)

        try? context.save()
    }
}
