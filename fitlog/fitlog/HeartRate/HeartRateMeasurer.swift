import AVFoundation
import Combine
import QuartzCore

/// 摄像头 PPG 测心率 + 60 秒恢复测试引擎。
///
/// 原理（参考 Pulse, MIT）：手指盖住后置摄像头并打开闪光灯，每一帧画面几乎全红，
/// 红色通道的明暗会随脉搏轻微起伏；对这条信号去趋势 + 检峰，就能算出每秒心率。
///
/// 恢复测试流程：start() → warmup（等手指放稳、读数稳定）→ 自动进入 recording，
/// 跑固定 60 秒窗口、每秒记一个 BPM，结束给出 峰值/结束/回落 与整条曲线。
///
/// 并发：本类 MainActor 隔离（工程默认）。只有逐帧像素均值在采集队列上算（nonisolated 纯函数），
/// 算完 hop 回主线程更新状态。会话的启停在主线程做（测量是模态场景，轻微阻塞可接受）。
@MainActor
final class HeartRateMeasurer: NSObject, ObservableObject {

    enum Phase: Equatable {
        case idle        // 还没开始
        case warmup      // 已开摄像头，等手指放稳
        case recording   // 60 秒恢复采集中
        case finished    // 完成
        case denied      // 没相机权限
        case unavailable // 没有可用摄像头/闪光灯
    }

    // MARK: - 对外发布的状态

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var currentBpm: Int?
    @Published private(set) var fingerDetected = false
    @Published private(set) var elapsed = 0                 // 已采集秒数 0...windowSec
    @Published private(set) var samples: [HeartRateSample] = []
    @Published private(set) var peakBpm = 0
    @Published private(set) var endBpm = 0
    @Published private(set) var waveform: [Double] = []     // 最近一段归一化信号，画动态波形

    let windowSec = 60

    var secondsRemaining: Int { max(windowSec - elapsed, 0) }

    // MARK: - 采集

    private let session = AVCaptureSession()
    private let processingQueue = DispatchQueue(label: "fitlog.hr.processing")
    private var device: AVCaptureDevice?
    private var configured = false

    // MARK: - 信号处理缓冲

    private var signal: [(t: Double, v: Double)] = []       // 最近 ~12s 的红色均值
    private var lastBpmComputeAt: Double = 0
    private var lastValidBpm = 0
    private var stableSince: Double?                        // 读数稳定起始时刻（用于自动开始）
    private var recordingTask: Task<Void, Never>?

    // MARK: - 生命周期

