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

    // MARK: - 备份导出 / 导入

    /// 导出当前全部数据为 JSON
    func exportData() -> Data? {
        let snapshot = Snapshot(
            trainingRecords: trainingRecords,
            exerciseSets: exerciseSets,
            weightRecords: weightRecords,
            measurements: measurements,
            goal: goal
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }

    /// 从 JSON 导入（覆盖现有数据），成功返回 true
    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return false
        }
        trainingRecords = snapshot.trainingRecords
        exerciseSets = snapshot.exerciseSets
        weightRecords = snapshot.weightRecords
        measurements = snapshot.measurements
        goal = snapshot.goal
        save()
        return true
    }

    // MARK: - 训练记录

    func addTrainingRecord(_ record: TrainingRecord) {
        trainingRecords.append(record)
        save()
    }

    /// 一次训练连同它的组一起保存
    func addTraining(_ record: TrainingRecord, sets: [ExerciseSet]) {
        trainingRecords.append(record)
        exerciseSets.append(contentsOf: sets)
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

    /// 历史出现过的动作名（去重、排序），用于录入时自动补全
    var exerciseNameSuggestions: [String] {
        let names = exerciseSets
            .map { $0.exerciseName.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    func addExerciseSet(_ set: ExerciseSet) {
        exerciseSets.append(set)
        save()
    }

    func deleteExerciseSet(_ set: ExerciseSet) {
        exerciseSets.removeAll { $0.id == set.id }
        save()
    }

    // MARK: - 体重记录（按日期一天一条）

    func upsertWeight(_ record: DailyWeightRecord) {
        weightRecords.removeAll { $0.date == record.date }
        weightRecords.append(record)
        save()
    }

    func deleteWeight(_ record: DailyWeightRecord) {
        weightRecords.removeAll { $0.date == record.date }
        save()
    }

    // MARK: - 围度记录（一周一条，管整周）

    /// 查某天所属那一周的围度（按周起始匹配）。
    func measurement(forWeekOf date: String) -> BodyMeasurementRecord? {
        let week = fitWeekStart(of: date)
        return measurements.first { $0.normalizedWeekStart == week }
    }

    func upsertMeasurement(_ record: BodyMeasurementRecord) {
        let week = record.normalizedWeekStart
        measurements.removeAll { $0.normalizedWeekStart == week }
        measurements.append(record)
        save()
    }

    func deleteMeasurement(_ record: BodyMeasurementRecord) {
        let week = record.normalizedWeekStart
        measurements.removeAll { $0.normalizedWeekStart == week }
        save()
    }

    // MARK: - 目标

    func updateGoal(_ newGoal: GoalRecord) {
        goal = newGoal
        save()
    }

    /// 设目标体重；起始体重为空时自动取最早一条体重
    func setTargetWeight(_ target: String) {
        goal.targetWeightKg = target.trimmingCharacters(in: .whitespaces)
        if goal.startWeight.isEmpty, let earliest = weightRecords.min(by: { $0.date < $1.date }) {
            goal.startWeight = earliest.weightKg
        }
        if goal.startDate.isEmpty {
            goal.startDate = fitTodayString()
        }
        save()
    }

    // MARK: - 数据清除

    func clearTrainingRecords() {
        trainingRecords = []
        exerciseSets = []
        save()
    }

    func clearWeightRecords() {
        weightRecords = []
        save()
    }

    func clearMeasurements() {
        measurements = []
        save()
    }

    func resetGoal() {
        goal = GoalRecord(targetWeightKg: "", startWeight: "", startDate: "")
        save()
    }

    func clearAll() {
        trainingRecords = []
        exerciseSets = []
        weightRecords = []
        measurements = []
        goal = GoalRecord(targetWeightKg: "", startWeight: "", startDate: "")
        save()
    }
}
