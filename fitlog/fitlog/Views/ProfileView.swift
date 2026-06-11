import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: FitStore

    @State private var showingGoal = false
    @State private var showingAddWeight = false
    @State private var showingAddMeasurement = false

    private var sortedWeights: [DailyWeightRecord] {
        store.weightRecords.sorted { $0.date > $1.date }
    }

    private var sortedMeasurements: [BodyMeasurementRecord] {
        store.measurements.sorted { $0.date > $1.date }
    }

    private var hasGoal: Bool {
        !(store.goal.targetWeightKg.isEmpty && store.goal.startWeight.isEmpty && store.goal.startDate.isEmpty)
    }

    var body: some View {
        NavigationStack {
            List {
                // 目标
                Section("目标") {
                    if hasGoal {
                        if !store.goal.targetWeightKg.isEmpty {
                            LabeledContent("目标体重", value: "\(store.goal.targetWeightKg) kg")
                        }
                        if !store.goal.startWeight.isEmpty {
                            LabeledContent("起始体重", value: "\(store.goal.startWeight) kg")
                        }
                        if !store.goal.startDate.isEmpty {
                            LabeledContent("起始日期", value: store.goal.startDate)
                        }
                    } else {
                        Text("还没有设置目标")
                            .foregroundStyle(.secondary)
                    }
                    Button("编辑目标") { showingGoal = true }
                }

                // 体重记录
                Section {
                    if sortedWeights.isEmpty {
                        Text("还没有体重记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedWeights, id: \.date) { record in
                            LabeledContent(record.date, value: "\(record.weightKg) kg")
                        }
                        .onDelete(perform: deleteWeight)
                    }
                } header: {
                    SectionHeaderWithAdd(title: "体重记录") { showingAddWeight = true }
                }

                // 围度记录
                Section {
                    if sortedMeasurements.isEmpty {
                        Text("还没有围度记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedMeasurements, id: \.date) { record in
                            MeasurementRow(record: record)
                        }
                        .onDelete(perform: deleteMeasurement)
                    }
                } header: {
                    SectionHeaderWithAdd(title: "围度记录") { showingAddMeasurement = true }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showingGoal) { EditGoalView() }
            .sheet(isPresented: $showingAddWeight) { AddWeightView() }
            .sheet(isPresented: $showingAddMeasurement) { AddMeasurementView() }
        }
    }

    private func deleteWeight(at offsets: IndexSet) {
        for index in offsets {
            store.deleteWeight(sortedWeights[index])
        }
    }

    private func deleteMeasurement(at offsets: IndexSet) {
        for index in offsets {
            store.deleteMeasurement(sortedMeasurements[index])
        }
    }
}

/// 带「+」按钮的分组标题
private struct SectionHeaderWithAdd: View {
    let title: String
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
            }
        }
    }
}

/// 围度单行：日期 + 关键数值摘要
private struct MeasurementRow: View {
    let record: BodyMeasurementRecord

    private var summary: String {
        var parts: [String] = []
        if !record.waistCm.isEmpty { parts.append("腰 \(record.waistCm)") }
        if !record.hipCm.isEmpty { parts.append("臀 \(record.hipCm)") }
        if !record.bodyFatPercent.isEmpty { parts.append("体脂 \(record.bodyFatPercent)%") }
        return parts.joined(separator: "  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.date)
                .font(.headline)
            if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
