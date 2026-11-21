import Foundation

/// 模型文件定位：优先 Documents/Models（可用「文件」App 拖入），其次 App 内置。
enum ModelStore {
    static var documentsModelsDirectory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for tier: ModelTier) -> URL? {
        let name = tier.resourceName + ".onnx"
        let external = documentsModelsDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: external.path) { return external }

        if let bundled = Bundle.main.url(forResource: tier.resourceName, withExtension: "onnx") {
            return bundled
        }
        if let nested = Bundle.main.url(forResource: tier.resourceName,
                                       withExtension: "onnx",
                                       subdirectory: "Models") {
            return nested
        }
        return nil
    }

    static func isAvailable(_ tier: ModelTier) -> Bool { url(for: tier) != nil }

    static var availableTiers: [ModelTier] {
        ModelTier.allCases.filter { isAvailable($0) }
    }

    /// 内置到 App 里的模型直接复制一份到 Documents，方便用户知道去哪换模型
    static func seedBundledModels() {
        for tier in ModelTier.allCases {
            let name = tier.resourceName + ".onnx"
            let dest = documentsModelsDirectory.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: dest.path),
                  let src = Bundle.main.url(forResource: tier.resourceName, withExtension: "onnx")
                    ?? Bundle.main.url(forResource: tier.resourceName, withExtension: "onnx", subdirectory: "Models")
            else { continue }
            try? FileManager.default.copyItem(at: src, to: dest)
        }
    }
}
