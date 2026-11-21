import Combine
import CoreMedia
import CoreVideo
import Foundation

/// 检测调度：120ms 节流（与安卓版一致），统计帧率，结果只留最新一帧。
final class DetectionPipeline: ObservableObject {
    private let detector = Detector()
    private let workQueue = DispatchQueue(label: "ts.pipeline", qos: .userInitiated)
    private let interval: TimeInterval = 0.12
    private let stateLock = NSLock()
    private var lastDispatch: TimeInterval = 0
    private var inFlight = false
    private var frameCount = 0
    private var fpsWindowStart: TimeInterval = 0

    @Published private(set) var detections: [Detection] = []
    @Published private(set) var fps: Double = 0
    @Published private(set) var modelReady = false
    @Published private(set) var inferMs: Double = 0
    @Published private(set) var sourceSize: CGSize = .zero
    @Published private(set) var statusText: String = "待启动"

    var isReady: Bool { detector.isReady }

    // MARK: - 模型

    func loadModel(tier: ModelTier) {
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.detector.load(tier: tier)
                DispatchQueue.main.async {
                    self.modelReady = true
                    self.statusText = "\(tier.network) 就绪"
                }
            } catch {
                DispatchQueue.main.async {
                    self.modelReady = false
                    self.statusText = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 取帧

    func handle(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        let now = CFAbsoluteTimeGetCurrent()

        frameCount += 1
        if fpsWindowStart == 0 { fpsWindowStart = now }
        if now - fpsWindowStart >= 1.0 {
            let measured = Double(frameCount) / (now - fpsWindowStart)
            frameCount = 0
            fpsWindowStart = now
            DispatchQueue.main.async { self.fps = measured }
        }

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        if size != sourceSize { DispatchQueue.main.async { self.sourceSize = size } }

        stateLock.lock()
        let canRun = detector.isReady && !inFlight && (now - lastDispatch >= interval)
        if canRun {
            inFlight = true
            lastDispatch = now
        }
        stateLock.unlock()
        guard canRun else { return }

        let started = CFAbsoluteTimeGetCurrent()
        workQueue.async { [weak self] in
            guard let self else { return }
            let output = self.detector.detect(pixelBuffer: pixelBuffer)
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000.0
            DispatchQueue.main.async {
                if let output {
                    self.detections = output.0
                    self.inferMs = elapsed
                }
                self.stateLock.lock()
                self.inFlight = false
                self.stateLock.unlock()
            }
        }
    }

    /// 按当前设置过滤（单人物 / 多物品 + 灵敏度 + 人的额外阈值）
    func filtered(settings: SettingsStore) -> [Detection] {
        detections.filter { det in
            guard settings.isClassEnabled(det.cls) else { return false }
            if Double(det.score) < settings.threshold { return false }
            if det.cls == "person", Double(det.score) < settings.personThreshold { return false }
            return true
        }
    }
}
