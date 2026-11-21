import SwiftUI

struct RootView: View {
    @StateObject private var settings = SettingsStore()
    @StateObject private var camera = CameraController()
    @StateObject private var pipeline = DetectionPipeline()
    @StateObject private var compass = Compass()

    @State private var showNotice = false
    @State private var showFilter = false
    @State private var showDiag = false
    @State private var filtered: [Detection] = []
    @State private var needsModel = false
    @State private var started = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                messageView(
                    title: "需要相机权限",
                    detail: "识别仅使用实时取景画面，不拍照、不上传。请到「设置 → 天神辅助」里打开相机权限。",
                    action: nil
                )
            } else {
                CameraPreview(session: camera.session, mirrored: false)
                    .ignoresSafeArea()

                DetectionOverlay(detections: filtered,
                                 sourceSize: pipeline.sourceSize,
                                 settings: settings,
                                 heading: compass.heading)

                HUDView(settings: settings,
                        pipeline: pipeline,
                        compass: compass,
                        targetCount: filtered.count,
                        onSwitchCamera: { camera.switchCamera() },
                        onSelectTier: { selectTier($0) },
                        onShowFilter: { showFilter = true },
                        onShowDiag: { showDiag = true })

                if needsModel {
                    messageView(
                        title: "缺少模型文件",
                        detail: "把 yolov8n.onnx / yolov8s.onnx / yolov8m.onnx 放进「文件」App 的「我的 iPhone → 天神辅助 → Models」目录，回到这里即可自动加载。",
                        action: nil
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear(perform: bootstrap)
        .onChange(of: pipeline.detections) { _, _ in recalc() }
        .onChange(of: settings.classFilter) { _, _ in recalc() }
        .onChange(of: settings.threshold) { _, _ in recalc() }
        .onChange(of: settings.drawMode) { _, _ in recalc() }
        .sheet(isPresented: $showNotice) {
            NoticeView {
                settings.noticeAcknowledged = true
                showNotice = false
            }
        }
        .sheet(isPresented: $showFilter) {
            FilterView(settings: settings)
        }
        .sheet(isPresented: $showDiag) {
            DiagView(settings: settings, pipeline: pipeline, camera: camera)
        }
    }

    // MARK: - 启动

    private func bootstrap() {
        guard !started else { return }
        started = true
        if !settings.noticeAcknowledged { showNotice = true }

        CameraController.requestCameraAccess { granted in
            guard granted else {
                camera.permissionDenied = true
                return
            }
            DispatchQueue.global(qos: .utility).async { ModelStore.seedBundledModels() }
            camera.prepare()
            let pipelineRef = pipeline
            camera.onFrame = { buffer, time in
                pipelineRef.handle(pixelBuffer: buffer, timestamp: time)
            }
            camera.start()
            compass.start()
            selectTier(settings.tier)
        }
    }

    private func selectTier(_ tier: ModelTier) {
        if ModelStore.isAvailable(tier) {
            settings.tier = tier
            pipeline.loadModel(tier: tier)
            needsModel = false
        } else if let fallback = ModelStore.availableTiers.first {
            settings.tier = fallback
            pipeline.loadModel(tier: fallback)
            needsModel = false
        } else {
            needsModel = true
        }
    }

    private func recalc() {
        filtered = pipeline.filtered(settings: settings)
    }

    // MARK: - 提示页

    private func messageView(title: String, detail: String, action: (() -> Void)?) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.horizontal, 34)
            if let action {
                Button("打开设置", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.82).ignoresSafeArea())
    }
}

#Preview {
    RootView()
}
