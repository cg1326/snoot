import Foundation

// ─────────────────────────────────────────────────────────────
// Codable structs mirroring the Supabase database schema.
// Used for encoding/decoding remote data.
// ─────────────────────────────────────────────────────────────

// MARK: - users
struct SupabaseUser: Codable, Identifiable {
    let id: String
    let email: String
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
    }
}

// MARK: - dogs
struct SupabaseDog: Codable, Identifiable {
    let id: String
    let ownerId: String
    var name: String
    var breed: String
    var dob: String?       // ISO date "YYYY-MM-DD"
    var weightLbs: Double?
    var gender: String?
    var personalityTags: [String]?
    var photoUrl: String?
    var bio: String
    let createdAt: String?
    let updatedAt: String?

    var user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case id, name, breed, dob, bio, gender
        case personalityTags = "personality_tags"
        case ownerId   = "owner_id"
        case weightLbs = "weight_lbs"
        case photoUrl  = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user      = "users"
    }
}

// MARK: - dog_owners
struct DogOwner: Codable, Identifiable {
    let id: String
    let dogId: String
    var userId: String?
    var role: String        // "owner" | "editor" | "viewer"
    var invitedEmail: String?
    var accepted: Bool
    let createdAt: String?
    var user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case id, role, accepted
        case dogId        = "dog_id"
        case userId       = "user_id"
        case invitedEmail = "invited_email"
        case createdAt    = "created_at"
        case user         = "users"
    }
}

// MARK: - care_profile
struct CareProfileRow: Codable, Identifiable {
    let id: String
    let dogId: String
    let section: String   // "feeding" | "walks" | "behaviour" | "health" | "bedtime"
    var data: CareData
    let updatedAt: String?
    var updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, section, data
        case dogId     = "dog_id"
        case updatedAt = "updated_at"
        case updatedBy = "updated_by"
    }
}

// MARK: - CareData (generic JSONB payload)
struct CareData: Codable {
    // Feeding
    var mealsPerDay: Int?
    var mealTimesData: [String]?
    var portionSize: String?
    var portionUnit: String?
    var foodBrand: String?
    var foodAllergies: [String]?
    var treatsPolicy: String?

    // Walks
    var walksPerDay: Int?
    var walkTimesData: [String]?
    var walkDurationMinutes: Int?
    var leashBehaviours: [String]?
    var offLeashTrusted: Bool?
    var offLeashNotes: String?

    // Behaviour
    var fearTriggers: [String]?
    var separationAnxiety: String?
    var separationAnxietyNotes: String?
    var pottySignal: String?
    var comfortItems: String?

    // Health
    var hasHealthConditions: Bool?
    var healthConditions: String?
    var medications: [MedicationData]?
    var warningSigns: String?
    var vetName: String?
    var vetClinic: String?
    var vetPhone: String?
    var emergencyContact: String?

    // Bedtime
    var sleepLocation: String?
    var bedtimeDate: String?
    var bedtimeRoutine: [String]?
    var nighttimeQuirks: String?

    enum CodingKeys: String, CodingKey {
        case mealsPerDay          = "meals_per_day"
        case mealTimesData        = "meal_times_data"
        case portionSize          = "portion_size"
        case portionUnit          = "portion_unit"
        case foodBrand            = "food_brand"
        case foodAllergies        = "food_allergies"
        case treatsPolicy         = "treats_policy"
        case walksPerDay          = "walks_per_day"
        case walkTimesData        = "walk_times_data"
        case walkDurationMinutes  = "walk_duration_minutes"
        case leashBehaviours      = "leash_behaviours"
        case offLeashTrusted      = "off_leash_trusted"
        case offLeashNotes        = "off_leash_notes"
        case fearTriggers         = "fear_triggers"
        case separationAnxiety    = "separation_anxiety"
        case separationAnxietyNotes = "separation_anxiety_notes"
        case pottySignal          = "potty_signal"
        case comfortItems         = "comfort_items"
        case hasHealthConditions  = "has_health_conditions"
        case healthConditions     = "health_conditions"
        case medications
        case warningSigns         = "warning_signs"
        case vetName              = "vet_name"
        case vetClinic            = "vet_clinic"
        case vetPhone             = "vet_phone"
        case emergencyContact     = "emergency_contact"
        case sleepLocation        = "sleep_location"
        case bedtimeDate          = "bedtime_date"
        case bedtimeRoutine       = "bedtime_routine"
        case nighttimeQuirks      = "nighttime_quirks"
    }
}

struct MedicationData: Codable {
    var name: String
    var dose: String
    var timing: String
    var method: String
}

// MARK: - sitter_links
struct SitterLink: Codable, Identifiable {
    let id: String
    let dogId: String
    let token: String
    var mode: String       // "daytime" | "overnight" | "both"
    let createdBy: String
    var expiresAt: String?
    var active: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, token, mode, active
        case dogId     = "dog_id"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }

    var shareURL: URL? {
        URL(string: "\(SupabaseConfig.sitterLinkBase)/\(token)")
    }

    var expiresAtDate: Date? {
        guard let str = expiresAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }
}

// MARK: - visit_logs
struct VisitLog: Codable, Identifiable {
    let id: String
    let dogId: String
    let sitterLinkId: String?
    let loggedByName: String
    let visitedAt: String
    let fed: Bool
    let walked: Bool
    let walkDurationMins: Int?
    let notes: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, fed, walked, notes
        case dogId          = "dog_id"
        case sitterLinkId   = "sitter_link_id"
        case loggedByName   = "logged_by_name"
        case visitedAt      = "visited_at"
        case walkDurationMins = "walk_duration_mins"
        case createdAt      = "created_at"
    }

    var visitedAtDate: Date {
        // Supabase returns timestamps like "2026-05-05T21:30:00+00:00" — try multiple formats
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: visitedAt) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: visitedAt) ?? Date()
    }
}

// MARK: - Insert payloads (no id / server defaults)
struct NewSitterLink: Encodable {
    let dogId: String
    let mode: String
    let createdBy: String
    let expiresAt: String?
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case mode, active
        case dogId     = "dog_id"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
    }
}

struct NewVisitLog: Encodable {
    let dogId: String
    let sitterLinkId: String
    let loggedByName: String
    let fed: Bool
    let walked: Bool
    let walkDurationMins: Int?
    let notes: String

    enum CodingKeys: String, CodingKey {
        case fed, walked, notes
        case dogId          = "dog_id"
        case sitterLinkId   = "sitter_link_id"
        case loggedByName   = "logged_by_name"
        case walkDurationMins = "walk_duration_mins"
    }
}
