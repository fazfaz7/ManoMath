import AVFoundation
import SwiftUI
import Combine

// MARK: - Video Frame Delegate Protocol
/// Protocol for receiving video frames from the camera
protocol CameraFrameDelegate: AnyObject, Sendable {
    func didCaptureFrame(_ sampleBuffer: CMSampleBuffer)
}

// MARK: - CameraManager
/// Manages the device camera session for capturing video frames.
/// This class handles camera setup, permissions, and frame delivery.
/// Conforms to @unchecked Sendable because we manually ensure thread safety
/// by performing all camera operations on the dedicated sessionQueue.
final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties (Main Actor isolated)

    /// Indicates whether the camera is currently running
    @MainActor @Published var isRunning = false

    /// Stores any error message for display to the user
    @MainActor @Published var errorMessage: String?

    // MARK: - Camera Components

    /// The main capture session that coordinates camera input and output
    let captureSession = AVCaptureSession()

    /// Output for receiving video frames to process
    private let videoOutput = AVCaptureVideoDataOutput()

    /// Dedicated queue for processing video frames (off main thread)
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    /// Delegate that will receive each video frame for processing
    weak var frameDelegate: CameraFrameDelegate?

    // MARK: - Setup

    /// Configures and starts the camera session
    /// Call this when the view appears
    func startSession() {
        sessionQueue.async {
            guard !self.captureSession.isRunning else { return }
            self.configureSession()
        }
    }

    /// Stops the camera session
    /// Call this when the view disappears to save battery
    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor in
                    self.isRunning = false
                }
            }
        }
    }

    /// Internal method to configure the capture session
    private func configureSession() {
        // Check camera authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            // Request permission if not yet determined
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async {
                        self.setupCamera()
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Camera access denied. Please enable in Settings."
                    }
                }
            }
        case .denied, .restricted:
            Task { @MainActor in
                self.errorMessage = "Camera access denied. Please enable in Settings."
            }
        @unknown default:
            Task { @MainActor in
                self.errorMessage = "Unknown camera authorization status."
            }
        }
    }

    /// Sets up the camera input and output
    private func setupCamera() {
        captureSession.beginConfiguration()

        // Set session preset for good balance of quality and performance
        captureSession.sessionPreset = .high

        // Find the front camera (so user can see themselves)
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            Task { @MainActor in
                self.errorMessage = "No front camera available."
            }
            return
        }

        do {
            // Create and add camera input
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            // Configure video output for frame processing
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            // Set video orientation to portrait and mirror for front camera
            if let connection = videoOutput.connection(with: .video) {
                // Use videoRotationAngle (iOS 17+) or fallback to videoOrientation
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90 // Portrait orientation
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }

                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }

            captureSession.commitConfiguration()

            // Start the session
            captureSession.startRunning()

            Task { @MainActor in
                self.isRunning = true
            }

        } catch {
            let errorDescription = error.localizedDescription
            Task { @MainActor in
                self.errorMessage = "Failed to setup camera: \(errorDescription)"
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Called for each video frame captured by the camera
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameDelegate?.didCaptureFrame(sampleBuffer)
    }
}
