@preconcurrency import Vision
import CoreMedia
import SwiftUI
import Combine

// MARK: - HandPoseDetector
/// Detects hand poses in video frames using Apple's Vision framework.
/// Analyzes finger positions to count how many fingers are raised on both hands.
@MainActor
class HandPoseDetector: ObservableObject {

    // MARK: - Published Properties

    /// The total number of fingers currently detected as raised (0-10 for two hands)
    @Published var detectedFingerCount: Int = 0

    /// Whether at least one hand is currently detected in the frame
    @Published var isHandDetected: Bool = false

    /// Number of hands currently detected (0, 1, or 2)
    @Published var handsDetected: Int = 0

    /// Confidence level of the detection (0.0 to 1.0)
    @Published var confidence: Float = 0.0

    /// Palm center positions for each detected hand (normalized 0-1 coordinates)
    /// These can be used to overlay graphics on the hand
    @Published var handPositions: [CGPoint] = []

    // MARK: - Vision Components

    /// The Vision request for detecting hand poses
    /// Using nonisolated(unsafe) because Vision requests are thread-safe
    private nonisolated(unsafe) let handPoseRequest: VNDetectHumanHandPoseRequest

    /// Throttle detection to avoid overwhelming the system
    private nonisolated(unsafe) var lastProcessingTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.1 // Process 10 times per second

    // MARK: - Initialization

    init() {
        handPoseRequest = VNDetectHumanHandPoseRequest()
        // Detect up to 2 hands for counting 0-10
        handPoseRequest.maximumHandCount = 2
    }

    // MARK: - Detection

    /// Process a video frame to detect hand poses
    /// Called from background camera queue, hence nonisolated
    /// - Parameter sampleBuffer: The video frame from the camera
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Throttle processing to save CPU
        let now = Date()
        guard now.timeIntervalSince(lastProcessingTime) >= processingInterval else {
            return
        }
        lastProcessingTime = now

        // Get the pixel buffer from the sample
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Create a request handler for this frame
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            // Perform the hand pose detection
            try handler.perform([handPoseRequest])

            // Get all detected hands
            guard let observations = handPoseRequest.results, !observations.isEmpty else {
                // No hands detected
                Task { @MainActor [weak self] in
                    self?.isHandDetected = false
                    self?.handsDetected = 0
                    self?.detectedFingerCount = 0
                    self?.confidence = 0.0
                    self?.handPositions = []
                }
                return
            }

            // Count fingers on all detected hands and get palm positions
            var totalFingers = 0
            var totalConfidence: Float = 0.0
            var palmPositions: [CGPoint] = []

            for observation in observations {
                let fingerCount = countRaisedFingers(observation: observation)
                totalFingers += fingerCount
                totalConfidence += observation.confidence

                // Get palm center position for this hand
                if let palmCenter = getPalmCenter(observation: observation) {
                    palmPositions.append(palmCenter)
                }
            }

            // Average confidence across all hands
            let avgConfidence = totalConfidence / Float(observations.count)
            let handCount = observations.count
            let finalFingers = totalFingers
            let finalPalmPositions = palmPositions

