import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: FitStore
    @State private var showingAdd = false

    /// 今天的日期，格式 yyyy-MM-dd
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// 只取今天的训练记录，按时间倒序
    private var todayRecords: [TrainingRecord] {
        store.trainingRecords
            .filter { $0.date == todayString }
            .sorted { $0.time > $1.time }
    }

    var body: some View {
        NavigationStack {
            Group {
                if todayRecords.isEmpty {
                    ContentUnavailableView(
                        "今天还没有训练记录",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("点右上角 + 添加一条")
                    )
                } else {
                    List {
                        ForEach(todayRecords) { record in
                            NavigationLink {
                                WorkoutDetailView(record: record)
                            } label: {
                                TrainingRow(record: record)
                            }
                        }
                        .onDelete(perform: delete)
                        .fitCardRow()
                    }
                    .fitListChrome()
                }
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("今日")
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
                AddTrainingView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.deleteTrainingRecord(todayRecords[index])
        }
    }
}

/// 单条训练记录的展示行
private struct TrainingRow: View {
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
