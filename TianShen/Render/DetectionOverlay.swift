import SwiftUI

/// 平滑器：按索引把框往新位置 ease（k=0.8），避免框瞬移。
final class BoxSmoother: ObservableObject {
    private var boxes: [CGRect] = []
    private var classes: [String] = []
    private let ease: CGFloat = 0.8

    func step(_ input: [Detection]) -> [Detection] {
        guard !input.isEmpty else {
            boxes = []
            classes = []
            return []
        }
        var out: [Detection] = []
        var next: [CGRect] = []
        for (index, det) in input.enumerated() {
            let sameTrack = index < boxes.count && index < classes.count && classes[index] == det.cls
            let prev = sameTrack ? boxes[index] : det.box
            let smoothed = CGRect(
                x: prev.minX + (det.box.minX - prev.minX) * ease,
                y: prev.minY + (det.box.minY - prev.minY) * ease,
                width: prev.width + (det.box.width - prev.width) * ease,
                height: prev.height + (det.box.height - prev.height) * ease
            )
            next.append(smoothed)
            out.append(Detection(box: smoothed, score: det.score, cls: det.cls))
        }
        boxes = next
        classes = input.map { $0.cls }
        return out
    }
}

/// 主体叠加层：四角括号框、标签、头部圆、射线、雷达。
struct DetectionOverlay: View {
    let detections: [Detection]
    let sourceSize: CGSize
    let settings: SettingsStore
    let heading: Double

    @StateObject private var smoother = BoxSmoother()

    private let green = Color(red: 0, green: 1, blue: 0.53)
    private let cyan = Color(red: 0, green: 0.83, blue: 1)
    private let red = Color(red: 1, green: 0.2, blue: 0.2)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let shown = smoother.step(detections)
                var ctx = context
                drawBoxes(&ctx, size: size, shown: shown)
                if settings.drawAntenna { drawRays(&ctx, size: size, shown: shown) }
                if settings.drawRadar { drawRadar(&ctx, size: size, shown: shown, now: now) }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - 坐标映射（与 preview 的 resizeAspectFill 一致）

