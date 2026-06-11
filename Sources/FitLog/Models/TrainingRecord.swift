import Foundation

struct TrainingRecord: Identifiable, Codable {
    let id: UUID
    var date: String
    var time: String
    var trainingType: String
    var trainingCategory: String
    var bodyParts: [String]
    var setsCount: String
    var durationMin: Int?
    var distanceKm: Double?
    var note: String

    init(
        id: UUID = UUID(),
        date: String,
        time: String,
        trainingType: String,
        trainingCategory: String = "",
        bodyParts: [String] = [],
        setsCount: String = "",
        durationMin: Int? = nil,
        distanceKm: Double? = nil,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.time = time
        self.trainingType = trainingType
        self.trainingCategory = trainingCategory
        self.bodyParts = bodyParts
        self.setsCount = setsCount
        self.durationMin = durationMin
        self.distanceKm = distanceKm
        self.note = note
    }
}
