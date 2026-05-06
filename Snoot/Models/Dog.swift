import SwiftData
import Foundation

@Model
class Dog {
    var id: UUID = UUID()
    var name: String = ""
    var breed: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    var weightLbs: Double = 25.0
    var photoData: Data? = nil
    var createdAt: Date = Date()

    // Personality
    var personalityTags: [String] = []
    var bio: String = ""

    // Feeding
    var mealsPerDay: Int = 2
    var mealTimesData: [Date] = []
    var portionSize: String = ""
    var portionUnit: String = "cups"
    var foodBrand: String = ""
    var foodAllergies: [String] = []
    var treatsPolicy: String = "freely"

    // Walks
    var walksPerDay: Int = 2
    var walkTimesData: [Date] = []
    var walkDurationMinutes: Int = 30
    var leashBehaviours: [String] = []
    var offLeashTrusted: Bool = true
    var offLeashNotes: String = ""

    // Behaviour
    var fearTriggers: [String] = []
    var separationAnxiety: String = "none"
    var separationAnxietyNotes: String = ""
    var pottySignal: String = ""
    var comfortItems: String = ""

    // Health
    var hasHealthConditions: Bool = false
    var healthConditions: String = ""
    @Relationship(deleteRule: .cascade) var medications: [Medication] = []
    var warningSigns: String = ""
    var vetName: String = ""
    var vetClinic: String = ""
    var vetPhone: String = ""
    var emergencyContact: String = ""

    // Bedtime
    var sleepLocation: String = "Dog bed"
    var bedtimeDate: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var bedtimeRoutine: [String] = []
    var nighttimeQuirks: String = ""

    var onboardingComplete: Bool = false
    var isSample: Bool = false

    // Supabase sync
    var supabaseId: String? = nil
    var photoUrl: String? = nil            // remote photo URL (Supabase Storage)
    var supabasePhotoUploaded: Bool = false
    var isShared: Bool = false             // true = came from dog_owners, not owned
    var sharedRole: String? = nil          // "owner" | "editor" | "viewer"
    var lastSyncedAt: Date? = nil
    
    var canEdit: Bool {
        // If not shared, you are the owner. 
        // If shared, you must have 'owner' or 'editor' role.
        if !isShared { return true }
        return sharedRole == "owner" || sharedRole == "editor"
    }

    // Computed
    var age: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: dateOfBirth, to: Date())
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        if y == 0 { return "\(m)mo" }
        if m == 0 { return "\(y)yr" }
        return "\(y)yr \(m)mo"
    }

    init(name: String = "") {
        self.name = name
        self.id = UUID()
        self.createdAt = Date()
    }
}
