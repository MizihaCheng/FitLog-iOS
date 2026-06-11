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

    /// 磁盘上 JSON 的完整结构
    private struct Snapshot: Codable {
        var trainingRecords: [TrainingRecord]
        var exerciseSets: [ExerciseSet]
        var weightRecords: [DailyWeightRecord]
        var measurements: [BodyMeasurementRecord]
        var goal: GoalRecord
    }

    func save() {
        let snapshot = Snapshot(
            trainingRecords: trainingRecords,
            exerciseSets: exerciseSets,
            weightRecords: weightRecords,
            measurements: measurements,
            goal: goal
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("FitStore 保存失败: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        trainingRecords = snapshot.trainingRecords
        exerciseSets = snapshot.exerciseSets
        weightRecords = snapshot.weightRecords
        measurements = snapshot.measurements
        goal = snapshot.goal
    }

    // MARK: - 训练记录

    func addTrainingRecord(_ record: TrainingRecord) {
        trainingRecords.append(record)
        save()
    }

    func deleteTrainingRecord(_ record: TrainingRecord) {
        trainingRecords.removeAll { $0.id == record.id }
        // 连带删除该训练下的所有组
        exerciseSets.removeAll { $0.workoutId == record.id }
        save()
    }

    // MARK: - 训练组（ExerciseSet）

    /// 取某次训练下的所有组
    func sets(for workoutId: UUID) -> [ExerciseSet] {
        exerciseSets.filter { $0.workoutId == workoutId }
    }

    func addExerciseSet(_ set: ExerciseSet) {
        exerciseSets.append(set)
        save()
    }

    func deleteExerciseSet(_ set: ExerciseSet) {
        exerciseSets.removeAll { $0.id == set.id }
        save()
    }
}
