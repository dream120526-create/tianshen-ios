import CoreGraphics
import Foundation

/// 一个检测结果，坐标是「旋转后的原始画面像素坐标」。
struct Detection: Identifiable, Equatable {
    let id = UUID()
    var box: CGRect
    var score: Float
    var cls: String

    var label: String { Catalog.label(for: cls) }
}

/// letterbox 的前后映射参数
struct Letterbox {
    var scale: CGFloat
    var padX: CGFloat
    var padY: CGFloat
    var sourceSize: CGSize
}
