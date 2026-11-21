import Foundation
import Combine

/// 本地持久化设置（无账号、无卡密、无网络）。
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var tier: ModelTier { didSet { defaults.set(tier.rawValue, forKey: Keys.tier) } }
    @Published var drawBox: Bool { didSet { defaults.set(drawBox, forKey: Keys.box) } }
    @Published var drawSkeleton: Bool { didSet { defaults.set(drawSkeleton, forKey: Keys.skeleton) } }
    @Published var drawRadar: Bool { didSet { defaults.set(drawRadar, forKey: Keys.radar) } }
    @Published var drawAntenna: Bool { didSet { defaults.set(drawAntenna, forKey: Keys.antenna) } }
    @Published var drawMode: DrawMode { didSet { defaults.set(drawMode.rawValue, forKey: Keys.mode) } }
    @Published var threshold: Double { didSet { defaults.set(threshold, forKey: Keys.threshold) } }
    @Published var classFilter: [String: Bool] { didSet { persistFilter() } }
    @Published var noticeAcknowledged: Bool { didSet { defaults.set(noticeAcknowledged, forKey: Keys.notice) } }

    /// 人的最低置信度：比通用阈值高一档，压掉衣物/轮廓误检
    let personThreshold: Double = 0.35

    private enum Keys {
        static let tier = "ts_tier"
        static let box = "ts_draw_box"
        static let skeleton = "ts_draw_skeleton"
        static let radar = "ts_draw_radar"
        static let antenna = "ts_draw_antenna"
        static let mode = "ts_draw_mode"
        static let threshold = "ts_threshold"
        static let filter = "ts_cls_filter"
        static let notice = "ts_notice_ack"
    }

    init() {
        tier = ModelTier.from(raw: UserDefaults.standard.string(forKey: Keys.tier))
        drawBox = UserDefaults.standard.object(forKey: Keys.box) as? Bool ?? true
        drawSkeleton = UserDefaults.standard.object(forKey: Keys.skeleton) as? Bool ?? false
        drawRadar = UserDefaults.standard.object(forKey: Keys.radar) as? Bool ?? false
        drawAntenna = UserDefaults.standard.object(forKey: Keys.antenna) as? Bool ?? false
        drawMode = DrawMode(rawValue: UserDefaults.standard.string(forKey: Keys.mode) ?? "") ?? .single
        let savedThreshold = UserDefaults.standard.object(forKey: Keys.threshold) as? Double
        threshold = savedThreshold ?? 0.22
        noticeAcknowledged = UserDefaults.standard.bool(forKey: Keys.notice)

        var filter: [String: Bool] = [:]
        var saved: [String: Bool] = [:]
        if let json = UserDefaults.standard.string(forKey: Keys.filter)?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: json) {
            saved = decoded
        }
        for cls in Catalog.targetClasses {
            filter[cls] = saved[cls] ?? true
        }
        classFilter = filter
    }

    private func persistFilter() {
        guard let data = try? JSONEncoder().encode(classFilter),
              let json = String(data: data, encoding: .utf8) else { return }
        defaults.set(json, forKey: Keys.filter)
    }

    /// 当前生效的类别（单人物模式只留人）
    func isClassEnabled(_ cls: String) -> Bool {
        drawMode == .single ? cls == "person" : (classFilter[cls] ?? true)
    }

    func setAll(_ value: Bool) {
        var next: [String: Bool] = [:]
        for cls in Catalog.targetClasses { next[cls] = value }
        classFilter = next
    }
}
