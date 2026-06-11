import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 生成训练报告 PDF
@MainActor
enum PDFReport {
    static func trainingReport(store: FitStore) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let groups = Dictionary(grouping: store.trainingRecords) { $0.date }
        let sortedDates = groups.keys.sorted(by: >)

        return renderer.pdfData { context in
            var y: CGFloat = margin
            context.beginPage()

            func draw(_ text: String, font: UIFont, color: UIColor = .black, indent: CGFloat = 0) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let attributed = NSAttributedString(string: text, attributes: attrs)
                let maxWidth = pageRect.width - 2 * margin - indent
                let height = attributed.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                ).height
                if y + height + 4 > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
                attributed.draw(in: CGRect(x: margin + indent, y: y, width: maxWidth, height: height))
                y += height + 4
            }

            // 标题
            draw("FitLog 训练报告", font: .boldSystemFont(ofSize: 22))
            let generated = DateFormatter()
            generated.dateFormat = "yyyy-MM-dd HH:mm"
            draw("生成时间：\(generated.string(from: Date()))", font: .systemFont(ofSize: 11), color: .gray)
            draw("训练总次数：\(store.trainingRecords.count)", font: .systemFont(ofSize: 12), color: .darkGray)
            y += 8

            if sortedDates.isEmpty {
                draw("暂无训练记录", font: .systemFont(ofSize: 13), color: .gray)
            }

            for date in sortedDates {
                draw(date, font: .boldSystemFont(ofSize: 15))
                let records = (groups[date] ?? []).sorted { $0.time > $1.time }
                for record in records {
                    var line = "· \(record.time)  \(record.trainingType)"
                    if let duration = record.durationMin {
                        line += "  \(duration)分钟"
                    }
                    draw(line, font: .systemFont(ofSize: 13), indent: 12)
                    if !record.note.isEmpty {
                        draw("备注：\(record.note)", font: .systemFont(ofSize: 11), color: .gray, indent: 24)
                    }
                    for set in store.sets(for: record.id) {
                        var s = "- \(set.exerciseName)"
                        if let weight = set.weightKg {
                            s += "  \(trimmed(weight))kg × \(set.reps)"
                        } else {
                            s += "  \(set.reps)次"
                        }
                        draw(s, font: .systemFont(ofSize: 11), color: .darkGray, indent: 24)
                    }
                }
                y += 6
            }
        }
    }

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// 用于 fileExporter 导出 PDF
struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
