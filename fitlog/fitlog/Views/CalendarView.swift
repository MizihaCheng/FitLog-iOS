import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: FitStore

    @State private var monthAnchor = Date()      // 当前显示月份内的任意一天
    @State private var selectedDate: Date = Date()

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // 周一
        return c
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 有训练记录的日期字符串集合
    private var trainingDays: Set<String> {
        Set(store.trainingRecords.map { $0.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    weekdayRow
                    grid
                    selectedDayList
                }
                .padding()
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("日历")
        }
    }

    // MARK: - 顶部月份切换

    private var header: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 月历网格

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dayString = dateFormatter.string(from: date)
        let hasTraining = trainingDays.contains(dayString)
        let isSelected = calendar.isDate(selectedDate, inSameDayAs: date)
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout)
                .frame(width: 34, height: 34)
                .background(
                    isSelected ? Color.accentColor
                        : (isToday ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .clipShape(Circle())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Circle()
                .fill(hasTraining ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = date }
    }

    // MARK: - 选中日期的训练列表

    @ViewBuilder
    private var selectedDayList: some View {
        let dayString = dateFormatter.string(from: selectedDate)
        let records = store.trainingRecords
            .filter { $0.date == dayString }
            .sorted { $0.time > $1.time }

        VStack(alignment: .leading, spacing: 8) {
            Text(selectedTitle)
                .font(.headline)

            if records.isEmpty {
                Text("这天没有训练记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        WorkoutDetailView(record: record)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.trainingType)
                                if !record.note.isEmpty {
                                    Text(record.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(record.time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if record.id != records.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.fitCardSurface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 计算

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstOfMonth = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) {
                result.append(date)
            }
        }
        return result
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: monthAnchor)
    }

    private var selectedTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f.string(from: selectedDate)
    }

    private func changeMonth(_ delta: Int) {
        if let newAnchor = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = newAnchor
        }
    }
}
