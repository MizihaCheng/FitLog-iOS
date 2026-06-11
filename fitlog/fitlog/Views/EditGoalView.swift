import SwiftUI

/// 编辑减脂/增肌目标
struct EditGoalView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    @State private var targetWeight = ""
    @State private var startWeight = ""
    @State private var startDate = Date()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("体重目标") {
                    TextField("目标体重（kg）", text: $targetWeight)
                        .keyboardType(.decimalPad)
                    TextField("起始体重（kg）", text: $startWeight)
                        .keyboardType(.decimalPad)
                }
                .fitCardRow()
                Section("起始日期") {
                    DatePicker("日期", selection: $startDate, displayedComponents: .date)
                }
                .fitCardRow()
            }
            .fitListChrome()
            .navigationTitle("编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        targetWeight = store.goal.targetWeightKg
        startWeight = store.goal.startWeight
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        if let parsed = parser.date(from: store.goal.startDate) {
            startDate = parsed
        }
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let goal = GoalRecord(
            targetWeightKg: targetWeight.trimmingCharacters(in: .whitespaces),
            startWeight: startWeight.trimmingCharacters(in: .whitespaces),
            startDate: formatter.string(from: startDate)
        )
        store.updateGoal(goal)
        dismiss()
    }
}
