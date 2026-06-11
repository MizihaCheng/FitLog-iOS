import Foundation

/// 训练大类（对应 Android StatsUtils 的 strength/cardio/rest）
enum TrainingCategory: String, CaseIterable {
    case strength
    case cardio
    case rest

    var label: String {
        switch self {
        case .strength: return "力量"
        case .cardio: return "有氧"
        case .rest: return "拉伸"
        }
    }
}

/// 力量 / 拉伸可多选的部位
let StrengthBodyParts = ["胸", "背", "肩", "二头", "三头", "腿", "臀", "核心", "其他"]

/// 有氧项目
let CardioTrainingTypes = ["跑步", "游泳", "骑行", "椭圆机", "其他有氧"]
