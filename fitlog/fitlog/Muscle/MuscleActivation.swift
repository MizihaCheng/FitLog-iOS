import Foundation

/// 把当天的训练记录转换成肌肉图所需的 [Segment] 列表。
///
/// 每条训练用其多选部位（TrainingRecord.bodyParts，老记录回退到 trainingType）作为 part，
/// 把该训练下各组的动作名拼成 context 交给 MuscleMapper 消歧（「上肢/其他」靠动作名辨别）。
/// 对应 Android MuscleActivation.toMuscleSegments。
func muscleSegments(
    for records: [TrainingRecord],
    sets getSets: (UUID) -> [ExerciseSet]
) -> [Segment] {
    var segments: [Segment] = []
    for record in records {
        let exerciseNames = getSets(record.id)
            .map { $0.exerciseName }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let distinctNames = exerciseNames.filter { seen.insert($0).inserted }
        let context = (distinctNames + [record.trainingType])
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let parts = record.bodyParts.isEmpty ? [record.trainingType] : record.bodyParts
        for part in parts where !part.isEmpty {
            segments.append(Segment(part: part, exercise: context))
        }
    }
    return segments
}

/// 当天激活的肌肉强度图（slug -> 强度）。
func dayMuscleHighlights(
    records: [TrainingRecord],
    sets getSets: (UUID) -> [ExerciseSet]
) -> [String: Intensity] {
    MuscleMapper.mapDay(muscleSegments(for: records, sets: getSets))
}

/// 激活肌群的中文名（主练在前，辅练在后），用于 chips 展示。
func activatedMuscleNames(_ highlights: [String: Intensity]) -> [(name: String, intensity: Intensity)] {
    let primary = highlights.filter { $0.value == .primary }.keys
    let secondary = highlights.filter { $0.value == .secondary }.keys
    var result: [(name: String, intensity: Intensity)] = []
    var seen = Set<String>()
    for slug in Array(primary) + Array(secondary) {
        guard let name = MuscleMap.nameCN[slug], let intensity = highlights[slug] else { continue }
        if seen.insert(name).inserted {
            result.append((name, intensity))
        }
    }
    return result
}
