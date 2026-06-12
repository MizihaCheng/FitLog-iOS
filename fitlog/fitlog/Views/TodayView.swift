import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: FitStore

    @State private var showingWeight = false
    @State private var showingTraining = false
    @State private var showingMeasurement = false
    @State private var showingSummary = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TodayHeader(todayDate: todayString)

                GoalProgressCard(
                    currentWeight: currentWeight,
                    startWeight: startWeight,
                    targetWeight: targetWeight,
                    progress: progress,
                    streakDays: weightStreakDays,
                    changeText: changeText,
                    daysAgoText: daysAgoText,
                    goal: store.goal
                )

                CheckInRow(
                    weightDone: todayWeightRecorded,
                    trainingDone: todayTrainingRecorded,
                    measurementDone: thisWeekMeasurementRecorded,
                    onWeight: { showingWeight = true },
                    onTraining: { showingTraining = true },
                    onMeasurement: { showingMeasurement = true }
                )

                QuickRecordCard(
                    highlightWeight: !todayWeightRecorded,
                    onWeight: { showingWeight = true },
                    onTraining: { showingTraining = true }
                )

                TodayTrainingListCard(
                    records: todayTrainings,
                    setsProvider: { store.sets(for: $0) },
                    recoveryProvider: { store.recovery(forWorkout: $0) },
                    onDelete: { store.deleteTrainingRecord($0) }
                )

                if summaryDate != nil {
                    Button { showingSummary = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("AI 训练总结")
                        }
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.fitAccent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.fitBackground.ignoresSafeArea())
        .sheet(isPresented: $showingWeight) { WeightEntryView() }
        .sheet(isPresented: $showingTraining) { StructuredTrainingEntryView() }
        .sheet(isPresented: $showingMeasurement) { MeasurementEntryView() }
        .sheet(isPresented: $showingSummary) {
            TodaySummaryView(date: summaryDate ?? todayString).environmentObject(store)
        }
    }

    /// 要总结的训练日：今天有训练就今天，否则取最近一次有训练的日期；都没有则 nil（不显示按钮）。
    private var summaryDate: String? {
        if !todayTrainings.isEmpty { return todayString }
        return store.trainingRecords.map(\.date).max()
    }

    // MARK: - 计算

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayTrainings: [TrainingRecord] {
        store.trainingRecords.filter { $0.date == todayString }.sorted { $0.time > $1.time }
    }

    private var latestWeight: DailyWeightRecord? {
        store.weightRecords.max { $0.date < $1.date }
    }
    private var currentWeight: Double? { latestWeight.flatMap { Double($0.weightKg) } }
    private var startWeight: Double? { Double(store.goal.startWeight) }
    private var targetWeight: Double? { Double(store.goal.targetWeightKg) }

    private var progress: Double? {
        guard let s = startWeight, let c = currentWeight, let t = targetWeight, abs(s - t) > 0.01 else { return nil }
        return min(max((s - c) / (s - t), 0), 1)
    }

    private var weightDates: Set<String> { Set(store.weightRecords.map { $0.date }) }

    private var todayWeightRecorded: Bool { weightDates.contains(todayString) }
    private var todayTrainingRecorded: Bool { store.trainingRecords.contains { $0.date == todayString } }

    private var thisWeekMeasurementRecorded: Bool {
        let (start, end) = weekRange(for: Date())
        return store.measurements.contains { $0.date >= start && $0.date <= end }
    }

    /// 连续记录体重天数：从今天往前数连续在册的天
    private var weightStreakDays: Int {
        let calendar = Calendar(identifier: .gregorian)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var count = 0
        var cursor = Date()
        while weightDates.contains(f.string(from: cursor)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// 今日体重相对昨日的变化文本（↓绿/↑红）
    private var changeText: (text: String, color: Color)? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar(identifier: .gregorian)
        guard let todayW = Double(store.weightRecords.first { $0.date == todayString }?.weightKg ?? ""),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
              let yesterdayW = Double(store.weightRecords.first { $0.date == f.string(from: yesterday) }?.weightKg ?? "")
        else {
            return nil
        }
        let change = todayW - yesterdayW
        if change < 0 {
            return ("↓ \(fitFormatWeight(abs(change))) kg", .fitPositiveGreen)
        } else if change > 0 {
            return ("↑ \(fitFormatWeight(abs(change))) kg", .fitWarningRed)
        } else {
            return ("0 kg", .fitSecondaryText)
        }
    }

    /// 最近一次体重距今天数（用于未记录提示）
    private var daysAgoText: String? {
        guard !todayWeightRecorded, let latest = latestWeight else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar(identifier: .gregorian)
        guard let latestDate = f.date(from: latest.date),
              let days = calendar.dateComponents([.day], from: latestDate, to: Date()).day,
              days > 0 else { return nil }
        return "\(days)天前"
    }

    private func weekRange(for date: Date) -> (String, String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let start = calendar.date(from: comps),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            let today = f.string(from: date)
            return (today, today)
        }
        return (f.string(from: start), f.string(from: end))
    }
}

