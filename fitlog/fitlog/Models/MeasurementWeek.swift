import Foundation

/// 把日期字符串归一到「本周一」（周起始），对应 Android `LocalDate.weekStart()`。
/// 围度是一周一测、管一整周，所以所有「某天的围度」查询都按周匹配。
func fitWeekStart(of dateString: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: dateString) else { return dateString }
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2 // 周一
    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    guard let start = calendar.date(from: comps) else { return dateString }
    return parser.string(from: start)
}

extension BodyMeasurementRecord {
    /// 归一化周起始：优先用已存的 weekStartDate，否则由 date 推算。
    /// 对应 Android `normalizedWeekStartDate()`。
    var normalizedWeekStart: String {
        weekStartDate.isEmpty ? fitWeekStart(of: date) : weekStartDate
    }
}
