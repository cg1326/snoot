import Foundation
import SwiftData
import Supabase

// ─────────────────────────────────────────────────────────────
// SyncService: mirrors SwiftData ↔ Supabase.
// ─────────────────────────────────────────────────────────────
final class SyncService {
    static let shared = SyncService()
    var supabase: SupabaseClient { SupabaseService.shared.client }
    private let isoFull = ISO8601DateFormatter()
    private let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Upsert payload structs

    private struct DogUpsert: Encodable {
        let id: String?
        let ownerId: String
        let name: String
        let breed: String
        let dob: String?
        let weightLbs: Double
        let photoUrl: String?
        let bio: String

        enum CodingKeys: String, CodingKey {
            case id, name, breed, bio
            case ownerId  = "owner_id"
            case dob      = "dob"
            case weightLbs = "weight_lbs"
            case photoUrl = "photo_url"
        }
    }

    private struct CareProfileUpsert: Encodable {
        let dogId: String
        let section: String
        let data: CareData
        let updatedAt: String
        let updatedBy: String

        enum CodingKeys: String, CodingKey {
            case section, data
            case dogId     = "dog_id"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
        }
    }

    // MARK: - Full sync on launch
    @MainActor
    func syncOnLaunch(context: ModelContext, auth: AuthService) async {
        guard auth.isAuthenticated, let user = auth.currentUser else { return }
        let uid = user.id

        // Auto-accept any pending invitations for this user's email
        await acceptPendingInvites(user: user)

        async let ownedTask: [SupabaseDog] = fetchOwnedDogs(uid: uid)
        async let sharedTask: [(SupabaseDog, String)] = fetchSharedDogs(uid: uid)

        let (owned, shared): ([SupabaseDog], [(SupabaseDog, String)])
        do {
            (owned, shared) = try await (ownedTask, sharedTask)
        } catch { return }

        let existingDogs = (try? context.fetch(FetchDescriptor<Dog>())) ?? []
        let existingBySupabaseId = Dictionary(
            existingDogs.compactMap { d -> (String, Dog)? in
                guard let sid = d.supabaseId else { return nil }
                return (sid, d)
            }, uniquingKeysWith: { first, _ in first }
        )

        for remote in owned {
            let local = existingBySupabaseId[remote.id]
            updateOrInsert(remote: remote, existing: local, context: context, isShared: false, sharedRole: nil)
        }
        for (remote, role) in shared {
            let local = existingBySupabaseId[remote.id]
            updateOrInsert(remote: remote, existing: local, context: context, isShared: true, sharedRole: role)
        }
        _ = try? context.save()
    }

    // MARK: - Push a dog to Supabase
    @MainActor
    func pushDog(_ dog: Dog, auth: AuthService) async throws {
        guard auth.isAuthenticated, let uid = auth.currentUser?.id else { return }

        let payload = DogUpsert(
            id: dog.supabaseId,
            ownerId: uid,
            name: dog.name,
            breed: dog.breed,
            dob: isoDate.string(from: dog.dateOfBirth),
            weightLbs: dog.weightLbs,
            photoUrl: dog.photoUrl,
            bio: dog.bio
        )

        let serverDog: SupabaseDog = try await supabase
            .from("dogs")
            .upsert(payload, onConflict: "id")
            .select()
            .single()
            .execute()
            .value

        if dog.supabaseId == nil {
            dog.supabaseId = serverDog.id
            _ = try? dog.modelContext?.save()
        }

        await pushCareProfile(dog: dog, auth: auth)
    }

    // MARK: - Push care profile
    @MainActor
    func pushCareProfile(dog: Dog, auth: AuthService) async {
        guard let uid = auth.currentUser?.id, let dogId = dog.supabaseId else { return }
        let sections = buildCareRows(dog: dog, dogId: dogId, userId: uid)
        for section in sections {
            _ = try? await supabase
                .from("care_profile")
                .upsert(section, onConflict: "dog_id,section")
                .execute()
        }
    }

