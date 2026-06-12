import Foundation

/// 把"今天的训练"攒成 prompt，调 DeepSeek 生成一段中文总结点评（被动式，按需触发）。
enum TodaySummary {

    static let systemPrompt = """
    你是一位专业、亲切的健身教练助手。用户会给你他某一天的训练记录。
    请用中文写一段简短的总结点评（120~200 字），包含：
    1. 这一天练了什么、整体完成度/强度如何；
    2. 有没有亮点（比如某个动作重量或次数不错、有氧距离够、运动后心率回落大说明心肺好）；
    3. 一两条具体、可操作的建议或提醒（比如记得拉伸、下次换个部位、别连续上大强度）。
    语气鼓励、口语化，直接成段，不要用 markdown 标题或列表符号。
    如果数据很少，就简短点评并鼓励继续记录。结尾不用加免责声明。
    """

    /// 把今天的训练（动作/组数/有氧/练后心率恢复 + 今日体重）整理成喂给模型的文本。
    @MainActor
    static func buildUserPrompt(store: FitStore, date: String) -> String {
        let trainings = store.trainingRecords
            .filter { $0.date == date }
            .sorted { $0.time < $1.time }

        var lines: [String] = ["\(date) 这一天的训练记录："]

        if trainings.isEmpty {
            lines.append("（今天还没有训练记录）")
        } else {
            for (i, t) in trainings.enumerated() {
                var head = "\(i + 1). \(t.displayTitle)"
                if !t.metricText.isEmpty { head += "（\(t.metricText)）" }
                lines.append(head)
                for s in store.sets(for: t.id) {
                    lines.append("   - \(s.exerciseName) \(s.detailSetText)")
                }
                if let r = store.recovery(forWorkout: t.id) {
                    lines.append("   运动后心率恢复：峰值\(r.peakBpm)→1分钟后\(r.endBpm)，回落\(r.recoveryDrop)bpm")
                }
                if !t.note.isEmpty { lines.append("   备注：\(t.note)") }
            }
        }

        if let w = store.weightRecords.first(where: { $0.date == date }), !w.weightKg.isEmpty {
            lines.append("今天体重：\(w.weightKg)kg")
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func generate(store: FitStore, apiKey: String, date: String) async throws -> String {
        let client = DeepSeekClient(apiKey: apiKey)
        return try await client.chat(system: systemPrompt, user: buildUserPrompt(store: store, date: date))
    }
}
