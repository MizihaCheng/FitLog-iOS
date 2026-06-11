import SwiftUI

/// 给某次训练添加一组「动作 + 重量 × 次数」
struct AddSetView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID

    @State private var exerciseName = ""
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var note = ""

    private var canSave: Bool {
        !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(repsText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("动作") {
                    TextField("动作名称（如 卧推 / 深蹲）", text: $exerciseName)
                }
                .fitCardRow()
                Section("组数据") {
                    TextField("重量（kg，可空）", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("次数", text: $repsText)
                        .keyboardType(.numberPad)
                }
                .fitCardRow()
                Section("备注（可空）") {
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
                .fitCardRow()
            }
            .fitListChrome()
            .navigationTitle("添加训练组")
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
        let set = ExerciseSet(
            workoutId: workoutId,
            exerciseName: exerciseName.trimmingCharacters(in: .whitespaces),
            weightKg: Double(weightText),
            reps: Int(repsText) ?? 0,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces)
        )
        store.addExerciseSet(set)
        dismiss()
    }
}
