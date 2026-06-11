import Foundation

struct BodyMeasurementRecord: Codable {
    var date: String
    var weekStartDate: String
    var weekEndDate: String
    var waistCm: String
    var hipCm: String
    var thighCm: String
    var chestCm: String
    var armCm: String
    var bodyFatPercent: String
    var note: String
}
