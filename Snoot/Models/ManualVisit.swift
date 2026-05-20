import Foundation
import SwiftData

@Model
class ManualVisit {
    var id: UUID = UUID()
    var dogLocalId: UUID = UUID()
    var visitedAt: Date = Date()
    var fed: Bool = false
    var walked: Bool = false
    var walkDurationMins: Int = 0
    var notes: String = ""
    var loggedByName: String = ""

    init(dogLocalId: UUID, loggedByName: String = "") {
        self.dogLocalId = dogLocalId
        self.loggedByName = loggedByName
    }
}
