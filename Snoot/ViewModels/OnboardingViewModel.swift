import SwiftUI
import SwiftData
import PhotosUI
import Observation

@Observable
class OnboardingViewModel {
    var currentStep: Int = 1
    let totalSteps: Int = 8

    // Step 1
    var name: String = ""
    var breed: String = "Labrador Retriever"
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    var weightLbs: Double = 35
    var photoData: Data? = nil
    var selectedPhoto: PhotosPickerItem? = nil

    // Step 2
    var personalityTags: Set<String> = []
    var customPersonalityTag: String = ""

    // Step 3
    var bio: String = ""

    // Step 4
    var mealsPerDay: Int = 2  // 0 = free feed
    var mealTimes: [Date] = [
        Calendar.current.date(from: DateComponents(hour: 7,  minute: 0)) ?? Date(),
        Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    ]
    var portionSize: String = ""
    var portionUnit: String = "cups"
    var foodBrand: String = ""
    var foodAllergies: [String] = []
    var newAllergyTag: String = ""
    var treatsPolicy: String = "Freely"

    // Step 5
    var walksPerDay: Int = 2
    var walkTimes: [Date] = [
        Calendar.current.date(from: DateComponents(hour: 8,  minute: 0))  ?? Date(),
        Calendar.current.date(from: DateComponents(hour: 17, minute: 30)) ?? Date()
    ]
    var walkDurationMinutes: Int = 30
    var leashBehaviours: Set<String> = []
    var offLeashTrusted: Bool = true
    var offLeashNotes: String = ""

    // Step 6
    var fearTriggers: Set<String> = []
    var customFearTag: String = ""
    var separationAnxiety: String = "None"
    var separationAnxietyNotes: String = ""
    var pottySignal: String = ""
    var comfortItems: String = ""

    // Step 7
    var hasHealthConditions: Bool = false
    var healthConditions: String = ""
    var medications: [MedEntry] = []
    var warningSigns: String = ""
    var vetName: String = ""
    var vetClinic: String = ""
    var vetPhone: String = ""
    var emergencyContact: String = ""

    // Step 8
    var sleepLocation: String = "Dog bed"
    var bedtimeDate: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var bedtimeRoutine: Set<String> = []
    var customBedtimeTag: String = ""
    var nighttimeQuirks: String = ""

    struct MedEntry: Identifiable {
        var id = UUID()
        var name: String = ""
        var dose: String = ""
        var timing: String = "Morning"
        var method: String = "With food"
    }

    func load(from dog: Dog) {
        name = dog.name
        breed = dog.breed
        dateOfBirth = dog.dateOfBirth
        weightLbs = dog.weightLbs
        photoData = dog.photoData
        personalityTags = Set(dog.personalityTags)
        bio = dog.bio
        mealsPerDay = dog.mealsPerDay
        mealTimes = dog.mealTimesData.isEmpty ? mealTimes : dog.mealTimesData
        portionSize = dog.portionSize
        portionUnit = dog.portionUnit
        foodBrand = dog.foodBrand
        foodAllergies = dog.foodAllergies
        treatsPolicy = dog.treatsPolicy
        walksPerDay = dog.walksPerDay
        walkTimes = dog.walkTimesData.isEmpty ? walkTimes : dog.walkTimesData
        walkDurationMinutes = dog.walkDurationMinutes
        leashBehaviours = Set(dog.leashBehaviours)
        offLeashTrusted = dog.offLeashTrusted
        offLeashNotes = dog.offLeashNotes
        fearTriggers = Set(dog.fearTriggers)
        separationAnxiety = dog.separationAnxiety
        separationAnxietyNotes = dog.separationAnxietyNotes
        pottySignal = dog.pottySignal
        comfortItems = dog.comfortItems
        hasHealthConditions = dog.hasHealthConditions
        healthConditions = dog.healthConditions
        medications = dog.medications.map { MedEntry(name: $0.name, dose: $0.dose, timing: $0.timing, method: $0.method) }
        warningSigns = dog.warningSigns
        vetName = dog.vetName
        vetClinic = dog.vetClinic
        vetPhone = dog.vetPhone
        emergencyContact = dog.emergencyContact
        sleepLocation = dog.sleepLocation
        bedtimeDate = dog.bedtimeDate
        bedtimeRoutine = Set(dog.bedtimeRoutine)
        nighttimeQuirks = dog.nighttimeQuirks
    }

