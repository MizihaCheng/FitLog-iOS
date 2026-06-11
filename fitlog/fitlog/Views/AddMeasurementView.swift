import SwiftUI

/// 添加/更新某天的围度记录（同一天会覆盖）
struct AddMeasurementView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var waist = ""
    @State private var hip = ""
    @State private var thigh = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var bodyFat = ""
    @State private var note = ""

    /// 至少填一项数值才允许保存
    private var canSave: Bool {
        [waist, hip, thigh, chest, arm, bodyFat]
            .contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                Section("围度（cm，可只填部分）") {
                    measurementField("腰围", unit: "cm", text: $waist)
                    measurementField("臀围", unit: "cm", text: $hip)
                    measurementField("大腿", unit: "cm", text: $thigh)
                    measurementField("胸围", unit: "cm", text: $chest)
                    measurementField("手臂", unit: "cm", text: $arm)
                }
                Section("体脂") {
                    measurementField("体脂率", unit: "%", text: $bodyFat)
                }
                Section("备注（可空）") {
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("记录围度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func measurementField(_ label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            TextField(unit, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    /// 计算所在周的周一~周日（yyyy-MM-dd）
    private func weekRange(for date: Date) -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 周一
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            let today = formatter.string(from: date)
            return (today, today)
        }
        return (formatter.string(from: start), formatter.string(from: end))
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let range = weekRange(for: date)
        let record = BodyMeasurementRecord(
            date: formatter.string(from: date),
            weekStartDate: range.start,
            weekEndDate: range.end,
            waistCm: waist.trimmingCharacters(in: .whitespaces),
            hipCm: hip.trimmingCharacters(in: .whitespaces),
            thighCm: thigh.trimmingCharacters(in: .whitespaces),
            chestCm: chest.trimmingCharacters(in: .whitespaces),
            armCm: arm.trimmingCharacters(in: .whitespaces),
            bodyFatPercent: bodyFat.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces)
        )
        store.upsertMeasurement(record)
        dismiss()
    }
}
