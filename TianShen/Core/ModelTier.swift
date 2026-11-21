import Foundation

/// 三档本地模型：用户按机型性能自选，全部离线推理。
enum ModelTier: String, CaseIterable, Identifiable {
    case low
    case mid
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:  return "低配"
        case .mid:  return "中配"
        case .high: return "高配"
        }
    }

    /// 权重文件名（不含扩展名）
    var resourceName: String {
        switch self {
        case .low:  return "yolov8n"
        case .mid:  return "yolov8s"
        case .high: return "yolov8m"
        }
    }

    var network: String {
        switch self {
        case .low:  return "YOLOv8n"
        case .mid:  return "YOLOv8s"
        case .high: return "YOLOv8m"
        }
    }

    /// 网络输入边长（letterbox 目标尺寸）
    var inputSize: Int { 416 }

    /// ONNX Runtime 线程数
    var intraOpThreads: Int {
        switch self {
        case .low:  return 2
        case .mid:  return 3
        case .high: return 4
        }
    }

    var summary: String {
        switch self {
        case .low:  return "最快 · 老机型/发热优先"
        case .mid:  return "均衡 · 大多数机型够用"
        case .high: return "最准 · 需要 A15 及以上"
        }
    }

    var approxSize: String {
        switch self {
        case .low:  return "12 MB"
        case .mid:  return "43 MB"
        case .high: return "99 MB"
        }
    }

    static func from(raw: String?) -> ModelTier {
        guard let raw, let t = ModelTier(rawValue: raw) else { return .low }
        return t
    }
}

enum DrawMode: String, CaseIterable, Identifiable {
    case single
    case multi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "单人物"
        case .multi:  return "多物品"
        }
    }
}
