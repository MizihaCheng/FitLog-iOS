import Foundation
import Combine

@MainActor
class FitStore: ObservableObject {
    @Published var trainingRecords: [TrainingRecord] = []
    @Published var exerciseSets: [ExerciseSet] = []
    @Published var weightRecords: [DailyWeightRecord] = []
    @Published var measurements: [BodyMeasurementRecord] = []
    @Published var goal = GoalRecord(targetWeightKg: "", startWeight: "", startDate: "")

    private let storageURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fitlog_data.json")
    }()

    init() {
        load()
    }

    func save() {
        // TODO: JSON 持久化（与 Android v5 格式兼容）
    }

    private func load() {
        // TODO: 从 storageURL 读取 JSON，解析各字段
    }
}
