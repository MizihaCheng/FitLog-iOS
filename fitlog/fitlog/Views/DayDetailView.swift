import SwiftUI
import UniformTypeIdentifiers

/// 当日详情（对应 Android DayDetailDialog）
struct DayDetailView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    let date: String

    @State private var showingWeight = false
    @State private var showingMeasurement = false
    @State private var showingPDFExporter = false
    @State private var pdfData: Data?

    private var dayTrainings: [TrainingRecord] {
        store.trainingRecords.filter { $0.date == date }.sorted { $0.time > $1.time }
    }
    private var weight: DailyWeightRecord? {
        store.weightRecords.first { $0.date == date }
    }
    private var measurement: BodyMeasurementRecord? {
        store.measurements.first { $0.date == date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    FitPrimaryButton(title: "导出本日 PDF") {
                        pdfData = PDFReport.dayReport(store: store, date: date)
                        showingPDFExporter = true
                    }

                    weightCard
                    measurementCard
                    if !dayTrainings.isEmpty {
                        muscleCard
                    }
                    trainingCard
                }
                .padding(20)
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showingWeight) { WeightEntryView(date: date) }
            .sheet(isPresented: $showingMeasurement) { MeasurementEntryView(date: date) }
            .fileExporter(
                isPresented: $showingPDFExporter,
                document: PDFFileDocument(data: pdfData ?? Data()),
                contentType: .pdf,
                defaultFilename: "FitLog_\(date)"
            ) { _ in }
        }
    }

    private var title: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let d = parser.date(from: date) ?? Date()
        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "M月d日 当天详情"
        return display.string(from: d)
    }

    // MARK: - 体重

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("体重").font(.headline).foregroundStyle(Color.fitPrimaryText)
            if let w = weight, !w.weightKg.isEmpty {
                Text("\(w.weightKg) kg")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.fitDeepOrange)
            } else {
                Text("未记录").foregroundStyle(Color.fitSecondaryText)
            }
            FitPrimaryButton(title: "记录 / 更新体重") { showingWeight = true }
        }
        .fitCard()
    }

    // MARK: - 围度

    private var measurementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本周围度").font(.headline).foregroundStyle(Color.fitPrimaryText)
            if let m = measurement, hasAnyMeasurement(m) {
                VStack(alignment: .leading, spacing: 4) {
                    measurementLine("腰围", m.waistCm, "cm")
                    measurementLine("臀围", m.hipCm, "cm")
                    measurementLine("大腿围", m.thighCm, "cm")
                    measurementLine("胸围", m.chestCm, "cm")
                    measurementLine("臂围", m.armCm, "cm")
                    measurementLine("体脂率", m.bodyFatPercent, "%")
                    if !m.note.isEmpty {
                        Text("备注：\(m.note)").font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                    }
                }
            } else {
                Text("本周暂无围度记录").foregroundStyle(Color.fitSecondaryText)
            }
            FitPrimaryButton(title: "记录 / 更新围度") { showingMeasurement = true }
        }
        .fitCard()
    }

    @ViewBuilder
    private func measurementLine(_ label: String, _ value: String, _ unit: String) -> some View {
        if !value.isEmpty {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                Spacer()
                Text("\(value) \(unit)").font(.subheadline).fontWeight(.medium).foregroundStyle(Color.fitPrimaryText)
            }
        }
    }

    private func hasAnyMeasurement(_ m: BodyMeasurementRecord) -> Bool {
        [m.waistCm, m.hipCm, m.thighCm, m.chestCm, m.armCm, m.bodyFatPercent].contains { !$0.isEmpty }
    }

    // MARK: - 肌肉激活

    private var muscleHighlights: [String: Intensity] {
        dayMuscleHighlights(records: dayTrainings) { store.sets(for: $0) }
    }

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("肌肉激活").font(.headline).foregroundStyle(Color.fitPrimaryText)
            MuscleMapView(highlights: muscleHighlights)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            MuscleLegend()
            ActivatedMuscleChips(highlights: muscleHighlights)
        }
        .fitCard()
    }

    // MARK: - 训练记录

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练记录").font(.headline).foregroundStyle(Color.fitPrimaryText)
            if dayTrainings.isEmpty {
                Text("当天还没有训练记录").foregroundStyle(Color.fitSecondaryText)
            } else {
                ForEach(dayTrainings) { record in
                    TrainingRecordItem(
                        record: record,
                        sets: store.sets(for: record.id),
                        onDelete: { store.deleteTrainingRecord(record) }
                    )
                }
            }
        }
        .fitCard()
    }
}
