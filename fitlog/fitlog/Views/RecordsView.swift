import SwiftUI

struct RecordsView: View {
    @EnvironmentObject var store: FitStore

    /// 按日期分组，日期倒序；每组内按时间倒序
    private var groupedByDate: [(date: String, records: [TrainingRecord])] {
        let groups = Dictionary(grouping: store.trainingRecords) { $0.date }
        return groups.keys.sorted(by: >).map { date in
            let records = (groups[date] ?? []).sorted { $0.time > $1.time }
            return (date: date, records: records)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.trainingRecords.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "list.bullet.rectangle",
                        description: Text("在「今日」页添加训练后，这里会显示全部历史")
                    )
                } else {
                    List {
                        ForEach(groupedByDate, id: \.date) { group in
                            Section(header: Text(sectionTitle(group.date))) {
                                ForEach(group.records) { record in
                                    RecordRow(record: record)
                                }
                                .onDelete { offsets in
                                    delete(offsets, in: group.records)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("记录")
        }
    }

    /// 把 yyyy-MM-dd 显示成「2026年6月11日 周三」这样更友好的标题
    private func sectionTitle(_ date: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let parsed = parser.date(from: date) else { return date }
        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "yyyy年M月d日 EEE"
        return display.string(from: parsed)
    }

    private func delete(_ offsets: IndexSet, in records: [TrainingRecord]) {
        for index in offsets {
            store.deleteTrainingRecord(records[index])
        }
    }
}

/// 历史记录单行
private struct RecordRow: View {
    let record: TrainingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.trainingType)
                    .font(.headline)
                Spacer()
                Text(record.time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let duration = record.durationMin {
                Text("\(duration) 分钟")
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
