import SwiftUI

/// 诊断面板：看模型、帧率、推理耗时和运行状态，不联网。
struct DiagView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pipeline: DetectionPipeline
    @ObservedObject var camera: CameraController
    @Environment(\.dismiss) private var dismiss

    private var modelPath: String {
        ModelStore.url(for: settings.tier)?.path ?? "(未找到)"
    }

    private var lines: [String] {
        [
            "App        天神辅助 iOS 1.0.0",
            "模型档位    \(settings.tier.title) · \(settings.tier.network)",
            "模型路径    \(modelPath)",
            "模型状态    \(pipeline.modelReady ? "已加载" : "未就绪")",
            "输入尺寸    \(settings.tier.inputSize) × \(settings.tier.inputSize)",
            "来源尺寸    \(Int(pipeline.sourceSize.width)) × \(Int(pipeline.sourceSize.height))",
            "推理耗时    \(String(format: "%.1f", pipeline.inferMs)) ms",
            "渲染帧率    \(Int(pipeline.fps.rounded())) fps",
            "检测节流    120 ms",
            "本次目标    \(pipeline.detections.count)",
            "相机        \(camera.positionLabel) · \(camera.running ? "运行中" : "停止")",
            "阈值        通用 \(String(format: "%.2f", settings.threshold)) / 人 \(String(format: "%.2f", settings.personThreshold))",
            "绘制模式    \(settings.drawMode.title)",
            "可用档位    \(ModelStore.availableTiers.map(\.title).joined(separator: " / "))",
            "onnxruntime 1.19+ (SPM)"
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(lines.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Theme.panelBG.ignoresSafeArea())
            .navigationTitle("诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
