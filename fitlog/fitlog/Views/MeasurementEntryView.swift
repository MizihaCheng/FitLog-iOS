import SwiftUI

/// 记录围度（对应 Android MeasurementEntryDialog），默认当天，也可传指定日期
struct MeasurementEntryView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    var date: String = fitTodayString()

    @State private var waist = ""
    @State private var hip = ""
    @State private var thigh = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var bodyFat = ""
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("建议每周测一次围度")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitSecondaryText)

                    FitLabeledField(label: "腰围", text: $waist, placeholder: "腰围", suffix: "cm")
                    FitLabeledField(label: "臀围", text: $hip, placeholder: "臀围", suffix: "cm")
                    FitLabeledField(label: "大腿围", text: $thigh, placeholder: "大腿围", suffix: "cm")
                    FitLabeledField(label: "胸围", text: $chest, placeholder: "可选", suffix: "cm")
                    FitLabeledField(label: "臂围", text: $arm, placeholder: "可选", suffix: "cm")
                    FitLabeledField(label: "体脂率", text: $bodyFat, placeholder: "可选", suffix: "%")
                    FitLabeledField(label: "备注", text: $note, placeholder: "围度备注，可选", decimal: false, multiline: true)

                    FitPrimaryButton(title: "保存围度") { save() }
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("本周围度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        guard !loaded else { return }
        loaded = true
        guard let existing = store.measurement(forWeekOf: date) else { return }
        waist = existing.waistCm
        hip = existing.hipCm
        thigh = existing.thighCm
        chest = existing.chestCm
        arm = existing.armCm
        bodyFat = existing.bodyFatPercent
        note = existing.note
    }

    private func save() {
        let values = [waist, hip, thigh, chest, arm, bodyFat]
        guard values.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            dismiss()
            return
        }
        let range = weekRange(for: date)
        store.upsertMeasurement(BodyMeasurementRecord(
            date: date,
            weekStartDate: range.start,
            weekEndDate: range.end,
            waistCm: waist.trimmingCharacters(in: .whitespaces),
            hipCm: hip.trimmingCharacters(in: .whitespaces),
            thighCm: thigh.trimmingCharacters(in: .whitespaces),
            chestCm: chest.trimmingCharacters(in: .whitespaces),
            armCm: arm.trimmingCharacters(in: .whitespaces),
            bodyFatPercent: bodyFat.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces)
        ))
        dismiss()
    }

    private func weekRange(for dateString: String) -> (start: String, end: String) {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let date = parser.date(from: dateString) ?? Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let start = calendar.date(from: comps),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return (dateString, dateString)
        }
        return (parser.string(from: start), parser.string(from: end))
    }
}
