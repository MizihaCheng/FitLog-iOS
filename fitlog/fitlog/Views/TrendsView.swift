import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var store: FitStore

    /// 可绘制的体重点（按日期升序）
    private var weightPoints: [WeightPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return store.weightRecords.compactMap { record in
            guard let date = formatter.date(from: record.date),
                  let weight = Double(record.weightKg) else { return nil }
            return WeightPoint(date: date, weight: weight)
        }
        .sorted { $0.date < $1.date }
    }

    private var targetWeight: Double? {
        Double(store.goal.targetWeightKg)
    }

    /// 本周训练次数（周一为一周起点）
    private var thisWeekCount: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return store.trainingRecords.filter { record in
            guard let date = formatter.date(from: record.date) else { return false }
            return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("体重趋势") {
                    if weightPoints.count < 2 {
                        Text("体重数据不足，去「我的」多记几天体重就能看到曲线")
                            .foregroundStyle(.secondary)
                    } else {
                        weightChart
                            .frame(height: 240)
                            .padding(.vertical, 8)
                    }
                }

                Section("统计") {
                    if let latest = weightPoints.last {
                        LabeledContent("最新体重", value: "\(trimmed(latest.weight)) kg")
                    }
                    if let change = weightChange {
                        LabeledContent("相比起始", value: change)
                    }
                    LabeledContent("训练总次数", value: "\(store.trainingRecords.count) 次")
                    LabeledContent("本周训练", value: "\(thisWeekCount) 次")
                }
            }
            .navigationTitle("趋势")
        }
    }

    private var weightChart: some View {
        Chart {
            ForEach(weightPoints) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("体重", point.weight)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日期", point.date),
                    y: .value("体重", point.weight)
                )
            }

            if let target = targetWeight {
                RuleMark(y: .value("目标", target))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("目标 \(trimmed(target))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    /// 起始体重到最新体重的变化，如「-1.5 kg」
    private var weightChange: String? {
        guard let first = weightPoints.first, let last = weightPoints.last, weightPoints.count >= 2 else {
            return nil
        }
        let delta = last.weight - first.weight
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(trimmed(delta)) kg"
    }

    /// 去掉多余小数：60.0 -> 60，62.5 -> 62.5
    private func trimmed(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

struct WeightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}
