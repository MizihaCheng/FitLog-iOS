import SwiftUI

private enum RecordDateRange: String, CaseIterable {
    case all, last7, last30, thisWeek, thisMonth
    var label: String {
        switch self {
        case .all: return "全部"
        case .last7: return "最近 7 天"
        case .last30: return "最近 30 天"
        case .thisWeek: return "本周"
        case .thisMonth: return "本月"
        }
    }
}

private enum RecordDataType: String, CaseIterable {
    case all, hasWeight, hasTraining, hasMeasurement
    var label: String {
        switch self {
        case .all: return "全部日期"
        case .hasWeight: return "有体重记录"
        case .hasTraining: return "有训练记录"
        case .hasMeasurement: return "有围度记录"
        }
    }
}

private struct DayGroup {
    let date: String
    let weight: DailyWeightRecord?
    let measurement: BodyMeasurementRecord?
    let trainings: [TrainingRecord]
}

struct RecordsView: View {
    @EnvironmentObject var store: FitStore

    @State private var keyword = ""
    @State private var dateRange: RecordDateRange = .all
    @State private var trainingType = "全部"
    @State private var dataType: RecordDataType = .all
    @State private var showFilters = false
    @State private var detailDay: DayKey?

    private let dateParser: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if showFilters {
                filterPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
                Text("每日记录").font(.headline).foregroundStyle(Color.fitPrimaryText)
                Spacer()
                Text("显示 \(filteredGroups.count) 天 / 共 \(allGroups.count) 天")
                    .font(.caption).foregroundStyle(Color.fitSecondaryText)
            }
            .padding(.horizontal, 20).padding(.vertical, 8)

