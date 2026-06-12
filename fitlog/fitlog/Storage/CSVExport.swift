import SwiftUI
import UniformTypeIdentifiers

/// 生成"明细版" CSV：训练按每一组拆成单独一行（比 Android 的按天汇总更详细），
/// 并带上当日体重与围度上下文。仅有体重/围度的日期也各占一行。
@MainActor
func fitDetailedCSV(store: FitStore) -> String {
    let columns = [
        "日期", "时间", "训练大类", "部位/项目", "时长(min)", "距离(km)",
        "动作", "组序", "重量(kg)", "次数", "组备注", "训练备注",
        "当日体重(kg)", "腰围(cm)", "臀围(cm)", "大腿围(cm)", "胸围(cm)", "臂围(cm)", "体脂率(%)", "围度备注"
    ]

    func categoryLabel(_ raw: String) -> String {
        switch raw {
        case "strength": return "力量"
        case "cardio": return "有氧"
        case "rest": return "拉伸"
        default: return raw
        }
    }

    let allDates = Set(store.weightRecords.map { $0.date }
                       + store.trainingRecords.map { $0.date }
                       + store.measurements.map { $0.date })
        .filter { !$0.isEmpty }
        .sorted(by: >)

    var lines: [String] = []
    lines.append(columns.map(csvEscape).joined(separator: ","))

    for date in allDates {
        let weight = store.weightRecords.first { $0.date == date }
        let measurement = store.measurement(forWeekOf: date)
        let trainings = store.trainingRecords.filter { $0.date == date }.sorted { $0.time < $1.time }

        // 当日的体重/围度上下文（每行重复，便于表格分析）
        let ctx: [String] = [
            weight?.weightKg ?? "",
            measurement?.waistCm ?? "", measurement?.hipCm ?? "", measurement?.thighCm ?? "",
            measurement?.chestCm ?? "", measurement?.armCm ?? "", measurement?.bodyFatPercent ?? "",
            measurement?.note ?? ""
        ]

        if trainings.isEmpty {
            // 仅体重/围度的日期
            let row = [date, "", "", "", "", "", "", "", "", "", "", ""] + ctx
            lines.append(row.map(csvEscape).joined(separator: ","))
            continue
        }

        for record in trainings {
            let base = [
                date, record.time, categoryLabel(record.trainingCategory), record.displayTitle,
                record.durationMin.map(String.init) ?? "",
                record.distanceKm.map { fitFormatWeight($0) } ?? ""
            ]
            let sets = store.sets(for: record.id)
            if sets.isEmpty {
                let row = base + ["", "", "", "", "", record.note] + ctx
                lines.append(row.map(csvEscape).joined(separator: ","))
            } else {
                for (index, set) in sets.enumerated() {
                    let row = base + [
                        set.exerciseName,
                        "\(index + 1)",
                        set.weightKg.map { fitFormatWeight($0) } ?? "",
                        "\(set.reps)",
                        set.note ?? "",
                        record.note
                    ] + ctx
                    lines.append(row.map(csvEscape).joined(separator: ","))
                }
            }
        }
    }

    // BOM 让 Excel 正确识别 UTF-8 中文
    return "\u{FEFF}" + lines.joined(separator: "\r\n")
}

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

/// 用于 fileExporter 导出 CSV
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