    func applyEdits(to dog: Dog, context: ModelContext) {
        dog.name = name
        dog.breed = breed
        dog.dateOfBirth = dateOfBirth
        dog.weightLbs = weightLbs
        dog.photoData = photoData
        dog.personalityTags = Array(personalityTags)
        dog.bio = bio
        dog.mealsPerDay = mealsPerDay
        dog.mealTimesData = mealsPerDay == 0 ? [] : Array(mealTimes.prefix(mealsPerDay))
        dog.portionSize = portionSize
        dog.portionUnit = portionUnit
        dog.foodBrand = foodBrand
        dog.foodAllergies = foodAllergies
        dog.treatsPolicy = treatsPolicy
        dog.walksPerDay = walksPerDay
        dog.walkTimesData = Array(walkTimes.prefix(walksPerDay))
        dog.walkDurationMinutes = walkDurationMinutes
        dog.leashBehaviours = Array(leashBehaviours)
        dog.offLeashTrusted = offLeashTrusted
        dog.offLeashNotes = offLeashNotes
        dog.fearTriggers = Array(fearTriggers)
        dog.separationAnxiety = separationAnxiety
        dog.separationAnxietyNotes = separationAnxietyNotes
        dog.pottySignal = pottySignal
        dog.comfortItems = comfortItems
        dog.hasHealthConditions = hasHealthConditions
        dog.healthConditions = healthConditions
        dog.warningSigns = warningSigns
        dog.vetName = vetName
        dog.vetClinic = vetClinic
        dog.vetPhone = vetPhone
        dog.emergencyContact = emergencyContact
        dog.sleepLocation = sleepLocation
        dog.bedtimeDate = bedtimeDate
        dog.bedtimeRoutine = Array(bedtimeRoutine)
        dog.nighttimeQuirks = nighttimeQuirks
        dog.isSample = false
        for m in dog.medications { context.delete(m) }
        dog.medications = []
        for entry in medications {
            let m = Medication(name: entry.name, dose: entry.dose, timing: entry.timing, method: entry.method)
            m.dog = dog
            context.insert(m)
            dog.medications.append(m)
        }
        try? context.save()
    }

    func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentStep < totalSteps {
                currentStep += 1
            }
        }
    }

    func skip() { advance() }

    func ensureMealTimesCount() {
        let target = mealsPerDay == 0 ? 0 : mealsPerDay
        while mealTimes.count < target {
            mealTimes.append(Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? Date())
        }
    }

    func ensureWalkTimesCount() {
        while walkTimes.count < walksPerDay {
            walkTimes.append(Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? Date())
        }
    }

    func saveDog(context: ModelContext, auth: AuthService? = nil) -> Dog {
        let dog = Dog(name: name)
        dog.breed = breed
        dog.dateOfBirth = dateOfBirth
        dog.weightLbs = weightLbs
        dog.photoData = photoData
        dog.personalityTags = Array(personalityTags)
        dog.bio = bio
        dog.mealsPerDay = mealsPerDay
        dog.mealTimesData = mealsPerDay == 0 ? [] : Array(mealTimes.prefix(mealsPerDay))
        dog.portionSize = portionSize
        dog.portionUnit = portionUnit
        dog.foodBrand = foodBrand
        dog.foodAllergies = foodAllergies
        dog.treatsPolicy = treatsPolicy
        dog.walksPerDay = walksPerDay
        dog.walkTimesData = Array(walkTimes.prefix(walksPerDay))
        dog.walkDurationMinutes = walkDurationMinutes
        dog.leashBehaviours = Array(leashBehaviours)
        dog.offLeashTrusted = offLeashTrusted
        dog.offLeashNotes = offLeashNotes
        dog.fearTriggers = Array(fearTriggers)
        dog.separationAnxiety = separationAnxiety
        dog.separationAnxietyNotes = separationAnxietyNotes
        dog.pottySignal = pottySignal
        dog.comfortItems = comfortItems
        dog.hasHealthConditions = hasHealthConditions
        dog.healthConditions = healthConditions
        dog.warningSigns = warningSigns
        dog.vetName = vetName
        dog.vetClinic = vetClinic
        dog.vetPhone = vetPhone
        dog.emergencyContact = emergencyContact
        dog.sleepLocation = sleepLocation
        dog.bedtimeDate = bedtimeDate
        dog.bedtimeRoutine = Array(bedtimeRoutine)
        dog.nighttimeQuirks = nighttimeQuirks
        dog.onboardingComplete = true
        context.insert(dog)
        for entry in medications {
            let m = Medication(name: entry.name, dose: entry.dose, timing: entry.timing, method: entry.method)
            m.dog = dog
            context.insert(m)
            dog.medications.append(m)
        }
        return dog
    }
}