    // MARK: - Photo upload
    @MainActor
    func uploadPhotoIfNeeded(dog: Dog, auth: AuthService) async {
        guard auth.isAuthenticated,
              let photoData = dog.photoData,
              dog.supabasePhotoUploaded == false,
              let dogId = dog.supabaseId else { return }
        do {
            let url = try await SupabaseService.shared.uploadDogPhoto(data: photoData, dogId: dogId)
            dog.photoUrl = url
            dog.supabasePhotoUploaded = true
            _ = try? dog.modelContext?.save()
            struct PhotoUpdate: Encodable { let photoUrl: String; enum CodingKeys: String, CodingKey { case photoUrl = "photo_url" } }
            _ = try? await supabase
                .from("dogs")
                .update(PhotoUpdate(photoUrl: url))
                .eq("id", value: dogId)
                .execute()
        } catch { }
    }

    // MARK: - Sitter links
    func createSitterLink(dogId: String, mode: String, expiresAt: Date?, createdBy: String) async throws -> SitterLink {
        let payload = NewSitterLink(
            dogId: dogId,
            mode: mode,
            createdBy: createdBy,
            expiresAt: expiresAt.map { isoFull.string(from: $0) },
            active: true
        )
        return try await supabase
            .from("sitter_links")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchSitterLinks(dogId: String) async throws -> [SitterLink] {
        try await supabase
            .from("sitter_links")
            .select()
            .eq("dog_id", value: dogId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func deactivateSitterLink(id: String) async throws {
        struct Update: Encodable { let active: Bool }
        let updated: [SitterLink] = try await supabase
            .from("sitter_links")
            .update(Update(active: false))
            .eq("id", value: id)
            .select()
            .execute()
            .value
        if updated.isEmpty {
            throw NSError(domain: "SitterLink", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "You don't have permission to deactivate this link."
            ])
        }
    }

    // MARK: - Visit logs
    func fetchVisitLogs(dogId: String) async throws -> [VisitLog] {
        try await supabase
            .from("visit_logs")
            .select()
            .eq("dog_id", value: dogId)
            .order("visited_at", ascending: false)
            .execute()
            .value
    }

    func deleteVisitLog(id: String) async throws {
        try await supabase
            .from("visit_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Dog owners (family access)
    func fetchDogOwners(dogId: String) async throws -> [DogOwner] {
        // Intentionally no users join — fetching user profiles via a join can produce
        // a decode error if PostgREST returns the nested resource as an array vs object.
        // Callers that need user profiles should fetch them separately.
        try await supabase
            .from("dog_owners")
            .select("*")
            .eq("dog_id", value: dogId)
            .execute()
            .value
    }

    func fetchUserProfile(userId: String) async throws -> SupabaseUser {
        try await supabase
            .from("users")
            .select("id, email, display_name")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func inviteFamilyMember(dogId: String, email: String, role: String, createdBy: String) async throws {
        struct Payload: Encodable { let dogId: String; let email: String; let role: String }
        struct FnResult: Decodable { let success: Bool?; let error: String?; let log: [String]? }
        let session = try await supabase.auth.session
        let result: FnResult = try await supabase.functions.invoke(
            "invite-family",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: Payload(dogId: dogId, email: email, role: role)
            )
        )
        if let msg = result.error {
            let detail = result.log?.joined(separator: " → ") ?? ""
            throw NSError(domain: "InviteError", code: 0, userInfo: [NSLocalizedDescriptionKey: "\(msg)\n\(detail)"])
        }
    }

    func removeFamilyMember(ownerId: String) async throws {
        try await supabase
            .from("dog_owners")
            .delete()
            .eq("id", value: ownerId)
            .execute()
    }

    func updateFamilyRole(ownerId: String, role: String) async throws {
        struct Update: Encodable { let role: String }
        try await supabase
            .from("dog_owners")
            .update(Update(role: role))
            .eq("id", value: ownerId)
            .execute()
    }

    // MARK: - Private helpers

    func acceptPendingInvites(user: SupabaseUser) async {
        // Use a security-definer RPC to bypass RLS and accept all pending invites for the current user
        _ = try? await supabase
            .rpc("accept_pending_invites_for_me")
            .execute()
    }

    private func fetchOwnedDogs(uid: String) async throws -> [SupabaseDog] {
        try await supabase
            .from("dogs")
            .select()
            .eq("owner_id", value: uid)
            .execute()
            .value
    }

    private func fetchSharedDogs(uid: String) async throws -> [(SupabaseDog, String)] {
        struct Row: Decodable {
            let role: String
            let dogs: SupabaseDog
        }
        let rows: [Row] = try await supabase
            .from("dog_owners")
            .select("role, dogs(*)")
            .eq("user_id", value: uid)
            .eq("accepted", value: true)
            .execute()
            .value
        return rows.map { ($0.dogs, $0.role) }
    }

    @MainActor
    private func updateOrInsert(
        remote: SupabaseDog,
        existing: Dog?,
        context: ModelContext,
        isShared: Bool,
        sharedRole: String?
    ) {
        let dog = existing ?? {
            let d = Dog(name: remote.name)
            context.insert(d)
            return d
        }()
        dog.supabaseId = remote.id
        dog.name = remote.name
        dog.breed = remote.breed
        dog.bio = remote.bio
        if let w = remote.weightLbs { dog.weightLbs = w }
        if let url = remote.photoUrl { dog.photoUrl = url }
        if let dobStr = remote.dob, let date = isoDate.date(from: dobStr) {
            dog.dateOfBirth = date
        }
        dog.isShared = isShared
        dog.sharedRole = sharedRole
    }

    private func buildCareRows(dog: Dog, dogId: String, userId: String) -> [CareProfileUpsert] {
        let now = isoFull.string(from: Date())
        let fmt = ISO8601DateFormatter()
        func dateStr(_ d: Date) -> String { fmt.string(from: d) }

        return [
            CareProfileUpsert(dogId: dogId, section: "feeding", data: CareData(
                mealsPerDay: dog.mealsPerDay,
                mealTimesData: dog.mealTimesData.map { dateStr($0) },
                portionSize: dog.portionSize,
                portionUnit: dog.portionUnit,
                foodBrand: dog.foodBrand,
                foodAllergies: dog.foodAllergies,
                treatsPolicy: dog.treatsPolicy
            ), updatedAt: now, updatedBy: userId),

            CareProfileUpsert(dogId: dogId, section: "walks", data: CareData(
                walksPerDay: dog.walksPerDay,
                walkTimesData: dog.walkTimesData.map { dateStr($0) },
                walkDurationMinutes: dog.walkDurationMinutes,
                leashBehaviours: dog.leashBehaviours,
                offLeashTrusted: dog.offLeashTrusted,
                offLeashNotes: dog.offLeashNotes
            ), updatedAt: now, updatedBy: userId),

            CareProfileUpsert(dogId: dogId, section: "behaviour", data: CareData(
                fearTriggers: dog.fearTriggers,
                separationAnxiety: dog.separationAnxiety,
                separationAnxietyNotes: dog.separationAnxietyNotes,
                pottySignal: dog.pottySignal,
                comfortItems: dog.comfortItems
            ), updatedAt: now, updatedBy: userId),

            CareProfileUpsert(dogId: dogId, section: "health", data: CareData(
                hasHealthConditions: dog.hasHealthConditions,
                healthConditions: dog.healthConditions,
                medications: dog.medications.map { MedicationData(name: $0.name, dose: $0.dose, timing: $0.timing, method: $0.method) },
                warningSigns: dog.warningSigns,
                vetName: dog.vetName,
                vetClinic: dog.vetClinic,
                vetPhone: dog.vetPhone,
                emergencyContact: dog.emergencyContact
            ), updatedAt: now, updatedBy: userId),

            CareProfileUpsert(dogId: dogId, section: "bedtime", data: CareData(
                sleepLocation: dog.sleepLocation,
                bedtimeDate: dateStr(dog.bedtimeDate),
                bedtimeRoutine: dog.bedtimeRoutine,
                nighttimeQuirks: dog.nighttimeQuirks
            ), updatedAt: now, updatedBy: userId),
        ]
    }
}
