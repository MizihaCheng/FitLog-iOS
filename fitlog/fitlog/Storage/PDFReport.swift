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

    // MARK: - 单日报告（对应 Android PdfExporter.exportDayDetail，含肌肉图）

    static func dayReport(store: FitStore, date: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 42
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let orange = UIColor(red: 0.886, green: 0.439, blue: 0.227, alpha: 1)
        let orangeDark = UIColor(red: 0.76, green: 0.325, blue: 0.122, alpha: 1)
        let orangeBg = UIColor(red: 0.984, green: 0.918, blue: 0.875, alpha: 1)
        let textDark = UIColor(red: 0.153, green: 0.133, blue: 0.098, alpha: 1)
        let gray = UIColor(red: 0.66, green: 0.62, blue: 0.557, alpha: 1)
        let green = UIColor(red: 0.369, green: 0.62, blue: 0.431, alpha: 1)
        let red = UIColor(red: 0.851, green: 0.325, blue: 0.31, alpha: 1)
        let divider = UIColor(red: 0.929, green: 0.906, blue: 0.859, alpha: 1)

        let weight = store.weightRecords.first { $0.date == date }
        let measurement = store.measurements.first { $0.date == date }
        let trainings = store.trainingRecords.filter { $0.date == date }.sorted { $0.time > $1.time }
        let goal = store.goal

        return renderer.pdfData { context in
            var y: CGFloat = 0
            context.beginPage()

            func draw(_ text: String, _ x: CGFloat, _ yy: CGFloat, _ font: UIFont, _ color: UIColor) {
                NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                    .draw(at: CGPoint(x: x, y: yy))
            }
            func fill(_ rect: CGRect, _ color: UIColor) { color.setFill(); UIRectFill(rect) }
            func ensure(_ h: CGFloat) {
                if y + h > pageRect.height - 60 { context.beginPage(); y = margin }
            }
            func sectionTitle(_ t: String) {
                ensure(40)
                fill(CGRect(x: margin, y: y, width: 4, height: 18), orange)
                draw(t, margin + 12, y, .boldSystemFont(ofSize: 14), textDark)
                y += 30
            }

            // 头部橙色条
            fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 90), orange)
            draw("FitLog", margin, 22, .boldSystemFont(ofSize: 26), .white)
            draw("当日记录　\(date)", margin, 58, .systemFont(ofSize: 14), .white)
            y = 110

            // 体重
            sectionTitle("体重")
            if let w = weight, let val = Double(w.weightKg) {
                draw("\(fitFormatWeight(val)) kg", margin + 6, y, .boldSystemFont(ofSize: 30), orangeDark)
                y += 40
                if let yChange = yesterdayChange(store: store, date: date, today: val) {
                    let color = yChange < 0 ? green : (yChange > 0 ? red : gray)
                    let sign = yChange < 0 ? "↓ " : (yChange > 0 ? "↑ " : "")
                    draw("较前一日 \(sign)\(fitFormatWeight(abs(yChange))) kg", margin + 8, y, .systemFont(ofSize: 12), color)
                    y += 22
                }
            } else {
                draw("未记录", margin + 6, y, .systemFont(ofSize: 13), gray); y += 24
            }
            y += 8

            // 目标进度
            sectionTitle("目标进度")
            if let s = Double(goal.startWeight), let t = Double(goal.targetWeightKg),
               let c = weight.flatMap({ Double($0.weightKg) }), abs(s - t) > 0.01 {
                let boxH: CGFloat = 56
                fill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: boxH), orangeBg)
                let colW = (pageRect.width - margin * 2) / 3
                let items = [("起始", "\(fitFormatWeight(s)) kg"), ("当前", "\(fitFormatWeight(c)) kg"), ("目标", "\(fitFormatWeight(t)) kg")]
                for (i, item) in items.enumerated() {
                    draw(item.0, margin + colW * CGFloat(i) + 16, y + 10, .systemFont(ofSize: 11), gray)
                    draw(item.1, margin + colW * CGFloat(i) + 16, y + 28, .boldSystemFont(ofSize: 16), textDark)
                }
                y += boxH + 12
                let progress = min(max((s - c) / (s - t), 0), 1)
                let barW = pageRect.width - margin * 2
                fill(CGRect(x: margin, y: y, width: barW, height: 12), divider)
                fill(CGRect(x: margin, y: y, width: barW * CGFloat(progress), height: 12), orange)
                draw("\(Int(progress * 100))%", margin + barW + 6 - 40, y - 2, .boldSystemFont(ofSize: 11), textDark)
                y += 26
            } else {
                draw("起始或目标体重未设置", margin + 6, y, .systemFont(ofSize: 13), gray); y += 26
            }
            y += 8

            // 围度
            sectionTitle("围度")
            let mItems: [(String, String)] = [
                ("腰围", measurement?.waistCm ?? ""), ("臀围", measurement?.hipCm ?? ""),
                ("大腿围", measurement?.thighCm ?? ""), ("胸围", measurement?.chestCm ?? ""),
                ("臂围", measurement?.armCm ?? ""), ("体脂率", measurement?.bodyFatPercent ?? "")
            ].filter { !$0.1.isEmpty }
            if mItems.isEmpty {
                draw("未记录", margin + 6, y, .systemFont(ofSize: 13), gray); y += 24
            } else {
                for (i, item) in mItems.enumerated() {
                    let unit = item.0 == "体脂率" ? "%" : " cm"
                    let x = margin + 6 + (i % 2 == 0 ? 0 : (pageRect.width - margin * 2) / 2)
                    draw("\(item.0)  \(item.1)\(unit)", x, y, .systemFont(ofSize: 12), textDark)
                    if i % 2 == 1 { y += 20 }
                }
                if mItems.count % 2 == 1 { y += 20 }
            }
            y += 8

            // 肌肉激活
            if !trainings.isEmpty {
                let highlights = dayMuscleHighlights(records: trainings) { store.sets(for: $0) }
                sectionTitle("肌肉激活")
                let mapH: CGFloat = 200
                ensure(mapH + 8)
                let mapRect = CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: mapH)
                drawMuscleMap(context.cgContext, highlights: highlights, in: mapRect)
                y += mapH + 6
                let names = activatedMuscleNames(highlights).map { $0.name }
                if !names.isEmpty {
                    draw("激活：" + names.joined(separator: "、"), margin + 6, y, .systemFont(ofSize: 11), orangeDark)
                    y += 18
                }
                y += 8
            }

            // 训练
            sectionTitle("训练")
            if trainings.isEmpty {
                draw("暂无训练", margin + 6, y, .systemFont(ofSize: 13), gray); y += 24
            } else {
                for record in trainings {
                    ensure(40)
                    fill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 26), orangeBg)
                    draw(record.displayTitle, margin + 10, y + 6, .boldSystemFont(ofSize: 13), textDark)
                    if !record.metricText.isEmpty {
                        draw(record.metricText, margin + 220, y + 7, .systemFont(ofSize: 11), orangeDark)
                    }
                    y += 30
                    if !record.note.isEmpty {
                        draw("备注：\(record.note)", margin + 12, y, .systemFont(ofSize: 11), gray); y += 18
                    }
                    for set in store.sets(for: record.id) {
                        ensure(16)
                        draw("· \(set.exerciseName)  \(set.detailSetText)", margin + 16, y, .systemFont(ofSize: 11), textDark)
                        y += 15
                    }
                    y += 8
                }
            }

            // 页脚
            let footY = pageRect.height - 50
            fill(CGRect(x: margin, y: footY - 8, width: pageRect.width - margin * 2, height: 1), divider)
            let gen = DateFormatter(); gen.dateFormat = "yyyy-MM-dd HH:mm"
            draw("FitLog  导出时间 \(gen.string(from: Date()))", margin, footY, .systemFont(ofSize: 10), gray)
        }
    }

    // MARK: - 肌肉图（绘进 PDF 的 CGContext，正反两人像并排）

    private static func drawMuscleMap(_ cg: CGContext, highlights: [String: Intensity], in rect: CGRect) {
        let vw = MuscleMap.viewW, vh = MuscleMap.viewH
        let gap: CGFloat = 36
        let halfW = (rect.width - gap) / 2
        let scale = min(halfW / vw, rect.height / vh)
        let figW = vw * scale, figH = vh * scale
        let dy = rect.minY + (rect.height - figH) / 2
        let frontDx = rect.minX + (halfW - figW) / 2
        let backDx = rect.minX + halfW + gap + (halfW - figW) / 2
        drawMuscleFigure(cg, MuscleGeometry.frontPaths, highlights, scale: scale, dx: frontDx, dy: dy)
        drawMuscleFigure(cg, MuscleGeometry.backPaths, highlights, scale: scale, dx: backDx, dy: dy)
    }

    private static func drawMuscleFigure(
        _ cg: CGContext,
        _ paths: [String: Path],
        _ highlights: [String: Intensity],
        scale: CGFloat, dx: CGFloat, dy: CGFloat
    ) {
        let primaryFill = UIColor(red: 0.949, green: 0.420, blue: 0.114, alpha: 1)
        let primaryStroke = UIColor(red: 0.761, green: 0.267, blue: 0.020, alpha: 1)
        let secondaryFill = UIColor(red: 0.984, green: 0.780, blue: 0.612, alpha: 1)
        let secondaryStroke = UIColor(red: 0.933, green: 0.624, blue: 0.369, alpha: 1)
        let baseFill = UIColor(red: 0.894, green: 0.855, blue: 0.796, alpha: 1)
        let baseStroke = UIColor(red: 0.827, green: 0.780, blue: 0.706, alpha: 1)

        var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)

        func pass(_ filter: (Intensity?) -> Bool, _ fill: UIColor, _ stroke: UIColor) {
            for (slug, path) in paths where filter(highlights[slug]) {
                guard let cgp = path.cgPath.copy(using: &transform) else { continue }
                cg.addPath(cgp); cg.setFillColor(fill.cgColor); cg.fillPath()
                cg.addPath(cgp); cg.setStrokeColor(stroke.cgColor)
                cg.setLineWidth(1.4 * scale); cg.strokePath()
            }
        }
        pass({ $0 == nil }, baseFill, baseStroke)
        pass({ $0 == .secondary }, secondaryFill, secondaryStroke)
        pass({ $0 == .primary }, primaryFill, primaryStroke)
    }

    private static func yesterdayChange(store: FitStore, date: String, today: Double) -> Double? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date),
              let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: d),
              let yVal = Double(store.weightRecords.first(where: { $0.date == f.string(from: yesterday) })?.weightKg ?? "")
        else { return nil }
        return today - yVal
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
