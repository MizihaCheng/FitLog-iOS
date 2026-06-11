import SwiftUI
import Charts

private enum ReviewRange { case week, month }

private enum BodyMetric: String, CaseIterable {
    case waist, hip, thigh, chest, arm, bodyFat
    var label: String {
        switch self {
        case .waist: return "腰围"
        case .hip: return "臀围"
        case .thigh: return "大腿"
        case .chest: return "胸围"
        case .arm: return "臂围"
        case .bodyFat: return "体脂率"
        }
    }
    func value(_ m: BodyMeasurementRecord) -> String {
        switch self {
        case .waist: return m.waistCm
        case .hip: return m.hipCm
        case .thigh: return m.thighCm
        case .chest: return m.chestCm
        case .arm: return m.armCm
        case .bodyFat: return m.bodyFatPercent
        }
    }
}

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendsView: View {
    @EnvironmentObject var store: FitStore

    @State private var range: ReviewRange = .week
    @State private var metric: BodyMetric = .waist

    private let dateParser: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                weightCard
                reviewCard
                bodyCard
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
        }
        .background(Color.fitBackground.ignoresSafeArea())
    }

    // MARK: - 体重趋势

    private var weightPoints: [ChartPoint] {
        store.weightRecords.compactMap { r in
            guard let d = dateParser.date(from: r.date), let v = Double(r.weightKg) else { return nil }
            return ChartPoint(date: d, value: v)
        }.sorted { $0.date < $1.date }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("体重趋势").font(.headline).foregroundStyle(Color.fitPrimaryText)
            if weightPoints.count < 2 {
                Text("暂无数据").font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            } else {
                Chart(weightPoints) { p in
                    LineMark(x: .value("日期", p.date), y: .value("体重", p.value))
                        .foregroundStyle(Color.fitAccent)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("日期", p.date), y: .value("体重", p.value))
                        .foregroundStyle(Color.fitAccent)
                }
                .chartYScale(domain: weightYDomain)
                .frame(height: 220)
            }
        }
        .fitCard()
    }

    private var weightYDomain: ClosedRange<Double> {
        let vals = weightPoints.map { $0.value }
        guard let lo = vals.min(), let hi = vals.max() else { return 0...1 }
        let pad = (hi - lo < 0.5) ? 1.0 : 2.0
        return (lo - pad)...(hi + pad)
    }

    // MARK: - 统计复盘

    private var reviewCard: some View {
        let s = stats
        return VStack(alignment: .leading, spacing: 14) {
            Text("统计复盘").font(.headline).foregroundStyle(Color.fitPrimaryText)
            HStack(spacing: 10) {
                rangeButton("本周", .week)
                rangeButton("本月", .month)
            }
            if !s.hasAnyData {
                Text("暂无数据").font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            } else {
                HStack(spacing: 10) {
                    statCell("\(s.weightDays) 天", "体重记录")
                    statCell("\(s.trainingCount) 次", "训练次数")
                }
                HStack(spacing: 10) {
                    statCell("\(s.strengthSets) 组", "力量总组数")
                    statCell("\(s.cardioMinutes) min", "有氧总时长")
                }
                HStack(spacing: 10) {
                    statCell(s.weightChange.text, "体重变化", valueColor: s.weightChange.color)
                    statCell(s.mostCommon, "最常训练")
                }
                if s.distribution.contains(where: { $0.count > 0 }) {
                    Text("训练类型分布").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
                        .padding(.top, 6)
                    ForEach(s.distribution.filter { $0.count > 0 }.sorted { $0.count > $1.count }, id: \.type) { item in
                        HStack {
                            Text(item.type).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                            Spacer()
                            Text("\(item.count) 次").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .fitCard()
    }

    private func rangeButton(_ text: String, _ value: ReviewRange) -> some View {
        let selected = range == value
        return Button { range = value } label: {
            Text(text).font(.subheadline).fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? .white : Color.fitAccent)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(selected ? Color.fitAccent : Color.fitCardSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.clear : Color.fitDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statCell(_ value: String, _ label: String, valueColor: Color = .fitPrimaryText) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(valueColor).multilineTextAlignment(.center)
            Text(label).font(.caption2).foregroundStyle(Color.fitSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.fitBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private struct Stats {
        var weightDays = 0
        var trainingCount = 0
        var strengthSets = 0
        var cardioMinutes = 0
        var weightChange: (text: String, color: Color) = ("—", .fitPrimaryText)
        var mostCommon = "暂无"
        var distribution: [(type: String, count: Int)] = []
        var hasAnyData = false
    }

    private var stats: Stats {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let now = Date()
        let start: Date
        let end: Date
        if range == .week {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            start = calendar.date(from: comps) ?? now
            end = calendar.date(byAdding: .day, value: 6, to: start) ?? now
        } else {
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let dayCount = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            end = calendar.date(byAdding: .day, value: dayCount - 1, to: start) ?? now
        }
        func inRange(_ ds: String) -> Bool {
            guard let d = dateParser.date(from: ds) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: end)
        }

        let weightsInRange = weightPoints.filter { inRange(dateParser.string(from: $0.date)) }
        let trainingsInRange = store.trainingRecords.filter { inRange($0.date) }

        var s = Stats()
        s.weightDays = weightsInRange.count
        s.trainingCount = trainingsInRange.count
        s.strengthSets = trainingsInRange.filter { $0.trainingCategory == TrainingCategory.strength.rawValue }
            .reduce(0) { $0 + store.sets(for: $1.id).count }
        s.cardioMinutes = trainingsInRange.filter { $0.trainingCategory == TrainingCategory.cardio.rawValue }
            .reduce(0) { $0 + ($1.durationMin ?? 0) }

        let labels = StrengthBodyParts + CardioTrainingTypes
        s.distribution = labels.map { label in
            (label, trainingsInRange.filter { $0.trainingType == label || $0.bodyParts.contains(label) }.count)
        }
        s.mostCommon = s.distribution.filter { $0.count > 0 }.max { $0.count < $1.count }?.type ?? "暂无"

        if weightsInRange.count >= 2, let first = weightsInRange.first, let last = weightsInRange.last {
            let delta = last.value - first.value
            if delta < 0 {
                s.weightChange = ("-\(fitFormatWeight(abs(delta))) kg", .fitPositiveGreen)
            } else if delta > 0 {
                s.weightChange = ("+\(fitFormatWeight(delta)) kg", .fitWarningRed)
            } else {
                s.weightChange = ("0 kg", .fitPrimaryText)
            }
        }
        s.hasAnyData = !weightsInRange.isEmpty || !trainingsInRange.isEmpty
        return s
    }

    // MARK: - 围度趋势

    private var bodyPoints: [ChartPoint] {
        store.measurements.compactMap { m in
            guard let d = dateParser.date(from: m.date), let v = Double(metric.value(m)) else { return nil }
            return ChartPoint(date: d, value: v)
        }.sorted { $0.date < $1.date }
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("围度趋势").font(.headline).foregroundStyle(Color.fitPrimaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BodyMetric.allCases, id: \.self) { m in
                        let selected = metric == m
                        Button { metric = m } label: {
                            Text(m.label).font(.caption).fontWeight(selected ? .semibold : .regular)
                                .foregroundStyle(selected ? .white : Color.fitPrimaryText)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selected ? Color.fitAccent : Color.fitCardSurface, in: Capsule())
                                .overlay(Capsule().stroke(selected ? Color.clear : Color.fitDivider, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if bodyPoints.count < 2 {
                Text("暂无数据").font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            } else {
                Chart(bodyPoints) { p in
                    LineMark(x: .value("日期", p.date), y: .value(metric.label, p.value))
                        .foregroundStyle(Color.fitPositiveGreen)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("日期", p.date), y: .value(metric.label, p.value))
                        .foregroundStyle(Color.fitPositiveGreen)
                }
                .frame(height: 220)
            }
        }
        .fitCard()
    }
}
