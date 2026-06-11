import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: FitStore

    @State private var monthAnchor = Date()
    @State private var detailDay: DayKey?

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var weightDates: Set<String> { Set(store.weightRecords.map { $0.date }) }
    private var trainingDates: Set<String> { Set(store.trainingRecords.map { $0.date }) }
    private var measurementDates: Set<String> { Set(store.measurements.map { $0.date }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                weekdayRow
                grid
                legend
            }
            .fitCard()
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.fitBackground.ignoresSafeArea())
        .sheet(item: $detailDay) { day in
            DayDetailView(date: day.id)
        }
    }

    // MARK: - 月份头

    private var header: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Text("〈").font(.title2).foregroundStyle(Color.fitAccent)
            }
            Spacer()
            Text(monthTitle).font(.headline).foregroundStyle(Color.fitPrimaryText)
            Spacer()
            Button { changeMonth(1) } label: {
                Text("〉").font(.title2).foregroundStyle(Color.fitAccent)
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 2) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                Text(day)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.fitSecondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 网格

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 62)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let ds = dateFormatter.string(from: date)
        let hasWeight = weightDates.contains(ds)
        let hasTraining = trainingDates.contains(ds)
        let hasMeasurement = measurementDates.contains(ds)
        let hasRecord = hasWeight || hasTraining || hasMeasurement
        let isToday = calendar.isDateInToday(date)

        let bg: Color = isToday ? .fitAccent : (hasRecord ? Color.fitAccent.opacity(0.12) : Color.fitCardSurface)
        let dateColor: Color = isToday ? .white : .fitPrimaryText
        let borderColor: Color = isToday ? .clear : (hasRecord ? Color.fitAccent.opacity(0.25) : Color.fitDivider)

        return VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline).fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(dateColor)
            HStack(spacing: 3) {
                if hasWeight { dot(.fitAccent) }
                if hasTraining { dot(.fitTrainingBlue) }
                if hasMeasurement { dot(.fitPositiveGreen) }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(bg, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { detailDay = DayKey(id: ds) }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    // MARK: - 图例

    private var legend: some View {
        HStack(spacing: 20) {
            Spacer()
            legendItem(.fitAccent, "体重")
            legendItem(.fitTrainingBlue, "训练")
            legendItem(.fitPositiveGreen, "围度")
            Spacer()
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            dot(color)
            Text(label).font(.caption).foregroundStyle(Color.fitSecondaryText)
        }
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

    private func changeMonth(_ delta: Int) {
        if let newAnchor = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = newAnchor
        }
    }
}

/// 用于 sheet(item:) 的日期包装
struct DayKey: Identifiable {
    let id: String
}