    /// 请求权限并开启摄像头，进入 warmup。
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.configureAndRun() } else { self.phase = .denied }
                }
            }
        default:
            phase = .denied
        }
    }

    /// 结束测量、关闪光灯、停摄像头。视图消失时务必调用。
    func stop() {
        recordingTask?.cancel()
        recordingTask = nil
        if session.isRunning { session.stopRunning() }
        setTorch(on: false)
    }

    /// 重新测一次（结果态点「重测」）。
    func restart() {
        recordingTask?.cancel()
        recordingTask = nil
        currentBpm = nil
        fingerDetected = false
        elapsed = 0
        samples = []
        peakBpm = 0
        endBpm = 0
        waveform = []
        signal = []
        lastValidBpm = 0
        stableSince = nil
        phase = session.isRunning ? .warmup : .idle
        if !session.isRunning { start() }
    }

    // MARK: - 配置

    private func configureAndRun() {
        if !configured {
            guard configureSession() else { phase = .unavailable; return }
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        setTorch(on: true)
        phase = .warmup
    }

    private func configureSession() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              camera.hasTorch
        else { return false }

        device = camera
        session.beginConfiguration()
        session.sessionPreset = .low                       // 低分辨率足够算均值，省算力
        if session.canAddInput(input) { session.addInput(input) } else { session.commitConfiguration(); return false }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)
        if session.canAddOutput(output) { session.addOutput(output) } else { session.commitConfiguration(); return false }

        session.commitConfiguration()
        return true
    }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // 闪光灯被占用等，忽略即可
        }
    }

    // MARK: - 每帧像素均值（采集队列，nonisolated 纯计算）

    nonisolated private static func meanRed(_ sampleBuffer: CMSampleBuffer) -> (red: Double, dominance: Double)? {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }

        let width = CVPixelBufferGetWidth(pb)
        let height = CVPixelBufferGetHeight(pb)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // 抽样约 40x40 个点即可（BGRA 排列）
        let stepX = max(1, width / 40)
        let stepY = max(1, height / 40)
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0.0
        var y = 0
        while y < height {
            let row = y * bytesPerRow
            var x = 0
            while x < width {
                let p = row + x * 4
                sumB += Double(ptr[p])
                sumG += Double(ptr[p + 1])
                sumR += Double(ptr[p + 2])
                count += 1
                x += stepX
            }
            y += stepY
        }
        guard count > 0 else { return nil }
        let r = sumR / count, g = sumG / count, b = sumB / count
        return (r, r - (g + b) / 2)   // dominance：手指+闪光灯时红色远高于绿蓝
    }

    // MARK: - 主线程：吃进每帧、检峰、跑协议

    fileprivate func ingest(red: Double, dominance: Double, at t: Double) {
        // 手指检测：画面要够亮且红色主导
        let present = red > 80 && dominance > 25
        if present != fingerDetected { fingerDetected = present }

        guard present else {
            // 手指拿开：清空稳定计时，不喂信号
            stableSince = nil
            return
        }

        // 累积信号，保留最近 12 秒
        signal.append((t, red))
        let cutoff = t - 12
        if signal.first.map({ $0.t < cutoff }) == true {
            signal.removeAll { $0.t < cutoff }
        }

        // 每 0.4s 重算一次 BPM
        if t - lastBpmComputeAt > 0.4 {
            lastBpmComputeAt = t
            computeBpm(now: t)
        }

        updateWaveform()
        maybeAutoStart(now: t)
    }

    /// 去趋势 + 检峰算 BPM。
    private func computeBpm(now: Double) {
        guard signal.count > 30,
              let first = signal.first?.t, now - first > 4    // 至少 4 秒数据
        else { return }

        // 去趋势：减去滑动均值
        let values = signal.map { $0.v }
        let mean = values.reduce(0, +) / Double(values.count)
        let detrended = signal.map { (t: $0.t, v: $0.v - mean) }

        // 动态阈值
        let variance = detrended.map { $0.v * $0.v }.reduce(0, +) / Double(detrended.count)
        let std = variance.squareRoot()
        let threshold = std * 0.5

        // 检正向峰（局部极大、超阈值、与上一峰至少间隔 0.3s = 上限 200bpm）
        var peakTimes: [Double] = []
        for i in 1..<(detrended.count - 1) {
            let v = detrended[i].v
            if v > threshold, v >= detrended[i - 1].v, v > detrended[i + 1].v {
                if let last = peakTimes.last, detrended[i].t - last < 0.3 { continue }
                peakTimes.append(detrended[i].t)
            }
        }

        guard peakTimes.count >= 3 else { return }
        var intervals: [Double] = []
        for i in 1..<peakTimes.count { intervals.append(peakTimes[i] - peakTimes[i - 1]) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return }
        let bpm = 60.0 / avg
        guard bpm >= 40, bpm <= 200 else { return }

        // 指数平滑
        let smoothed = lastValidBpm == 0 ? bpm : lastValidBpm.double * 0.6 + bpm * 0.4
        lastValidBpm = Int(smoothed.rounded())
        currentBpm = lastValidBpm
    }

    private func updateWaveform() {
        // 取最近 ~3 秒信号，归一化到 0...1 给 UI 画线
        let now = signal.last?.t ?? 0
        let recent = signal.filter { $0.t > now - 3 }.map { $0.v }
        guard recent.count > 2, let lo = recent.min(), let hi = recent.max(), hi > lo else { return }
        waveform = recent.map { ($0 - lo) / (hi - lo) }
    }

    /// warmup 阶段：读数稳定持续 ~2 秒后自动开始 60 秒采集。
    private func maybeAutoStart(now: Double) {
        guard phase == .warmup, currentBpm != nil else { stableSince = nil; return }
        if stableSince == nil { stableSince = now }
        if let s = stableSince, now - s >= 2 {
            beginRecording()
        }
    }

    private func beginRecording() {
        guard phase == .warmup, let bpm = currentBpm else { return }
        phase = .recording
        elapsed = 0
        peakBpm = bpm
        endBpm = bpm
        samples = [HeartRateSample(t: 0, bpm: bpm)]   // 起点=峰值（刚停下时心率最高）

        recordingTask = Task { @MainActor in
            for t in 1...windowSec {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                let bpm = currentBpm ?? lastValidBpm
                elapsed = t
                samples.append(HeartRateSample(t: t, bpm: bpm))
                peakBpm = max(peakBpm, bpm)
                endBpm = bpm
                if t >= windowSec { break }
            }
            finish()
        }
    }

    private func finish() {
        endBpm = samples.last?.bpm ?? endBpm
        peakBpm = samples.map(\.bpm).max() ?? peakBpm
        phase = .finished
        if session.isRunning { session.stopRunning() }
        setTorch(on: false)
    }
}

// MARK: - 采集回调（nonisolated，跑在 processingQueue）

extension HeartRateMeasurer: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let m = Self.meanRed(sampleBuffer) else { return }
        let t = CACurrentMediaTime()
        Task { @MainActor in
            self.ingest(red: m.red, dominance: m.dominance, at: t)
        }
    }
}

private extension Int {
    var double: Double { Double(self) }
}
