import SwiftUI

/// 记录体重（对应 Android WeightEntryDialog），默认当天，也可传指定日期
struct WeightEntryView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    var date: String = fitTodayString()
    @State private var weight = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FitLabeledField(
                        label: "今日体重",
                        text: $weight,
                        placeholder: "请输入今日体重",
                        suffix: "kg"
                    )
                    FitPrimaryButton(title: "保存体重") { save() }
                }
                .padding(20)
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                weight = store.weightRecords.first { $0.date == date }?.weightKg ?? ""
            }
        }
    }

    private func save() {
        let trimmed = weight.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.upsertWeight(DailyWeightRecord(date: date, weightKg: trimmed))
        }
        dismiss()
    }
}
