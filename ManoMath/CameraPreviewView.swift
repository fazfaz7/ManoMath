import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView
/// A SwiftUI view that displays the live camera feed.
/// Wraps AVCaptureVideoPreviewLayer in a UIViewRepresentable.
struct CameraPreviewView: UIViewRepresentable {

    /// The capture session to display
    let session: AVCaptureSession

    /// Creates the UIView that will display the camera preview
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        // Mirror the preview for front camera (feels more natural)
        view.previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        view.previewLayer.connection?.isVideoMirrored = true

        return view
    }

    /// Updates the view when SwiftUI state changes
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update session if needed
        uiView.previewLayer.session = session
    }
}

// MARK: - CameraPreviewUIView
/// UIView subclass that hosts the AVCaptureVideoPreviewLayer.
/// Using a subclass ensures proper layer sizing.
class CameraPreviewUIView: UIView {

    /// The preview layer that displays the camera feed
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    /// Add the preview layer to this view
    private func setupLayer() {
        layer.addSublayer(previewLayer)
    }

    /// Ensure the preview layer fills the entire view
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
