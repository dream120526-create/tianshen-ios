import AVFoundation
import CoreVideo
import Combine
import Foundation

/// 相机采集：后置/前置切换，竖屏输出，逐帧回调到检测管线。
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ts.camera.session")
    private let videoQueue = DispatchQueue(label: "ts.camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var isConfigured = false

    @Published private(set) var positionLabel: String = "后置"
    @Published private(set) var frameSize: CGSize = .zero
    @Published private(set) var running = false
    @Published var permissionDenied = false

    /// 仅视频队列访问，避免每帧跨线程读 @Published
    private var lastReportedSize: CGSize = .zero

    /// 每帧回调；在视频队列上执行，不要在里面做 UI 操作
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?

    func prepare() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            self.configure()
        }
    }

    private func configure() {
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            let denied = !Self.cameraAuthorized()
            DispatchQueue.main.async { self.permissionDenied = denied }
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        currentInput = input

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }

        session.commitConfiguration()
        isConfigured = true
        positionLabel = "后置"
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured { self.configure() }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.running = true }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.running = false }
            }
        }
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let target: AVCaptureDevice.Position = (self.currentInput?.device.position == .front) ? .back : .front
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: target),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            if let old = self.currentInput { self.session.removeInput(old) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            } else if let old = self.currentInput {
                self.session.addInput(old)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.positionLabel = (target == .front) ? "前置" : "后置"
            }
        }
    }

    static func cameraAuthorized() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .authorized || status == .notDetermined
    }

    static func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        if size != lastReportedSize {
            lastReportedSize = size
            DispatchQueue.main.async { [weak self] in self?.frameSize = size }
        }
        onFrame?(pixelBuffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }
}