// MARK: - 头部

private struct TodayHeader: View {
    let todayDate: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FitLog")
                    .font(.title2).bold()
                    .foregroundStyle(Color.fitPrimaryText)
                Text("今日记录")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitSecondaryText)
            }
            Spacer()
            Text(displayChineseDate(todayDate))
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(Color.fitSecondaryText)
        }
    }
}

// MARK: - 目标进度环

private struct GoalProgressCard: View {
    let currentWeight: Double?
    let startWeight: Double?
    let targetWeight: Double?
    let progress: Double?
    let streakDays: Int
    let changeText: (text: String, color: Color)?
    let daysAgoText: String?
    let goal: GoalRecord

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("连续 \(streakDays) 天")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.fitAccent)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.fitAccent.opacity(0.16), in: Capsule())
            }

            ZStack {
                Circle()
                    .stroke(Color.fitDivider, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                Circle()
                    .trim(from: 0, to: progress ?? 0)
                    .stroke(Color.fitAccent, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(currentWeight.map { "\(fitFormatWeight($0)) kg" } ?? "-- kg")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.fitPrimaryText)
                    subtitle
                }
            }
            .frame(width: 214, height: 214)
            .padding(.top, 6)

            HStack {
                GoalMetric(label: "起始", value: goal.startWeight.isEmpty ? "--" : "\(goal.startWeight) kg")
                Spacer()
                GoalMetric(label: "已完成", value: progress.map { "\(Int($0 * 100))%" } ?? "--")
                Spacer()
                GoalMetric(label: "目标", value: goal.targetWeightKg.isEmpty ? "--" : "\(goal.targetWeightKg) kg")
            }
            .padding(.top, 18)
        }
        .fitCard()
    }

    @ViewBuilder
    private var subtitle: some View {
        if startWeight == nil || targetWeight == nil {
            Text("未设置目标")
                .font(.subheadline)
                .foregroundStyle(Color.fitSecondaryText)
        } else if let daysAgoText {
            Text(daysAgoText)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.fitAccent)
        } else if let changeText {
            Text(changeText.text)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(changeText.color)
        } else {
            Text("暂无昨日对比")
                .font(.subheadline)
                .foregroundStyle(Color.fitSecondaryText)
        }
    }
}

private struct GoalMetric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Color.fitSecondaryText)
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
        }
    }
}

// MARK: - 打卡行

private struct CheckInRow: View {
    let weightDone: Bool
    let trainingDone: Bool
    let measurementDone: Bool
    let onWeight: () -> Void
    let onTraining: () -> Void
    let onMeasurement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CheckInMiniCard(title: "今日体重", recorded: weightDone, onTap: onWeight)
            CheckInMiniCard(title: "今日训练", recorded: trainingDone, onTap: onTraining)
            CheckInMiniCard(title: "本周围度", recorded: measurementDone, onTap: onMeasurement)
        }
    }
}

