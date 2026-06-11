import SwiftUI

/// 训练详情：展示某次训练下的所有组，可增删
struct WorkoutDetailView: View {
    @EnvironmentObject var store: FitStore
    let record: TrainingRecord

    @State private var showingAdd = false

    private var sets: [ExerciseSet] {
        store.sets(for: record.id)
    }

    var body: some View {
        List {
            Section("训练信息") {
                LabeledContent("类型", value: record.trainingType)
                LabeledContent("日期", value: record.date)
                LabeledContent("时间", value: record.time)
                if let duration = record.durationMin {
                    LabeledContent("时长", value: "\(duration) 分钟")
                }
                if !record.note.isEmpty {
                    LabeledContent("备注", value: record.note)
                }
            }
            .fitCardRow()

            Section("训练组") {
                if sets.isEmpty {
                    Text("还没有训练组，点右上角 + 添加")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sets) { set in
                        SetRow(set: set)
                    }
                    .onDelete(perform: delete)
                }
            }
            .fitCardRow()
        }
        .fitListChrome()
        .navigationTitle(record.trainingType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSetView(workoutId: record.id)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.deleteExerciseSet(sets[index])
        }
    }
}

/// 单组展示，如「卧推    60.0kg × 10」
private struct SetRow: View {
    let set: ExerciseSet

    private var weightText: String {
        if let weight = set.weightKg {
            return "\(formatted(weight))kg × \(set.reps)"
        } else {
            return "\(set.reps) 次"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(set.exerciseName)
                    .font(.headline)
                Spacer()
                Text(weightText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let note = set.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// 去掉多余小数，如 60.0 -> 60，62.5 -> 62.5
    private func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}