    private func mapping(for size: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return (1, .zero) }
        let scale = max(size.width / sourceSize.width, size.height / sourceSize.height)
        let drawW = sourceSize.width * scale
        let drawH = sourceSize.height * scale
        return (scale, CGPoint(x: (size.width - drawW) / 2, y: (size.height - drawH) / 2))
    }

    // MARK: - 方框 + 标签 + 骨骼

    private func drawBoxes(_ ctx: inout GraphicsContext, size: CGSize, shown: [Detection]) {
        guard settings.drawBox || settings.drawSkeleton else { return }
        let (scale, origin) = mapping(for: size)

        for (index, det) in shown.enumerated() {
            let rect = CGRect(
                x: origin.x + det.box.minX * scale,
                y: origin.y + det.box.minY * scale,
                width: det.box.width * scale,
                height: det.box.height * scale
            )

            if settings.drawBox {
                let corner = min(rect.width, rect.height) * 0.2
                var path = Path()
                // 左上
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + corner))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.minY))
                // 右上
                path.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
                // 左下
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
                // 右下
                path.move(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
                ctx.stroke(path, with: .color(green), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                let label = "\(det.label) \(index + 1) \(Int(det.score * 100))%"
                let text = Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(green)
                ctx.draw(text, at: CGPoint(x: rect.minX + 2, y: rect.minY - 4), anchor: .bottomLeading)
            }

            if settings.drawSkeleton {
                let headCenter = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1)
                let headRadius = min(rect.width, rect.height) * 0.14
                let circle = Path(ellipseIn: CGRect(x: headCenter.x - headRadius,
                                                    y: headCenter.y - headRadius,
                                                    width: headRadius * 2,
                                                    height: headRadius * 2))
                ctx.stroke(circle, with: .color(cyan), lineWidth: 2)
                let dot = Path(ellipseIn: CGRect(x: headCenter.x - 2, y: headCenter.y - 2, width: 4, height: 4))
                ctx.fill(dot, with: .color(cyan))
            }
        }
    }

    // MARK: - 射线（顶部红色目标盒 + 连线）

    private func drawRays(_ ctx: inout GraphicsContext, size: CGSize, shown: [Detection]) {
        guard !shown.isEmpty else { return }
        let (scale, origin) = mapping(for: size)

        let boxWidth: CGFloat = 118
        let boxHeight: CGFloat = 30
        let boxRect = CGRect(x: (size.width - boxWidth) / 2, y: 54, width: boxWidth, height: boxHeight)

        let panel = Path(roundedRect: boxRect, cornerRadius: 6)
        ctx.fill(panel, with: .color(Color(red: 0.32, green: 0, blue: 0).opacity(0.85)))
        ctx.stroke(panel, with: .color(red.opacity(0.9)), lineWidth: 1.2)

        ctx.draw(Text("天神辅助")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(red),
                 at: CGPoint(x: boxRect.midX, y: boxRect.minY + 11))

        ctx.draw(Text("\(shown.count) TARGETS")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 1, green: 0.67, blue: 0.67)),
                 at: CGPoint(x: boxRect.midX, y: boxRect.minY + 23))

        let anchor = CGPoint(x: boxRect.midX, y: boxRect.maxY)

        for (index, det) in shown.enumerated() {
            let px = origin.x + (det.box.minX + det.box.width / 2) * scale
            let py = origin.y + det.box.minY * scale

            var line = Path()
            line.move(to: anchor)
            line.addLine(to: CGPoint(x: px, y: py))
            ctx.stroke(line, with: .linearGradient(
                Gradient(colors: [red.opacity(0.7), green.opacity(0.5)]),
                startPoint: anchor,
                endPoint: CGPoint(x: px, y: py)
            ), lineWidth: 1.2)

            let tag = "目标\(index + 1) \(det.box.width * det.box.height > 50000 ? "近" : "远")"
            let tagRect = CGRect(x: px - 26, y: py - 18, width: 52, height: 14)
            let tagPath = Path(roundedRect: tagRect, cornerRadius: 3)
            ctx.fill(tagPath, with: .color(.black.opacity(0.7)))
            ctx.draw(Text(tag)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(red: 0.4, green: 1, blue: 0.4)),
                     at: CGPoint(x: tagRect.midX, y: tagRect.midY))
        }
    }

    // MARK: - 雷达

    private func drawRadar(_ ctx: inout GraphicsContext, size: CGSize, shown: [Detection], now: Double) {
        let diameter = min(240.0, min(size.width, size.height) * 0.56)
        let radius = diameter / 2 - 6
        let center = CGPoint(x: size.width - diameter / 2 - 16, y: size.height - diameter / 2 - 42)

        // 底盘
        var disc = Path(ellipseIn: CGRect(x: center.x - diameter / 2,
                                          y: center.y - diameter / 2,
                                          width: diameter,
                                          height: diameter))
        ctx.fill(disc, with: .color(Color(red: 0, green: 0.06, blue: 0.1).opacity(0.62)))

        // 三环
        for i in 1...3 {
            let r = radius * CGFloat(i) / 3
            let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            ctx.stroke(ring, with: .color(cyan.opacity(0.2)), lineWidth: 1)
        }

        // 十字
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - radius, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - radius))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        ctx.stroke(cross, with: .color(cyan.opacity(0.2)), lineWidth: 1)

        // 扫描扇
        let sweep = heading * .pi / 180 + now.truncatingRemainder(dividingBy: 10) * 0.6
        var fan = Path()
        fan.move(to: center)
        fan.addArc(center: center, radius: radius,
                   startAngle: .radians(sweep - 0.45), endAngle: .radians(sweep), clockwise: false)
        fan.closeSubpath()
        ctx.fill(fan, with: .linearGradient(
            Gradient(colors: [green.opacity(0.45), green.opacity(0.02)]),
            startPoint: center,
            endPoint: CGPoint(x: center.x + radius, y: center.y)
        ))

        // N 标记 + 度数
        ctx.draw(Text("N").font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(red),
                 at: CGPoint(x: center.x, y: center.y - radius + 12))
        ctx.draw(Text("\(Int(heading.rounded()))°")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(cyan.opacity(0.7)),
                 at: CGPoint(x: center.x, y: center.y + 2))

        // 目标点
        guard sourceSize.width > 0 else { return }
        for det in shown {
            let nx = (det.box.midX / sourceSize.width) * 2 - 1
            let angle = Double(nx) * 30.0
            let rad = (angle - heading) * .pi / 180 + .pi / 2
            let dist = radius * 0.7 * (0.5 + CGFloat(det.score) * 0.5)
            let px = center.x + CGFloat(cos(rad)) * dist
            let py = center.y - CGFloat(sin(rad)) * dist

            let pulse = CGFloat(8 + sin(now * 5) * 3)
            let ring = Path(ellipseIn: CGRect(x: px - pulse, y: py - pulse,
                                              width: pulse * 2, height: pulse * 2))
            ctx.stroke(ring, with: .color(red.opacity(0.4)), lineWidth: 1)

            let dot = Path(ellipseIn: CGRect(x: px - 4.5, y: py - 4.5, width: 9, height: 9))
            ctx.fill(dot, with: .color(red))
        }
    }
}