            if allGroups.isEmpty {
                emptyHint("还没有记录，先保存今天的一条吧。")
            } else if filteredGroups.isEmpty {
                emptyHint("暂无符合条件的记录")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredGroups, id: \.date) { group in
                            DailyRecordCard(group: group, setsProvider: { store.sets(for: $0) })
                                .onTapGesture { detailDay = DayKey(id: group.date) }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }
            }
        }
        .background(Color.fitBackground.ignoresSafeArea())
        .sheet(item: $detailDay) { day in DayDetailView(date: day.id) }
    }

    // MARK: - 搜索栏

    private var activeFilterCount: Int {
        [!keyword.isEmpty, dateRange != .all, trainingType != "全部", dataType != .all].filter { $0 }.count
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.fitSecondaryText)
                TextField("搜索备注或训练类型", text: $keyword)
            }
            .padding(10)
            .background(Color.fitCardSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fitDivider, lineWidth: 1))

            Button { withAnimation(.easeInOut(duration: 0.22)) { showFilters.toggle() } } label: {
                ZStack(alignment: .topTrailing) {
                    Text(showFilters ? "收起" : "筛选")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.fitAccent)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 10)).foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.fitAccent, in: Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: - 筛选面板

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            filterGroup(title: "时间范围") {
                ForEach(RecordDateRange.allCases, id: \.self) { range in
                    chip(range.label, selected: dateRange == range) { dateRange = range }
                }
            }
            filterGroup(title: "训练类型") {
                chip("全部", selected: trainingType == "全部") { trainingType = "全部" }
                ForEach(StrengthBodyParts + CardioTrainingTypes, id: \.self) { type in
                    chip(type, selected: trainingType == type) { trainingType = type }
                }
            }
            filterGroup(title: "数据类型") {
                ForEach(RecordDataType.allCases, id: \.self) { dt in
                    chip(dt.label, selected: dataType == dt) { dataType = dt }
                }
            }
            Button {
                keyword = ""; dateRange = .all; trainingType = "全部"; dataType = .all
            } label: {
                Text("清除筛选").font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.fitAccent)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fitDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 14)
    }

    private func filterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(Color.fitSecondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
            }
        }
    }

    private func chip(_ text: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(text)
                .font(.caption)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? .white : Color.fitPrimaryText)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.fitAccent : Color.fitCardSurface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Color.fitDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - 分组 + 筛选

    private var allGroups: [DayGroup] {
        let dates = Set(store.weightRecords.map { $0.date }
                        + store.trainingRecords.map { $0.date }
                        + store.measurements.map { $0.date })
            .filter { !$0.isEmpty }
        return dates.map { date in
            DayGroup(
                date: date,
                weight: store.weightRecords.first { $0.date == date },
                measurement: store.measurements.first { $0.date == date },
                trainings: store.trainingRecords.filter { $0.date == date }.sorted { $0.time > $1.time }
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var filteredGroups: [DayGroup] {
        allGroups.filter { group in
            matchesKeyword(group) && matchesDateRange(group) && matchesTrainingType(group) && matchesDataType(group)
        }
    }

    private func matchesKeyword(_ group: DayGroup) -> Bool {
        let q = keyword.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return group.trainings.contains { record in
            record.displayTitle.localizedCaseInsensitiveContains(q)
                || record.trainingType.localizedCaseInsensitiveContains(q)
                || record.note.localizedCaseInsensitiveContains(q)
        }
    }

    private func matchesDateRange(_ group: DayGroup) -> Bool {
        guard dateRange != .all, let date = dateParser.date(from: group.date) else { return true }
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        switch dateRange {
        case .all: return true
        case .last7: return date >= calendar.date(byAdding: .day, value: -7, to: now)!
        case .last30: return date >= calendar.date(byAdding: .day, value: -30, to: now)!
        case .thisWeek: return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }
    }

    private func matchesTrainingType(_ group: DayGroup) -> Bool {
        guard trainingType != "全部" else { return true }
        return group.trainings.contains { $0.trainingType == trainingType || $0.bodyParts.contains(trainingType) }
    }

    private func matchesDataType(_ group: DayGroup) -> Bool {
        switch dataType {
        case .all: return true
        case .hasWeight: return group.weight != nil
        case .hasTraining: return !group.trainings.isEmpty
        case .hasMeasurement: return group.measurement != nil
        }
    }
}

// MARK: - 每日卡片

private struct DailyRecordCard: View {
    let group: DayGroup
    let setsProvider: (UUID) -> [ExerciseSet]

    private var weightText: String {
        if let w = group.weight, !w.weightKg.isEmpty { return "\(w.weightKg) kg" }
        return "未记录"
    }

    /// 训练动作摘要（对应 Android trainingActionSummary）
    private var summary: (primary: String, detail: String?)? {
        guard !group.trainings.isEmpty else { return nil }
        var names: [String] = []
        for record in group.trainings {
            let sets = setsProvider(record.id)
            if sets.isEmpty {
                let title = record.displayTitle
                if !title.isEmpty && !names.contains(title) { names.append(title) }
            } else {
                for set in sets where !names.contains(set.exerciseName) {
                    names.append(set.exerciseName)
                }
            }
        }
        if names.isEmpty {
            let minutes = group.trainings.compactMap { $0.durationMin }.reduce(0, +)
            var text = "\(group.trainings.count) 次"
            if minutes > 0 { text += " · \(minutes) min" }
            return (text, nil)
        }
        let visible = names.prefix(3).joined(separator: "、")
        return ("\(group.trainings.count) 次训练", visible + (names.count > 3 ? " 等" : ""))
    }

    private var measurementSummary: String? {
        guard let m = group.measurement else { return nil }
        var parts: [String] = []
        if !m.waistCm.isEmpty { parts.append("腰 \(m.waistCm)") }
        if !m.hipCm.isEmpty { parts.append("臀 \(m.hipCm)") }
        if !m.bodyFatPercent.isEmpty { parts.append("体脂 \(m.bodyFatPercent)%") }
        return parts.isEmpty ? nil : "围度：" + parts.joined(separator: "  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.date).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
                Spacer()
                Text("当天详情 →").font(.caption).fontWeight(.medium).foregroundStyle(Color.fitAccent)
            }
            HStack(spacing: 4) {
                Text("体重:").font(.caption).foregroundStyle(Color.fitSecondaryText)
                Text(weightText).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
            }
            if let summary {
                Text(summary.primary).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
                if let detail = summary.detail {
                    Text(detail).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                }
            }
            if let measurementSummary {
                Text(measurementSummary).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            }
        }
        .fitCard()
        .contentShape(Rectangle())
    }
}
