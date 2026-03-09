import SwiftUI
import Combine
import CoreMedia

// MARK: - GameState
/// Represents the current state of the game
enum GameState: Equatable {
    case waiting        // Waiting for player to show answer
    case correct        // Player answered correctly
    case incorrect      // Player answered incorrectly
    case noHand         // No hand detected
}

// MARK: - InputPhase
/// Tracks which digit the player is currently inputting
enum InputPhase: Equatable {
    case singleDigit    // Answer is 0-10, direct input
    case tensDigit      // Waiting for tens digit (first input for two-digit)
    case onesDigit      // Waiting for ones digit (second input for two-digit)
}

// MARK: - GameViewModel
/// Main view model that coordinates the game logic.
/// Connects camera input, hand detection, and math challenges.
@MainActor
class GameViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current math challenge being displayed
    @Published var currentChallenge: MathChallenge

    /// Current state of the game
    @Published var gameState: GameState = .noHand

    /// Current input phase for two-digit answers
    @Published var inputPhase: InputPhase = .singleDigit

    /// The confirmed tens digit (nil if not yet confirmed)
    @Published var confirmedTensDigit: Int? = nil

    /// The confirmed ones digit (nil if not yet confirmed)
    @Published var confirmedOnesDigit: Int? = nil

    /// Whether the last answer was correct (nil if not yet answered)
    @Published var wasCorrect: Bool? = nil

    /// Player's current score
    @Published var score: Int = 0

    /// Number of challenges completed
    @Published var challengesCompleted: Int = 0

    /// The number currently being shown by the player (0-10)
    @Published var displayedFingerCount: Int = 0

    /// Whether at least one hand is currently detected
    @Published var isHandDetected: Bool = false

    /// Number of hands detected (0, 1, or 2)
    @Published var handsDetected: Int = 0

    /// Palm positions for detected hands (normalized 0-1 coordinates)
    @Published var handPositions: [CGPoint] = []

    /// Time remaining in the countdown (seconds)
    @Published var timeRemaining: TimeInterval = 30

    /// Whether the game has ended (time ran out)
    @Published var isGameOver: Bool = false

    /// Drives the "+2" floating animation on correct answer
    @Published var showTimeBonus: Bool = false

    /// Hold-to-confirm progress (0.0 to 1.0)
    @Published var holdProgress: Double = 0

    /// Whether the game is in pre-game state (waiting for user to tap Start)
    @Published var isPreGame: Bool = true

    /// Current streak of consecutive correct answers
    @Published var streak: Int = 0

    /// Drives the "+5 STREAK" floating animation
    @Published var showStreakBonus: Bool = false

    /// Drives celebration particle effect on correct answer
    @Published var showCelebration: Bool = false

    /// Brief flash of the correct answer number (nil = hidden)
    @Published var flashAnswer: String? = nil

    // MARK: - Components

    /// Manages the camera session
    let cameraManager = CameraManager()

    /// Detects hand poses and counts fingers
    let handPoseDetector = HandPoseDetector()

    /// Generates math challenges
    private let challengeGenerator = MathChallengeGenerator()

    // MARK: - Private Properties

    /// Stores Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// How long the player must hold the answer (in seconds)
    private let requiredHoldTime: TimeInterval = 1.5

    /// Shorter hold time for undo gesture (10 fingers during ones phase)
    private let requiredUndoHoldTime: TimeInterval = 0.75

    /// Tracks how long current answer has been held
    private var holdStartTime: Date?

    /// The finger count when hold started
    private var heldFingerCount: Int?

    /// Stored reference to keep the frame bridge alive
    private var frameBridge: FrameDelegateBridge?

    /// Timer for updating hold progress continuously
    private var holdProgressTimer: AnyCancellable?

    /// The countdown timer subscription
    private var gameTimer: AnyCancellable?

    /// Absolute end time for the countdown (avoids floating-point drift)
    private var gameEndDate: Date?

    // MARK: - Initialization

    init() {
        // Generate the first challenge
        currentChallenge = challengeGenerator.generateChallenge()

        // Setup observation of hand detection results
        setupSubscriptions()

        // Connect camera frames to hand detector
        setupCameraDelegate()
    }

    // MARK: - Setup

    /// Subscribe to hand detector updates
    private func setupSubscriptions() {
        // Observe finger count changes
        handPoseDetector.$detectedFingerCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.handleFingerCountUpdate(count)
            }
            .store(in: &cancellables)

        // Observe hand detection status
        handPoseDetector.$isHandDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.isHandDetected = detected
                if !detected {
                    self?.gameState = .noHand
                    self?.resetHoldTimer()
                }
            }
            .store(in: &cancellables)

        // Observe hands count
        handPoseDetector.$handsDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.handsDetected = count
            }
            .store(in: &cancellables)

        // Observe hand positions for AR overlay
        handPoseDetector.$handPositions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] positions in
                self?.handPositions = positions
            }
            .store(in: &cancellables)
    }

    /// Connect camera output to hand detector
    private func setupCameraDelegate() {
        let detector = handPoseDetector
        let bridge = FrameDelegateBridge { buffer in
            detector.processFrame(buffer)
        }
        cameraManager.frameDelegate = bridge
        self.frameBridge = bridge
    }

    // MARK: - Game Logic

    /// Handle updates to the detected finger count
    private func handleFingerCountUpdate(_ count: Int) {
        // Don't process if showing result, game is over, or pre-game
        guard gameState != .correct && gameState != .incorrect && !isGameOver && !isPreGame else { return }

        // Don't process if no hand is actually detected (avoids ghost "0")
        guard handPoseDetector.isHandDetected else { return }

        displayedFingerCount = count

        // Check for reset gesture: 10 fingers while in ones digit phase
        if count == 10 && inputPhase == .onesDigit {
            if heldFingerCount != 10 {
                holdStartTime = Date()
                heldFingerCount = 10
                gameState = .waiting
                startHoldProgressTimer()
            }
            return
        }

        // For two-digit input, only accept 0-9
        let maxDigit = (inputPhase == .singleDigit) ? 10 : 9
        guard count <= maxDigit else {
            resetHoldTimer()
            return
        }

        // Accept ANY valid input - start/continue hold timer
        if heldFingerCount != count {
            // New number, start hold timer
            holdStartTime = Date()
            heldFingerCount = count
            gameState = .waiting
            startHoldProgressTimer()
        }
        // If same count, the progress timer is already running
    }

    /// Reset back to tens digit input (allows user to correct mistakes)
    private func resetToTensDigit() {
        resetHoldTimer()
        confirmedTensDigit = nil
        confirmedOnesDigit = nil
        inputPhase = .tensDigit
        gameState = .noHand
    }

    /// Called when the player has held a digit long enough
    private func confirmDigit(_ digit: Int) {
        resetHoldTimer()

        switch inputPhase {
        case .singleDigit:
            // Check if answer is correct
            checkAnswer(userAnswer: digit)

        case .tensDigit:
            // Tens digit confirmed, move to ones digit
            confirmedTensDigit = digit
            inputPhase = .onesDigit
            gameState = .noHand

        case .onesDigit:
            // Ones digit confirmed, now check full answer
            confirmedOnesDigit = digit
            let userAnswer = (confirmedTensDigit ?? 0) * 10 + digit
            checkAnswer(userAnswer: userAnswer)
        }
    }

    /// Check if the user's answer is correct
    private func checkAnswer(userAnswer: Int) {
        let isCorrect = userAnswer == currentChallenge.answer
        wasCorrect = isCorrect

        let delay: TimeInterval
        if isCorrect {
            SoundManager.shared.playCorrect()
            gameState = .correct
            score += currentChallenge.requiresTwoDigits ? 20 : 10
            challengesCompleted += 1
            streak += 1
            // Add 3 seconds to the timer
            timeRemaining += 3
            gameEndDate = gameEndDate?.addingTimeInterval(3)
            showTimeBonus = true
            showCelebration = true
            flashAnswer = "\(currentChallenge.answer)"
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.6))
                self?.flashAnswer = nil
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.8))
                self?.showTimeBonus = false
                self?.showCelebration = false
            }
            // Streak bonus: +5 seconds every 5 correct in a row
            if streak > 0 && streak.isMultiple(of: 5) {
                timeRemaining += 5
                gameEndDate = gameEndDate?.addingTimeInterval(5)
                showStreakBonus = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1.2))
                    self?.showStreakBonus = false
                }
            }
            delay = 1.0
        } else {
            SoundManager.shared.playIncorrect()
            gameState = .incorrect
            streak = 0
            delay = 1.5
        }

        // Generate new challenge after delay
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !self.isGameOver else { return }
            self.generateNewChallenge()
        }
    }

    /// Reset the answer hold timer
    private func resetHoldTimer() {
        holdStartTime = nil
        heldFingerCount = nil
        holdProgressTimer?.cancel()
        holdProgressTimer = nil
        holdProgress = 0
    }

    /// Generate a new math challenge
    private func generateNewChallenge() {
        currentChallenge = challengeGenerator.generateChallenge()
        confirmedTensDigit = nil
        confirmedOnesDigit = nil
        wasCorrect = nil

        // Set the appropriate input phase
        if currentChallenge.requiresTwoDigits {
            inputPhase = .tensDigit
        } else {
            inputPhase = .singleDigit
        }

        gameState = isHandDetected ? .waiting : .noHand
    }

    // MARK: - Lifecycle

    /// Start the game session (camera only, waits for user to tap Start)
    func startGame() {
        cameraManager.startSession()
        score = 0
        challengesCompleted = 0
        timeRemaining = 30
        isGameOver = false
        isPreGame = true
        showTimeBonus = false
        showStreakBonus = false
        showCelebration = false
        streak = 0
        holdProgress = 0
        resetHoldTimer()
        gameTimer?.cancel()
        gameTimer = nil
    }

    /// Called when user taps Start — applies settings, begins countdown and first challenge
    func beginCountdown(with settings: GameSettings) {
        challengeGenerator.apply(settings)
        timeRemaining = 30

        isPreGame = false
        generateNewChallenge()
        startTimer()
    }

    /// Stop the game session (camera stays running across rounds)
    func stopGame() {
        gameTimer?.cancel()
        gameTimer = nil
        holdProgressTimer?.cancel()
        holdProgressTimer = nil
    }

    /// Start the countdown timer
    private func startTimer() {
        gameEndDate = Date().addingTimeInterval(timeRemaining)
        gameTimer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self, let endDate = self.gameEndDate else { return }
                let remaining = endDate.timeIntervalSince(now)
                if remaining <= 0 {
                    self.timeRemaining = 0
                    self.endGame()
                } else {
                    self.timeRemaining = remaining
                }
            }
    }

    /// Start continuous hold progress updates
    private func startHoldProgressTimer() {
        holdProgressTimer?.cancel()
        holdProgress = 0
        holdProgressTimer = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let startTime = self.holdStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let isUndo = self.heldFingerCount == 10 && self.inputPhase == .onesDigit
                let holdTime = isUndo ? self.requiredUndoHoldTime : self.requiredHoldTime
                let progress = min(1.0, elapsed / holdTime)
                self.holdProgress = progress
                if progress >= 1.0 {
                    self.holdProgressTimer?.cancel()
                    self.holdProgressTimer = nil
                    if let count = self.heldFingerCount {
                        if count == 10 && self.inputPhase == .onesDigit {
                            self.resetToTensDigit()
                        } else {
                            self.confirmDigit(count)
                        }
                    }
                }
            }
    }

    /// End the game when time runs out
    private func endGame() {
        isGameOver = true
        gameTimer?.cancel()
        gameTimer = nil
        gameEndDate = nil
        resetHoldTimer()
        gameState = .noHand
    }

    /// Restart the game (called from Play Again button)
    func restartGame() {
        startGame()
    }

    /// Skip to next challenge (for testing/debugging)
    func skipChallenge() {
        generateNewChallenge()
    }
}

// MARK: - Frame Delegate Bridge
/// A bridge class to forward camera frames to the hand pose detector.
final class FrameDelegateBridge: CameraFrameDelegate, @unchecked Sendable {
    private let handler: @Sendable (CMSampleBuffer) -> Void

    init(handler: @escaping @Sendable (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func didCaptureFrame(_ sampleBuffer: CMSampleBuffer) {
        handler(sampleBuffer)
    }
}
