import SwiftUI
import Charts
import UIKit

/// 运动后心率恢复测量页（三态：引导/测量中/完成）。
/// 测完点「保存」把结果回传给录入页，由录入页在训练保存时落库。
struct HeartRateRecoveryView: View {
    @StateObject private var measurer = HeartRateMeasurer()
    @Environment(\.dismiss) private var dismiss

    let onComplete: (HeartRateResult) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fitBackground.ignoresSafeArea()
                content
                    .padding(24)
            }
            .navigationTitle("运动后心率恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear { measurer.start() }
        .onDisappear { measurer.stop() }
    }

    @ViewBuilder private var content: some View {
        switch measurer.phase {
        case .idle, .warmup: warmupView
        case .recording: recordingView
        case .finished: finishedView
        case .denied:
            messageView("需要相机权限",
                        "测心率要用后置摄像头和闪光灯。请到「设置 → FitLog」打开相机权限再回来。",
                        showSettings: true)
        case .unavailable:
            messageView("无法测量", "此设备没有可用的后置摄像头或闪光灯。", showSettings: false)
        }
    }

    // MARK: - 引导 / 预热

    private var warmupView: some View {
        VStack(spacing: 20) {
            Spacer()
            heart
            Text("把指尖轻轻盖住\n后置摄像头 + 闪光灯")
                .multilineTextAlignment(.center)
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(Color.fitPrimaryText)
            VStack(alignment: .leading, spacing: 6) {
                tip("练完那一刻测，别歇太久")
                tip("手指别动，力度适中")
                tip("会自动测量约 1 分钟")
            }
            statusPill
            Spacer()
            disclaimer
        }
    }

    private var statusPill: some View {
        let detected = measurer.fingerDetected
        return HStack(spacing: 8) {
            Image(systemName: detected ? "checkmark.circle.fill" : "hand.point.up.left.fill")
            if detected, let bpm = measurer.currentBpm {
                Text("手指放好了 · \(bpm) bpm，正在稳定…")
            } else if detected {
                Text("手指放好了，正在读取…")
            } else {
                Text("请把指尖盖住摄像头")
            }
        }
        .font(.subheadline).fontWeight(.medium)
        .foregroundStyle(detected ? Color.fitPositiveGreen : Color.fitSecondaryText)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.fitCardSurface, in: Capsule())
    }

    // MARK: - 测量中

    private var recordingView: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                heartSmall
                Text(measurer.currentBpm.map(String.init) ?? "--")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.fitHeartCoral)
                    .contentTransition(.numericText())
                Text("bpm").font(.title3).foregroundStyle(Color.fitSecondaryText)
            }

            Text("还剩 \(measurer.secondsRemaining) 秒")
                .font(.headline).foregroundStyle(Color.fitPrimaryText)
            ProgressView(value: Double(measurer.elapsed), total: Double(measurer.windowSec))
                .tint(Color.fitHeartCoral)

            curveChart(measurer.samples)

            if !measurer.fingerDetected {
                Text("⚠️ 手指好像松了，盖紧一点")
                    .font(.subheadline).foregroundStyle(Color.fitWarningRed)
            }
            Spacer()
            disclaimer
        }
    }

    // MARK: - 完成

    private var finishedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("测量完成").font(.headline).foregroundStyle(Color.fitSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                bigStat("\(measurer.peakBpm)", "峰值")
                Image(systemName: "arrow.right").foregroundStyle(Color.fitSecondaryText)
                bigStat("\(measurer.endBpm)", "1分钟后")
            }
            let drop = max(measurer.peakBpm - measurer.endBpm, 0)
            Text("回落 \(drop) bpm · \(drop >= 12 ? "恢复良好" : "恢复偏慢")")
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(Color.fitHeartCoral)

            curveChart(measurer.samples)

            HStack(spacing: 12) {
                Button { measurer.restart() } label: {
                    Text("重测").fontWeight(.semibold).foregroundStyle(Color.fitAccent)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fitDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button {
                    onComplete(HeartRateResult(
                        peakBpm: measurer.peakBpm,
                        endBpm: measurer.endBpm,
                        windowSec: measurer.windowSec,
                        samples: measurer.samples
                    ))
                    dismiss()
                } label: {
                    Text("保存").fontWeight(.semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.fitHeartCoral, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            disclaimer
        }
    }

    // MARK: - 组件

    private func curveChart(_ samples: [HeartRateSample]) -> some View {
        Chart {
            ForEach(samples, id: \.t) { s in
                LineMark(x: .value("秒", s.t), y: .value("BPM", s.bpm))
                    .foregroundStyle(Color.fitHeartCoral)
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXScale(domain: 0...measurer.windowSec)
        .frame(height: 170)
        .padding(.vertical, 4)
    }

    private var heart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 64))
            .foregroundStyle(Color.fitHeartCoral)
            .symbolEffect(.pulse, options: .repeating)
    }

    private var heartSmall: some View {
        Image(systemName: "heart.fill")
            .font(.title2)
            .foregroundStyle(Color.fitHeartCoral)
            .symbolEffect(.pulse, options: .repeating)
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 48, weight: .bold)).foregroundStyle(Color.fitPrimaryText)
            Text(label).font(.caption).foregroundStyle(Color.fitSecondaryText)
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Color.fitSecondaryText)
            Text(text).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
        }
    }

    private var disclaimer: some View {
        Text("⚠️ 仅供参考，非医疗设备")
            .font(.caption2).foregroundStyle(Color.fitTertiaryText)
    }

    private func messageView(_ title: String, _ message: String, showSettings: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(Color.fitSecondaryText)
            Text(title).font(.title3).fontWeight(.semibold).foregroundStyle(Color.fitPrimaryText)
            Text(message).multilineTextAlignment(.center).font(.subheadline).foregroundStyle(Color.fitSecondaryText)
            if showSettings {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .fontWeight(.semibold).foregroundStyle(Color.fitAccent)
            }
            Spacer()
        }
    }
}