            // Update published properties on main thread
            Task { @MainActor [weak self] in
                self?.isHandDetected = true
                self?.handsDetected = handCount
                self?.detectedFingerCount = finalFingers
                self?.confidence = avgConfidence
                self?.handPositions = finalPalmPositions
            }

        } catch {
            print("Hand pose detection error: \(error)")
        }
    }

    // MARK: - Finger Counting Logic

    /// Counts how many fingers are raised based on the hand pose observation.
    /// Uses the relative positions of finger tips and knuckles.
    /// - Parameter observation: The detected hand pose
    /// - Returns: Number of raised fingers (0-5)
    private nonisolated func countRaisedFingers(observation: VNHumanHandPoseObservation) -> Int {
        var raisedFingers = 0

        // Check thumb separately (moves differently than other fingers)
        if isThumbExtended(observation: observation) {
            raisedFingers += 1
        }

        // Check the four fingers (index, middle, ring, little)
        let fingerTips: [VNHumanHandPoseObservation.JointName] = [
            .indexTip, .middleTip, .ringTip, .littleTip
        ]

        let fingerPIPs: [VNHumanHandPoseObservation.JointName] = [
            .indexPIP, .middlePIP, .ringPIP, .littlePIP
        ]

        for (tip, pip) in zip(fingerTips, fingerPIPs) {
            guard let tipPoint = try? observation.recognizedPoint(tip),
                  let pipPoint = try? observation.recognizedPoint(pip) else {
                continue
            }

            // Skip low confidence points
            guard tipPoint.confidence > 0.3 && pipPoint.confidence > 0.3 else {
                continue
            }

            // Finger is extended if tip is above PIP (higher y value)
            let fingerExtended = tipPoint.location.y > pipPoint.location.y + 0.02
            if fingerExtended {
                raisedFingers += 1
            }
        }

        return raisedFingers
    }

    /// Determines if the thumb is extended outward from the palm.
    /// The thumb is considered extended ONLY when it points AWAY from the other fingers,
    /// NOT when it's folded across the palm or tucked in.
    /// - Parameter observation: The detected hand pose
    /// - Returns: True if thumb is extended outward (away from fingers)
    private nonisolated func isThumbExtended(observation: VNHumanHandPoseObservation) -> Bool {
        // Get thumb joints
        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let thumbCMC = try? observation.recognizedPoint(.thumbCMC) else {
            return false
        }

        // Get finger reference points to determine hand orientation
        guard let indexMCP = try? observation.recognizedPoint(.indexMCP),
              let littleMCP = try? observation.recognizedPoint(.littleMCP) else {
            return false
        }

        // Check confidence
        guard thumbTip.confidence > 0.3 &&
              thumbCMC.confidence > 0.3 &&
              indexMCP.confidence > 0.3 &&
              littleMCP.confidence > 0.3 else {
            return false
        }

        // Determine which side is "inside" the hand (toward pinky) vs "outside" (away from fingers)
        // The pinky MCP tells us which direction is "inside" the hand
        let pinkyDirection = littleMCP.location.x - indexMCP.location.x

        // The thumb base (CMC) is naturally on the "outside" of the hand
        // We check if the thumb TIP is also on the outside (same side as CMC relative to index)
        let thumbTipRelativeToIndex = thumbTip.location.x - indexMCP.location.x

        // Thumb is pointing INWARD (toward pinky) if the tip moved toward the pinky direction
        // Thumb is pointing OUTWARD if the tip is on the opposite side from the pinky

        // If pinky is to the right of index (pinkyDirection > 0):
        //   - Thumb CMC should be to the left of index (negative)
        //   - Thumb tip should ALSO be to the left (negative) to be "extended outward"
        //   - If thumb tip moved right (toward pinky), it's folded inward

        // If pinky is to the left of index (pinkyDirection < 0):
        //   - Thumb CMC should be to the right of index (positive)
        //   - Thumb tip should ALSO be to the right (positive) to be "extended outward"
        //   - If thumb tip moved left (toward pinky), it's folded inward

        // Simple check: thumb tip should be on the OPPOSITE side from the pinky
        let thumbTipIsOppositeFromPinky: Bool
        if pinkyDirection > 0 {
            // Pinky is to the right, so thumb should extend to the left
            thumbTipIsOppositeFromPinky = thumbTipRelativeToIndex < 0
        } else {
            // Pinky is to the left, so thumb should extend to the right
            thumbTipIsOppositeFromPinky = thumbTipRelativeToIndex > 0
        }

        // Also verify the thumb is actually extended (tip is away from CMC, not curled back)
        let thumbLength = hypot(
            thumbTip.location.x - thumbCMC.location.x,
            thumbTip.location.y - thumbCMC.location.y
        )

        // Minimum extension threshold (thumb should be somewhat extended, not fully curled)
        let isExtended = thumbLength > 0.08

        return thumbTipIsOppositeFromPinky && isExtended
    }

    // MARK: - Palm Position

    /// Gets the center of the palm for overlaying graphics
    /// - Parameter observation: The detected hand pose
    /// - Returns: Normalized point (0-1) representing palm center, or nil if not available
    private nonisolated func getPalmCenter(observation: VNHumanHandPoseObservation) -> CGPoint? {
        // Use the middle of the palm - average of wrist and middle finger MCP
        guard let wrist = try? observation.recognizedPoint(.wrist),
              let middleMCP = try? observation.recognizedPoint(.middleMCP),
              let indexMCP = try? observation.recognizedPoint(.indexMCP),
              let ringMCP = try? observation.recognizedPoint(.ringMCP) else {
            return nil
        }

        guard wrist.confidence > 0.3 && middleMCP.confidence > 0.3 else {
            return nil
        }

        // Calculate palm center as average of key points
        let centerX = (wrist.location.x + middleMCP.location.x + indexMCP.location.x + ringMCP.location.x) / 4
        let centerY = (wrist.location.y + middleMCP.location.y + indexMCP.location.y + ringMCP.location.y) / 4

        // Vision coordinates: origin is bottom-left, y increases upward
        // We need to flip Y for SwiftUI (origin top-left)
        return CGPoint(x: centerX, y: 1 - centerY)
    }
}
