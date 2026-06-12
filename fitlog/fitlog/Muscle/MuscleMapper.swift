import Foundation

/// 主练 / 辅练 两档强度
enum Intensity {
    case primary
    case secondary
}

/// 一段训练：部位标签 + 动作名（动作名用于消歧，可空）
struct Segment {
    let part: String
    let exercise: String

    init(part: String, exercise: String = "") {
        self.part = part
        self.exercise = exercise
    }
}

/// 把「部位 + 动作名」映射到肌肉 slug。
/// 优先用部位词；「上肢/其他力量」等笼统标签靠动作名关键词消歧
/// （如 上肢+Pulldown => 练背）。对应 Android MuscleMapper。
enum MuscleMapper {

    // 肌群 -> (主练 slug, 辅练 slug)
    private static let groups: [String: (primary: [String], secondary: [String])] = [
        "chest":    (["chest"],                              ["triceps", "deltoids"]),
        "back":     (["upper-back", "trapezius"],            ["biceps", "deltoids"]),
        "shoulder": (["deltoids"],                           ["trapezius"]),
        "core":     (["abs", "obliques"],                    []),
        "leg":      (["quadriceps", "hamstring", "gluteal"], ["calves", "adductors"]),
        "arm":      (["biceps", "triceps"],                  ["forearm", "deltoids"]),
        "pull":     (["upper-back"],                         ["biceps", "trapezius"]),
        "curl":     (["biceps"],                             ["forearm"]),
        "legext":   (["quadriceps"],                         []),
        "plank":    (["abs"],                                ["obliques"]),
    ]

    // 动作名/文本关键词 -> 肌群（顺序敏感，先匹配更具体的）
    private static let keywords: [(pattern: String, group: String)] = [
        ("pulldown|下拉|划船|row|引体|pull", "pull"),
        ("curl|弯举", "curl"),
        ("腿屈伸|leg ?ext|腿弯举|leg ?curl", "legext"),
        ("squat|深蹲|蹲|腿|下肢|leg", "leg"),
        ("press|推|卧推|chest", "chest"),
        ("plank|平板支撑", "plank"),
        ("侧平举|lateral|肩|shoulder|推举", "shoulder"),
    ]

    private static func keywordGroup(_ text: String) -> String? {
        for (pattern, group) in keywords {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return group
            }
        }
        return nil
    }

    private static func partGroups(part: String, ctx: String) -> [String] {
        let hasChest = part.contains("胸")
        let hasBack = part.contains("背")
        if hasChest && hasBack { return ["chest", "back"] }
        if hasChest { return ["chest"] }
        if hasBack { return ["back"] }
        if part.contains("肩") { return ["shoulder"] }
        if part.contains("核心") { return ["core"] }
        if part.contains("腿") || part.contains("下肢") { return ["leg"] }
        if part.contains("上肢") { return [keywordGroup(ctx) ?? "arm"] }
        if part.contains("其他") { return keywordGroup(ctx).map { [$0] } ?? [] }
        return keywordGroup("\(part) \(ctx)").map { [$0] } ?? []
    }

    /// 输入当天所有训练段，返回 slug -> 强度（主练优先于辅练）
    static func mapDay(_ segments: [Segment]) -> [String: Intensity] {
        var primary: [String] = []      // 保序去重
        var secondary: [String] = []
        var primarySet = Set<String>()
        var secondarySet = Set<String>()

        for s in segments {
            for gk in partGroups(part: s.part, ctx: s.exercise) {
                guard let g = groups[gk] else { continue }
                for slug in g.primary where primarySet.insert(slug).inserted {
                    primary.append(slug)
                }
                for slug in g.secondary where secondarySet.insert(slug).inserted {
                    secondary.append(slug)
                }
            }
        }

        var result: [String: Intensity] = [:]
        for slug in primary { result[slug] = .primary }
        for slug in secondary where !primarySet.contains(slug) {
            result[slug] = .secondary
        }
        return result
    }
}
