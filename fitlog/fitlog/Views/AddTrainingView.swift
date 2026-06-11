import SwiftUI

/// 添加一条训练记录的表单
struct AddTrainingView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var trainingType = ""
    @State private var durationText = ""
    @State private var note = ""

    private var canSave: Bool {
        !trainingType.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    TextField("训练类型（如 力量 / 跑步）", text: $trainingType)
                }
                Section("详情（可空）") {
                    TextField("时长（分钟）", text: $durationText)
                        .keyboardType(.numberPad)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("添加训练")
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let record = TrainingRecord(
            date: dateFormatter.string(from: date),
            time: timeFormatter.string(from: Date()),
            trainingType: trainingType.trimmingCharacters(in: .whitespaces),
            durationMin: Int(durationText),
            note: note.trimmingCharacters(in: .whitespaces)
        )
        store.addTrainingRecord(record)
        dismiss()
    }
}
