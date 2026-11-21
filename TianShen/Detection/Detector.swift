import CoreImage
import CoreVideo
import Foundation
import UIKit

/// 本地 ONNX 推理：YOLOv8 + letterbox + 贪心 NMS。全程离线。
/// 底层走 ObjC++ 桥（ONNXBridge.mm），不依赖任何网络包管理器。
final class Detector {
    private let ciContext = CIContext()
    private let queue = DispatchQueue(label: "ts.detector", qos: .userInitiated)

    private var runner: ONNXRunner?
    private(set) var inputSize: Int = 416
    private(set) var loadedTier: ModelTier?
    private(set) var loadedPath: String = ""

    /// 原生侧粗筛阈值（UI 上的灵敏度在此基础上再过滤）
    private let nativeScoreThreshold: Float = 0.20
    private let iouThreshold: CGFloat = 0.45

    var isReady: Bool { runner != nil }

    // MARK: - 加载模型

    func load(tier: ModelTier) throws {
        guard let url = ModelStore.url(for: tier) else {
            throw DetectorError.modelMissing(tier)
        }
        var thrown: Error?
        queue.sync {
            do {
                let runner = try ONNXRunner(modelPath: url.path, threads: tier.intraOpThreads)
                self.runner = runner
                self.inputSize = tier.inputSize
                self.loadedTier = tier
                self.loadedPath = url.path
            } catch {
                self.runner = nil
                thrown = error
            }
        }
        if let thrown { throw thrown }
    }

    // MARK: - 推理

    func detect(pixelBuffer: CVPixelBuffer) -> ([Detection], Letterbox)? {
        guard let runner else { return nil }

        var result: ([Detection], Letterbox)?
        queue.sync {
            guard let input = makeInput(pixelBuffer: pixelBuffer) else { return }
            do {
                let shape = [NSNumber(value: 1),
                             NSNumber(value: 3),
                             NSNumber(value: inputSize),
                             NSNumber(value: inputSize)]
                guard let output = try runner.run(withFloatInput: input.data as NSData, shape: shape) else {
                    return
                }
                let boxes = try decode(output: output, letterbox: input.letterbox)
                result = (boxes, input.letterbox)
            } catch {
                NSLog("[Detector] run failed: \(error)")
                result = nil
            }
        }
        return result
    }

    // MARK: - 预处理（letterbox + CHW + 归一化）

    private struct PreparedInput {
        var data: Data
        var letterbox: Letterbox
    }

    private func makeInput(pixelBuffer: CVPixelBuffer) -> PreparedInput? {
        let side = inputSize
        let srcW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let srcH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        guard srcW > 0, srcH > 0 else { return nil }

        let scale = min(CGFloat(side) / srcW, CGFloat(side) / srcH)
        let drawW = max(1, (srcW * scale).rounded())
        let drawH = max(1, (srcH * scale).rounded())
        let padX = ((CGFloat(side) - drawW) / 2).rounded()
        let padY = ((CGFloat(side) - drawH) / 2).rounded()

        var source = CIImage(cvPixelBuffer: pixelBuffer)
        if source.extent.origin != .zero {
            source = source.transformed(by: CGAffineTransform(translationX: -source.extent.origin.x,
                                                              y: -source.extent.origin.y))
        }
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }

        let bytesPerRow = side * 4
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        rgba.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(data: base,
                                      width: side,
                                      height: side,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }

            // 灰色留边（与安卓版一致：153,153,153）
            ctx.setFillColor(CGColor(red: 153.0 / 255.0,
                                     green: 153.0 / 255.0,
                                     blue: 153.0 / 255.0,
                                     alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

            // CGContext 原点在左下；bitmap 第 0 行是最上面一行
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: padX,
                                         y: CGFloat(side) - padY - drawH,
                                         width: drawW,
                                         height: drawH))
        }

        let plane = side * side
        var floats = [Float](repeating: 0, count: plane * 3)
        for i in 0..<plane {
            let o = i * 4
            floats[i] = Float(rgba[o]) / 255.0
            floats[plane + i] = Float(rgba[o + 1]) / 255.0
            floats[plane * 2 + i] = Float(rgba[o + 2]) / 255.0
        }
        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }

        return PreparedInput(
            data: data,
            letterbox: Letterbox(scale: scale, padX: padX, padY: padY,
                                 sourceSize: CGSize(width: srcW, height: srcH))
        )
    }

    // MARK: - 后处理

    private func decode(output: [String: Any], letterbox: Letterbox) throws -> [Detection] {
        guard let data = output["data"] as? Data,
              let shapeNumbers = output["shape"] as? [NSNumber] else { return [] }

        let shape = shapeNumbers.map { $0.intValue }
        guard shape.count >= 3 else { return [] }
        let attrs = shape[shape.count - 2]
        let count = shape[shape.count - 1]
        guard attrs > 4, count > 0 else { return [] }

        var values = [Float](repeating: 0, count: data.count / 4)
        _ = values.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        guard values.count >= attrs * count else { return [] }

        var boxes: [Detection] = []
        let scale = max(letterbox.scale, 0.0001)

        for i in 0..<count {
            let cx = values[i]
            let cy = values[count + i]
            let w = values[count * 2 + i]
            let h = values[count * 3 + i]
            guard w > 1, h > 1 else { continue }

            var best: Float = -1
            var bestClass = -1
            for a in 4..<attrs {
                let s = values[a * count + i]
                if s > best {
                    best = s
                    bestClass = a - 4
                }
            }
            guard best >= nativeScoreThreshold,
                  bestClass >= 0,
                  bestClass < Catalog.coco80.count else { continue }
            let cls = Catalog.coco80[bestClass]
            guard Catalog.targetClasses.contains(cls) else { continue }

            let x1 = (CGFloat(cx - w / 2) - letterbox.padX) / scale
            let y1 = (CGFloat(cy - h / 2) - letterbox.padY) / scale
            let bw = CGFloat(w) / scale
            let bh = CGFloat(h) / scale
            let rect = CGRect(x: x1, y: y1, width: bw, height: bh)
                .intersection(CGRect(origin: .zero, size: letterbox.sourceSize))
            guard !rect.isNull, rect.width > 2, rect.height > 2 else { continue }
            boxes.append(Detection(box: rect, score: best, cls: cls))
        }

        return nms(boxes, iou: iouThreshold)
    }

    private func nms(_ boxes: [Detection], iou: CGFloat) -> [Detection] {
        let sorted = boxes.sorted { $0.score > $1.score }
        var kept: [Detection] = []
        for candidate in sorted {
            var overlapping = false
            for keep in kept where keep.cls == candidate.cls {
                let inter = keep.box.intersection(candidate.box)
                if inter.isNull { continue }
                let interArea = inter.width * inter.height
                let union = keep.box.width * keep.box.height
                    + candidate.box.width * candidate.box.height
                    - interArea
                if union > 0, interArea / union > iou {
                    overlapping = true
                    break
                }
            }
            if !overlapping { kept.append(candidate) }
        }
        return kept
    }
}

enum DetectorError: LocalizedError {
    case modelMissing(ModelTier)

    var errorDescription: String? {
        switch self {
        case .modelMissing(let tier):
            return "\(tier.title)模型缺失：把 \(tier.resourceName).onnx 放进 App 的 Documents/Models 目录"
        }
    }
}
