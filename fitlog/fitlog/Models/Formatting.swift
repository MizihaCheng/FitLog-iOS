import Foundation

/// 今天的日期字符串 yyyy-MM-dd
func fitTodayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

/// 与 Android StatsUtils.formatWeight 一致：保留一位小数，整数则去掉小数
func fitFormatWeight(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded.truncatingRemainder(dividingBy: 1) == 0 {
        return String(Int(rounded))
    }
    return String(rounded)
}

extension TrainingRecord {
    /// 标题：有部位则用「胸、背」这种，否则用训练类型
    var displayTitle: String {
        bodyParts.isEmpty ? trainingType : bodyParts.joined(separator: "、")
    }

    var distanceText: String? {
        distanceKm.map { "\(fitFormatWeight($0)) km" }
    }

    /// 右上角指标：时长 · 距离
    var metricText: String {
        var parts: [String] = []
        if let duration = durationMin { parts.append("\(duration) min") }
        if let distance = distanceText { parts.append(distance) }
        return parts.joined(separator: " · ")
    }
}

extension ExerciseSet {
    /// 组文本，如「60kg × 10」
    var detailSetText: String {
        let weight = weightKg.map { "\(fitFormatWeight($0))kg " } ?? ""
        return "\(weight)× \(reps)"
    }
}
