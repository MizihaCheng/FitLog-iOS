import SwiftUI

/// 添加/更新某天的体重（同一天会覆盖）
struct AddWeightView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weightText = ""

    private var canSave: Bool {
        Double(weightText.trimmingCharacters(in: .whitespaces)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    TextField("体重（kg）", text: $weightText)
                        .keyboardType(.decimalPad)
                }
                .fitCardRow()
            }
            .fitListChrome()
            .navigationTitle("记录体重")
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

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let record = DailyWeightRecord(
            date: formatter.string(from: date),
            weightKg: weightText.trimmingCharacters(in: .whitespaces)
        )
        store.upsertWeight(record)
        dismiss()
    }
}