private struct CheckInMiniCard: View {
    let title: String
    let recorded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                StatusCircle(recorded: recorded)
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.fitPrimaryText)
                Text(recorded ? "已记录" : "未记录")
                    .font(.caption2)
                    .foregroundStyle(recorded ? Color.fitPositiveGreen : Color.fitSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .fitCard(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct StatusCircle: View {
    let recorded: Bool
    var body: some View {
        ZStack {
            if recorded {
                Circle().fill(Color.fitPositiveGreen)
                Text("✓").font(.headline).bold().foregroundStyle(.white)
            } else {
                Circle().stroke(
                    Color.fitTertiaryText,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                )
            }
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - 快速记录

private struct QuickRecordCard: View {
    let highlightWeight: Bool
    let onWeight: () -> Void
    let onTraining: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("快速记录").font(.headline).foregroundStyle(Color.fitPrimaryText)
            HStack(spacing: 10) {
                QuickActionButton(subtitle: "体重", title: "记录/更新", color: .fitAccent, onTap: onWeight)
                QuickActionButton(subtitle: "训练", title: "添加训练", color: .fitTrainingBlue, onTap: onTraining)
            }
        }
        .fitCard()
    }
}

private struct QuickActionButton: View {
    let subtitle: String
    let title: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(subtitle).font(.subheadline).fontWeight(.semibold)
                Text(title).font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 今日训练列表

private struct TodayTrainingListCard: View {
    let records: [TrainingRecord]
    let setsProvider: (UUID) -> [ExerciseSet]
    let recoveryProvider: (UUID) -> HeartRateRecovery?
    let onDelete: (TrainingRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日训练").font(.headline).foregroundStyle(Color.fitPrimaryText)
            if records.isEmpty {
                Text("今天还没有训练记录")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitSecondaryText)
            } else {
                ForEach(records) { record in
                    TrainingRecordItem(
                        record: record,
                        sets: setsProvider(record.id),
                        recovery: recoveryProvider(record.id),
                        onDelete: { onDelete(record) }
                    )
                }
            }
        }
        .fitCard()
    }
}

/// 一条训练记录卡片（含按动作分组的组数据 + 删除）
struct TrainingRecordItem: View {
    let record: TrainingRecord
    let sets: [ExerciseSet]
    var recovery: HeartRateRecovery? = nil
    let onDelete: () -> Void

    private var grouped: [(name: String, sets: [ExerciseSet])] {
        var order: [String] = []
        var map: [String: [ExerciseSet]] = [:]
        for set in sets {
            if map[set.exerciseName] == nil { order.append(set.exerciseName) }
            map[set.exerciseName, default: []].append(set)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.displayTitle)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.fitAccent)
                Spacer()
                if !record.metricText.isEmpty {
                    Text(record.metricText)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(Color.fitSecondaryText)
                }
            }
            if let rec = recovery {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Color.fitHeartCoral)
                    Text("\(rec.peakBpm)→\(rec.endBpm)")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.fitHeartCoral)
                    Text("↓\(rec.recoveryDrop)").font(.caption2).foregroundStyle(Color.fitSecondaryText)
                    RecoverySparkline(samples: rec.samples)
                        .stroke(Color.fitHeartCoral, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                        .frame(width: 56, height: 18)
                    Spacer()
                }
            }
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.subheadline)
                    .foregroundStyle(Color.fitSecondaryText)
            }
            ForEach(grouped, id: \.name) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.fitPrimaryText)
                    ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1).  \(set.detailSetText)")
                                .font(.subheadline)
                                .foregroundStyle(Color.fitPrimaryText)
                            if let note = set.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.fitSecondaryText)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Text("删除").font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.fitWarningRed)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fitBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 心率恢复迷你曲线（训练记录里的小 sparkline）
struct RecoverySparkline: Shape {
    let samples: [HeartRateSample]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count >= 2 else { return path }
        let ts = samples.map { Double($0.t) }
        let bpms = samples.map { Double($0.bpm) }
        let minT = ts.min() ?? 0, maxT = ts.max() ?? 1
        let minB = bpms.min() ?? 0, maxB = bpms.max() ?? 1
        let spanT = max(maxT - minT, 1), spanB = max(maxB - minB, 1)
        for (i, s) in samples.enumerated() {
            let x = rect.minX + CGFloat((Double(s.t) - minT) / spanT) * rect.width
            let y = rect.maxY - CGFloat((Double(s.bpm) - minB) / spanB) * rect.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

// MARK: - 中文日期

func displayChineseDate(_ dateString: String) -> String {
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    let date = parser.date(from: dateString) ?? Date()
    let display = DateFormatter()
    display.locale = Locale(identifier: "zh_CN")
    display.dateFormat = "yyyy-MM-dd EEE"
    return display.string(from: date)
}
