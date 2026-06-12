import Foundation

/// 恢复曲线上的一个采样点。整条曲线保留下来，是为了以后接 AI 时能分析趋势/形态。
struct HeartRateSample: Codable {
    var t: Int      // 距测量开始的秒数（0...windowSec）
    var bpm: Int
}

/// 一次「运动后心率恢复测试」（固定 60 秒 HRR），挂在某次训练上。
///
/// 设计取向：心率不是按日期记的孤立快照，而是某次训练的恢复表现——
/// 练完那一刻峰值多高、1 分钟回落多少、最后稳在哪。一个训练最多一条。
struct HeartRateRecovery: Identifiable, Codable {
    let id: UUID
    var workoutId: UUID         // 关联的训练记录
    var date: String            // yyyy-MM-dd
    var time: String            // HH:mm
    var peakBpm: Int            // 峰值（刚停下时）
    var endBpm: Int             // 恢复窗口结束时
    var windowSec: Int          // 恢复窗口时长（固定 60）
    var samples: [HeartRateSample]   // 整条恢复曲线

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        date: String,
        time: String,
        peakBpm: Int,
        endBpm: Int,
        windowSec: Int = 60,
        samples: [HeartRateSample]
    ) {
        self.id = id
        self.workoutId = workoutId
        self.date = date
        self.time = time
        self.peakBpm = peakBpm
        self.endBpm = endBpm
        self.windowSec = windowSec
        self.samples = samples
    }

    /// 1 分钟心率回落（峰值 − 结束），越大恢复越好。
    var recoveryDrop: Int { max(peakBpm - endBpm, 0) }
}

/// 测量页测完回传给录入页的中间结果。
/// workoutId/date/time 要等训练保存那一刻才确定，所以测量阶段先不带。
struct HeartRateResult {
    var peakBpm: Int
    var endBpm: Int
    var windowSec: Int
    var samples: [HeartRateSample]

    var recoveryDrop: Int { max(peakBpm - endBpm, 0) }
}
