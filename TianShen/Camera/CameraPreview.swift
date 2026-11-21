import AVFoundation
import SwiftUI
import UIKit

/// 相机预览：AVCaptureVideoPreviewLayer，等比填充全屏。
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
        DispatchQueue.main.async {
            guard let connection = uiView.previewLayer.connection else { return }
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = mirrored
            }
        }
    }
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
