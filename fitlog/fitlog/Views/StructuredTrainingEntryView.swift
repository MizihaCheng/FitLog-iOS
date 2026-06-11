import SwiftUI

/// 结构化训练录入（对应 Android StructuredTrainingEntryDialog）
struct StructuredTrainingEntryView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss

    @State private var category: TrainingCategory = .strength
    @State private var selectedParts: Set<String> = []
    @State private var cardioProject = CardioTrainingTypes.first ?? "跑步"
    @State private var durationText = ""
    @State private var distanceText = ""
    @State private var note = ""
    @State private var exercises: [ExerciseInput] = [ExerciseInput()]
    @State private var validation: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    categorySelector

                    if category == .cardio {
                        cardioFields
                    } else {
                        bodyPartSelector
                        noteField(placeholder: "记录今天整体状态，可选")
                        if category == .strength {
                            strengthExercises
                        }
                    }

                    if let validation {
                        Text(validation)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(Color.fitWarningRed)
                    }
                }
                .padding(20)
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("添加训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    // MARK: - 大类选择

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("训练大类").font(.subheadline).foregroundStyle(Color.fitPrimaryText)
            HStack(spacing: 4) {
                ForEach(TrainingCategory.allCases, id: \.self) { option in
                    let selected = option == category
                    Button {
                        category = option
                        validation = nil
                    } label: {
                        Text(option.label)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(selected ? .white : Color.fitSecondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selected ? Color.fitAccent : Color.clear,
                                       in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.fitDivider.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 部位多选

    private var bodyPartSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练部位").font(.subheadline).foregroundStyle(Color.fitPrimaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(StrengthBodyParts, id: \.self) { part in
                    let selected = selectedParts.contains(part)
                    Button {
                        if selected { selectedParts.remove(part) } else { selectedParts.insert(part) }
                        validation = nil
                    } label: {
                        Text(part)
                            .font(.subheadline)
                            .foregroundStyle(selected ? .white : Color.fitPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(selected ? Color.fitAccent : Color.fitDivider.opacity(0.5),
                                       in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 有氧字段

    private var cardioFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("项目").font(.subheadline).foregroundStyle(Color.fitPrimaryText)
                Menu {
                    ForEach(CardioTrainingTypes, id: \.self) { type in
                        Button(type) { cardioProject = type }
                    }
                } label: {
                    HStack {
                        Text(cardioProject).foregroundStyle(Color.fitPrimaryText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Color.fitSecondaryText)
                    }
                    .padding(12)
                    .background(Color.fitDivider.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            labeledField("训练时长", text: $durationText, placeholder: "可选", suffix: "min", decimal: false)
            labeledField("距离", text: $distanceText, placeholder: "可选（游泳填 0.5=500米）", suffix: "km", decimal: true)
            noteField(placeholder: "配速、心率等，可选")
        }
    }

    // MARK: - 力量动作明细

    private var strengthExercises: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().background(Color.fitDivider)
            Text("动作明细").font(.headline).foregroundStyle(Color.fitPrimaryText)

            ForEach($exercises) { $exercise in
                ExerciseInputCard(
                    exercise: $exercise,
                    canDelete: exercises.count > 1,
                    onDelete: { exercises.removeAll { $0.id == exercise.id }
                        if exercises.isEmpty { exercises = [ExerciseInput()] } }
                )
            }

            Button {
                exercises.append(ExerciseInput())
            } label: {
                Text("+ 添加动作")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.fitAccent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 通用字段

    private func noteField(placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("训练备注").font(.subheadline).foregroundStyle(Color.fitPrimaryText)
            TextField(placeholder, text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.fitDivider.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String, suffix: String, decimal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(Color.fitPrimaryText)
            HStack {
                TextField(placeholder, text: text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                Text(suffix).foregroundStyle(Color.fitSecondaryText)
            }
            .padding(12)
            .background(Color.fitDivider.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 保存

    private func save() {
        if category == .strength || category == .rest {
            if selectedParts.isEmpty {
                validation = "请至少选择一个部位"
                return
            }
        }

        let orderedParts = StrengthBodyParts.filter { selectedParts.contains($0) }
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        var record: TrainingRecord
        var sets: [ExerciseSet] = []

        if category == .cardio {
            record = TrainingRecord(
                date: today,
                time: timeFormatter.string(from: Date()),
                trainingType: cardioProject,
                trainingCategory: TrainingCategory.cardio.rawValue,
                bodyParts: [],
                durationMin: Int(durationText.trimmingCharacters(in: .whitespaces)),
                distanceKm: Double(distanceText.trimmingCharacters(in: .whitespaces)),
                note: note.trimmingCharacters(in: .whitespaces)
            )
        } else {
            record = TrainingRecord(
                date: today,
                time: timeFormatter.string(from: Date()),
                trainingType: orderedParts.joined(separator: "、"),
                trainingCategory: category.rawValue,
                bodyParts: orderedParts,
                note: note.trimmingCharacters(in: .whitespaces)
            )
            if category == .strength {
                for exercise in exercises {
                    let name = exercise.exerciseName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { continue }
                    for set in exercise.sets {
                        guard let reps = Int(set.reps.trimmingCharacters(in: .whitespaces)) else { continue }
                        sets.append(ExerciseSet(
                            workoutId: record.id,
                            exerciseName: name,
                            weightKg: Double(set.weightKg.trimmingCharacters(in: .whitespaces)),
                            reps: reps,
                            note: set.note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : set.note.trimmingCharacters(in: .whitespaces)
                        ))
                    }
                }
            }
        }

        store.addTraining(record, sets: sets)
        dismiss()
    }
}

// MARK: - 录入用的可变状态

struct ExerciseInput: Identifiable {
    let id = UUID()
    var exerciseName: String = ""
    var sets: [SetInput] = [SetInput()]
}

struct SetInput: Identifiable {
    let id = UUID()
    var weightKg: String = ""
    var reps: String = ""
    var note: String = ""
}

/// 单个动作卡片：动作名 + 多组
private struct ExerciseInputCard: View {
    @Binding var exercise: ExerciseInput
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("动作名称（如 卧推）", text: $exercise.exerciseName)
                    .font(.subheadline).fontWeight(.semibold)
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.caption).foregroundStyle(Color.fitWarningRed)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    Text("\(index + 1).").font(.subheadline).foregroundStyle(Color.fitSecondaryText).frame(width: 22, alignment: .leading)
                    TextField("重量", text: $exercise.sets[index].weightKg)
                        .keyboardType(.decimalPad).multilineTextAlignment(.center)
                    Text("kg").font(.caption).foregroundStyle(Color.fitSecondaryText)
                    TextField("次数", text: $exercise.sets[index].reps)
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                    Text("次").font(.caption).foregroundStyle(Color.fitSecondaryText)
                    if exercise.sets.count > 1 {
                        Button {
                            exercise.sets.removeAll { $0.id == set.id }
                        } label: {
                            Image(systemName: "minus.circle").font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.fitCardSurface, in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                exercise.sets.append(SetInput())
            } label: {
                Text("+ 添加组").font(.caption).fontWeight(.semibold).foregroundStyle(Color.fitAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.fitDivider.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}
