import SwiftData
import Foundation

@Model
class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = ""
    var timing: String = "Morning"
    var method: String = "With food"
    var dog: Dog?

    init(name: String = "", dose: String = "", timing: String = "Morning", method: String = "With food") {
        self.id = UUID()
        self.name = name
        self.dose = dose
        self.timing = timing
        self.method = method
    }
}
