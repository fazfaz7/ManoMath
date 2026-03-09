import SwiftUI
import Combine

// MARK: - Color Theme
extension Color {
    static let appBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.19)
    static let accentPrimary = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let accentSuccess = Color(red: 0.3, green: 0.85, blue: 0.5)
    static let accentWarning = Color(red: 1.0, green: 0.7, blue: 0.3)
    static let accentDanger = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let borderSubtle = Color.white.opacity(0.1)
    static let borderFaint = Color.white.opacity(0.06)
    static let controlInactive = Color.white.opacity(0.06)
    static let dimContent = Color.white.opacity(0.15)
}

// MARK: - Design Tokens
enum DesignTokens {
    static let radiusSmall: CGFloat = 12
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 28

    static let springBouncy = Animation.spring(response: 0.45, dampingFraction: 0.65)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.75)
}

// MARK: - Adaptive Scale
/// Scales a point value for the current device: 1.45× on iPad, 1.0× on iPhone.
@MainActor
func scaled(_ pt: CGFloat) -> CGFloat {
    UIDevice.current.userInterfaceIdiom == .pad ? pt * 1.45 : pt
}

// MARK: - Button Style Helper
extension View {
    func primaryButtonStyle() -> some View {
        self.font(.system(size: scaled(20), weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: scaled(260))
            .padding(.vertical, scaled(16))
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(LinearGradient(
                        colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: .accentPrimary.opacity(0.35), radius: 12, y: 4)
            )
    }
}

// MARK: - App Phase
private enum AppPhase {
    case splash
    case onboarding
    case loading
    case settings
    case tutorial
    case warmup
    case countdown
    case playing
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var appPhase: AppPhase = .splash
    @State private var gameSettings = GameSettings()
    @AppStorage("highScore") private var highScore = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
        switch appPhase {
        case .splash:
            SplashView(
                isFirstLaunch: !hasCompletedOnboarding,
                onPlay: {
                    withAnimation(DesignTokens.springGentle) {
                        appPhase = .settings
                    }
                },
                onLearn: {
                    withAnimation(DesignTokens.springGentle) {
                        appPhase = hasCompletedOnboarding ? .tutorial : .onboarding
                    }
                }
            )
        case .onboarding:
            OnboardingView(onFinish: {
                hasCompletedOnboarding = true
                withAnimation(DesignTokens.springGentle) {
                    appPhase = .loading
                }
            })
        case .loading:
            LoadingScreen()
                .onAppear {
                    SoundManager.shared.warmUp()
                    Task {
                        try? await Task.sleep(for: .seconds(0.8))
                        withAnimation(DesignTokens.springGentle) {
                            appPhase = .settings
                        }
                    }
                }
        case .tutorial:
            TutorialView(onFinish: {
                withAnimation(DesignTokens.springGentle) {
                    appPhase = .settings
                }
            })
        case .settings:
            SettingsScreen(settings: $gameSettings, onHowToPlay: {
                withAnimation(DesignTokens.springGentle) {
                    appPhase = .tutorial
                }
            }, onStart: {
                viewModel.startGame()
                withAnimation(DesignTokens.springSnappy) {
                    // Skip warmup if camera is already running (Play Again case)
                    appPhase = viewModel.cameraManager.isRunning ? .countdown : .warmup
                }
            })
        case .warmup:
            CameraWarmupScreen(cameraManager: viewModel.cameraManager, onReady: {
                withAnimation(DesignTokens.springGentle) {
                    appPhase = .countdown
                }
            })
        case .countdown, .playing:
            ZStack {
                // Persistent camera layer shared between countdown and game
                CameraPreviewView(session: viewModel.cameraManager.captureSession)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.75),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                if appPhase == .countdown {
                    CountdownScreen(
                        isHandDetected: $viewModel.isHandDetected,
                        onGo: {
                            viewModel.beginCountdown(with: gameSettings)
                            withAnimation(DesignTokens.springSnappy) {
                                appPhase = .playing
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    gameContent
                        .transition(.opacity)
                }
            }
        }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var gameContent: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Timer bar at the very top
                TimerBar(timeRemaining: viewModel.timeRemaining)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Question below timer
                QuestionBar(challenge: viewModel.currentChallenge, wasCorrect: viewModel.wasCorrect)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                Spacer()

                // Streak counter
                if viewModel.streak >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.accentWarning)
                        Text("\(viewModel.streak)")
                            .font(.system(size: scaled(18), weight: .bold, design: .rounded))
                            .foregroundColor(.accentWarning)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.accentWarning.opacity(0.15))
                    )
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                // Answer section at the bottom
                AnswerSection(
                    challenge: viewModel.currentChallenge,
                    inputPhase: viewModel.inputPhase,
                    confirmedTens: viewModel.confirmedTensDigit,
                    confirmedOnes: viewModel.confirmedOnesDigit,
                    currentCount: viewModel.displayedFingerCount,
                    gameState: viewModel.gameState,
                    holdProgress: viewModel.holdProgress
                )
                .padding(.horizontal)
                .padding(.bottom, 40)
            }

            // Flash correct answer
            if let answer = viewModel.flashAnswer {
                AnswerFlash(text: answer)
                    .allowsHitTesting(false)
            }

            // Celebration particles
            if viewModel.showCelebration {
                CelebrationParticles()
                    .allowsHitTesting(false)
            }

            // "+3s" time bonus animation
            if viewModel.showTimeBonus {
                Text("+3s")
                    .font(.system(size: scaled(32), weight: .bold, design: .rounded))
                    .foregroundColor(.accentSuccess)
                    .shadow(color: .accentSuccess.opacity(0.6), radius: 8)
                    .transition(.asymmetric(
                        insertion: .offset(y: 20).combined(with: .opacity),
                        removal: .offset(y: -30).combined(with: .opacity)
                    ))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 52)
            }

            // Streak bonus animation
            if viewModel.showStreakBonus {
                VStack(spacing: 4) {
                    Text("+5s STREAK!")
                        .font(.system(size: scaled(32), weight: .heavy, design: .rounded))
                        .foregroundColor(.accentWarning)
                        .shadow(color: .accentWarning.opacity(0.6), radius: 10)
                    Text("\(viewModel.streak) in a row")
                        .font(.system(size: scaled(16), weight: .semibold, design: .rounded))
                        .foregroundColor(.accentWarning.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
                .transition(.asymmetric(
                    insertion: .offset(y: 20).combined(with: .opacity),
                    removal: .offset(y: -30).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // Error overlay
            if let error = viewModel.cameraManager.errorMessage {
                ErrorOverlayView(message: error)
            }

            // Game over overlay
            if viewModel.isGameOver {
                GameOverView(
                    score: viewModel.score,
                    challengesCompleted: viewModel.challengesCompleted,
                    highScore: $highScore,
                    onPlayAgain: {
                        viewModel.restartGame()
                        withAnimation(DesignTokens.springSnappy) {
                            appPhase = .settings
                        }
                    }
                )
            }
        }
        .animation(DesignTokens.springBouncy, value: viewModel.showTimeBonus)
        .animation(DesignTokens.springBouncy, value: viewModel.showStreakBonus)
        .animation(DesignTokens.springSnappy, value: viewModel.showCelebration)
        .animation(DesignTokens.springSnappy, value: viewModel.streak)
        .onDisappear { viewModel.stopGame() }
    }
}

// MARK: - Celebration Particles
// MARK: - Answer Flash
struct AnswerFlash: View {
    let text: String

    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0
    @State private var xOffset: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var glowRadius: CGFloat = 0

    var body: some View {
        Text(text)
            .font(.system(size: scaled(120), weight: .heavy, design: .rounded))
            .foregroundColor(.accentSuccess)
            .shadow(color: .accentSuccess.opacity(0.8), radius: glowRadius)
            .shadow(color: .accentSuccess.opacity(0.4), radius: glowRadius * 2)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: xOffset, y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // Random position toward an edge
                let side = Int.random(in: 0...3)
                switch side {
                case 0:
                    xOffset = CGFloat.random(in: -100 ... -30)
                    yOffset = CGFloat.random(in: -220 ... -120)
                case 1:
                    xOffset = CGFloat.random(in: 30...100)
                    yOffset = CGFloat.random(in: -220 ... -120)
                case 2:
                    xOffset = CGFloat.random(in: -100 ... -30)
                    yOffset = CGFloat.random(in: 40...140)
                default:
                    xOffset = CGFloat.random(in: 30...100)
                    yOffset = CGFloat.random(in: 40...140)
                }
                rotation = Double.random(in: -12...12)

                // Pop in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    scale = 1.0
                    opacity = 0.85
                    glowRadius = 20
                }
                // Smooth fade out
                withAnimation(.easeOut(duration: 0.35).delay(0.25)) {
                    scale = 1.15
                    opacity = 0
                    glowRadius = 0
                }
            }
    }
}

// MARK: - Celebration Particles
struct CelebrationParticles: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, scale: CGFloat)] = []
    @State private var animate = false

    private let colors: [Color] = [.accentPrimary, .accentSuccess, .accentWarning, .purple, .pink, .yellow, .cyan, .mint]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 8 * p.scale, height: 8 * p.scale)
                        .position(
                            x: animate ? p.x : geo.size.width / 2,
                            y: animate ? p.y : geo.size.height * 0.7
                        )
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<12).map { i in
                    (
                        id: i,
                        x: CGFloat.random(in: geo.size.width * 0.1...geo.size.width * 0.9),
                        y: CGFloat.random(in: geo.size.height * 0.3...geo.size.height * 0.7),
                        color: colors[i % colors.count],
                        scale: CGFloat.random(in: 0.8...1.8)
                    )
                }
                withAnimation(.easeOut(duration: 0.8)) {
                    animate = true
                }
            }
        }
    }
}

// MARK: - Question Bar (Top)
struct QuestionBar: View {
    let challenge: MathChallenge
    var wasCorrect: Bool? = nil

    @State private var pop: CGFloat = 1.0

    private var barBackground: Color {
        switch wasCorrect {
        case .some(true): return .accentSuccess.opacity(0.25)
        case .some(false): return .accentDanger.opacity(0.25)
        case .none: return .cardBackground.opacity(0.9)
        }
    }

    private var barBorder: Color {
        switch wasCorrect {
        case .some(true): return .accentSuccess.opacity(0.6)
        case .some(false): return .accentDanger.opacity(0.6)
        case .none: return .borderSubtle
        }
    }

    var body: some View {
        Text(challenge.questionText)
            .font(.system(size: scaled(44), weight: .bold, design: .rounded))
            .foregroundColor(.textPrimary)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(barBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .stroke(barBorder, lineWidth: wasCorrect != nil ? 2 : 1)
            )
            .scaleEffect(pop)
            .animation(DesignTokens.springSnappy, value: wasCorrect != nil)
            .onChange(of: challenge.id) { _, _ in
                // Bounce in new question
                pop = 0.85
                withAnimation(DesignTokens.springBouncy) {
                    pop = 1.0
                }
            }
    }
}


// MARK: - Answer Section (Bottom)
struct AnswerSection: View {
    let challenge: MathChallenge
    let inputPhase: InputPhase
    let confirmedTens: Int?
    let confirmedOnes: Int?
    let currentCount: Int
    let gameState: GameState
    var holdProgress: Double = 0

    @State private var shakeOffset: CGFloat = 0
    @State private var correctScale: CGFloat = 1.0

    private var isUndoInProgress: Bool {
        inputPhase == .onesDigit && currentCount == 10 && gameState == .waiting
    }

    var body: some View {
        VStack(spacing: 12) {
            // Status message
            Text(statusMessage)
                .font(.system(size: scaled(17), weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)

            if challenge.requiresTwoDigits {
                // Two digit input
                HStack(spacing: 12) {
                    DigitBox(
                        digit: confirmedTens,
                        isActive: inputPhase == .tensDigit && gameState != .correct && gameState != .incorrect,
                        currentCount: inputPhase == .tensDigit ? currentCount : nil,
                        isWrong: gameState == .incorrect,
                        holdProgress: inputPhase == .tensDigit ? holdProgress : 0,
                        gameState: gameState
                    )

                    DigitBox(
                        digit: confirmedOnes,
                        isActive: inputPhase == .onesDigit && gameState != .correct && gameState != .incorrect,
                        currentCount: isUndoInProgress ? nil : (inputPhase == .onesDigit ? currentCount : nil),
                        isWrong: gameState == .incorrect,
                        holdProgress: inputPhase == .onesDigit ? holdProgress : 0,
                        gameState: gameState,
                        isUndoing: isUndoInProgress
                    )
                }
            } else {
                // Single digit display
                SingleDigitBox(
                    currentCount: currentCount,
                    targetCount: challenge.answer,
                    gameState: gameState,
                    holdProgress: holdProgress
                )
            }

            // Fixed-height hint row — always occupies space to prevent layout shifts
            Text(bottomHintText)
                .font(.caption)
                .foregroundColor(bottomHintColor)
                .opacity(bottomHintText.isEmpty ? 0 : 1)
                .frame(height: 18)
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(Color.cardBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .stroke(borderColor, lineWidth: 1)
        )
        .scaleEffect(correctScale)
        .offset(x: shakeOffset)
        .onChange(of: gameState) { _, newState in
            if newState == .correct {
                withAnimation(DesignTokens.springBouncy) {
                    correctScale = 1.05
                }
                withAnimation(DesignTokens.springBouncy.delay(0.15)) {
                    correctScale = 1.0
                }
            } else if newState == .incorrect {
                // Shake animation
                withAnimation(.linear(duration: 0.06)) { shakeOffset = -8 }
                withAnimation(.linear(duration: 0.06).delay(0.06)) { shakeOffset = 8 }
                withAnimation(.linear(duration: 0.06).delay(0.12)) { shakeOffset = -6 }
                withAnimation(.linear(duration: 0.06).delay(0.18)) { shakeOffset = 6 }
                withAnimation(.linear(duration: 0.06).delay(0.24)) { shakeOffset = 0 }
            }
        }
    }

    private var statusMessage: String {
        switch gameState {
        case .correct:
            return "Correct! +\(challenge.requiresTwoDigits ? 20 : 10) pts"
        case .incorrect:
            return "Wrong!"
        case .waiting:
            if inputPhase == .onesDigit && currentCount == 10 {
                return "Hold to undo..."
            }
            return "Hold steady..."
        case .noHand:
            return "Show your hand"
        }
    }

    private var statusColor: Color {
        switch gameState {
        case .correct: return .accentSuccess
        case .incorrect: return .accentWarning
        default: return .textSecondary
        }
    }

    private var bottomHintText: String {
        if gameState == .incorrect {
            return "Correct answer: \(challenge.answer)"
        } else if challenge.requiresTwoDigits && inputPhase == .onesDigit && gameState != .correct {
            return "10 fingers to undo"
        }
        return " "
    }

    private var bottomHintColor: Color {
        if gameState == .incorrect {
            return .accentSuccess
        }
        return .textSecondary
    }

    private var borderColor: Color {
        switch gameState {
        case .correct: return Color.accentSuccess.opacity(0.4)
        case .incorrect: return Color.accentWarning.opacity(0.3)
        default: return .borderSubtle
        }
    }
}

struct DigitBox: View {
    let digit: Int?
    let isActive: Bool
    let currentCount: Int?
    var isWrong: Bool = false
    var holdProgress: Double = 0
    var gameState: GameState = .noHand
    var isUndoing: Bool = false

    @State private var bounceScale: CGFloat = 1.0

    private var fillColor: Color {
        isUndoing ? Color.accentWarning.opacity(0.2) : Color.accentPrimary.opacity(0.2)
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(backgroundColor)
                .frame(width: scaled(72), height: scaled(88))

            // Hold progress fill (bottom to top)
            if isActive && holdProgress > 0 && digit == nil {
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(fillColor)
                    .frame(width: scaled(72), height: scaled(88))
                    .mask(
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: scaled(88) * (1 - holdProgress))
                            Color.white
                                .frame(height: scaled(88) * holdProgress)
                        }
                        .frame(width: scaled(72), height: scaled(88))
                    )
            }

            // Border
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .stroke(borderColor, lineWidth: isActive ? 2 : 1)
                .frame(width: scaled(72), height: scaled(88))

            // Content: undo icon or digit text
            if isUndoing {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.accentWarning)
                    .transition(.scale.combined(with: .opacity))
            } else if let confirmed = digit {
                Text("\(confirmed)")
                    .font(.system(size: scaled(36), weight: .bold, design: .rounded))
                    .foregroundColor(isWrong ? .accentWarning : .accentSuccess)
            } else if let current = currentCount, isActive, gameState != .noHand {
                Text("\(current)")
                    .font(.system(size: scaled(36), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            } else {
                Text("–")
                    .font(.system(size: scaled(32), weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary.opacity(0.4))
            }
        }
        .shadow(color: isActive ? (isUndoing ? Color.accentWarning.opacity(0.2) : Color.accentPrimary.opacity(0.2)) : .clear, radius: 8, y: 2)
        .scaleEffect(bounceScale)
        .animation(DesignTokens.springSnappy, value: isUndoing)
        .onChange(of: digit) { _, newDigit in
            if newDigit != nil {
                withAnimation(DesignTokens.springBouncy) {
                    bounceScale = 1.1
                }
                withAnimation(DesignTokens.springBouncy.delay(0.1)) {
                    bounceScale = 1.0
                }
            }
        }
    }

    private var backgroundColor: Color {
        if isUndoing {
            return Color.accentWarning.opacity(0.1)
        } else if isWrong && digit != nil {
            return Color.accentWarning.opacity(0.15)
        } else if digit != nil {
            return Color.accentSuccess.opacity(0.15)
        } else if isActive {
            return Color.accentPrimary.opacity(0.1)
        }
        return .controlInactive
    }

    private var borderColor: Color {
        if isUndoing {
            return Color.accentWarning.opacity(0.5)
        } else if isWrong && digit != nil {
            return Color.accentWarning.opacity(0.5)
        } else if digit != nil {
            return Color.accentSuccess.opacity(0.5)
        } else if isActive {
            return Color.accentPrimary.opacity(0.4)
        }
        return .borderSubtle
    }
}

struct SingleDigitBox: View {
    let currentCount: Int
    let targetCount: Int
    let gameState: GameState
    var holdProgress: Double = 0

    @State private var bounceScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0

    private var displayText: String {
        if gameState == .noHand { return "–" }
        return "\(currentCount)"
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(backgroundColor)
                .frame(width: scaled(100), height: scaled(88))

            // Hold progress fill (bottom to top)
            if holdProgress > 0 && gameState == .waiting {
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(Color.accentPrimary.opacity(0.2))
                    .frame(width: scaled(100), height: scaled(88))
                    .mask(
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: scaled(88) * (1 - holdProgress))
                            Color.white
                                .frame(height: scaled(88) * holdProgress)
                        }
                        .frame(width: scaled(100), height: scaled(88))
                    )
            }

            // Border
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .stroke(borderColor, lineWidth: 2)
                .frame(width: scaled(100), height: scaled(88))

            // Text
            Text(displayText)
                .font(.system(size: scaled(48), weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .scaleEffect(bounceScale)
        .offset(x: shakeOffset)
        .onChange(of: gameState) { _, newState in
            if newState == .correct {
                withAnimation(DesignTokens.springBouncy) {
                    bounceScale = 1.1
                }
                withAnimation(DesignTokens.springBouncy.delay(0.1)) {
                    bounceScale = 1.0
                }
            } else if newState == .incorrect {
                withAnimation(.linear(duration: 0.06)) { shakeOffset = -8 }
                withAnimation(.linear(duration: 0.06).delay(0.06)) { shakeOffset = 8 }
                withAnimation(.linear(duration: 0.06).delay(0.12)) { shakeOffset = -6 }
                withAnimation(.linear(duration: 0.06).delay(0.18)) { shakeOffset = 6 }
                withAnimation(.linear(duration: 0.06).delay(0.24)) { shakeOffset = 0 }
            }
        }
    }

    private var textColor: Color {
        switch gameState {
        case .correct: return .accentSuccess
        case .incorrect: return .accentWarning
        default: return .textPrimary
        }
    }

    private var backgroundColor: Color {
        switch gameState {
        case .correct: return Color.accentSuccess.opacity(0.15)
        case .incorrect: return Color.accentWarning.opacity(0.1)
        default: return .controlInactive
        }
    }

    private var borderColor: Color {
        switch gameState {
        case .correct: return Color.accentSuccess.opacity(0.5)
        case .incorrect: return Color.accentWarning.opacity(0.4)
        default: return .borderSubtle
        }
    }
}

// MARK: - Settings Screen (Full Page)
struct SettingsScreen: View {
    @Binding var settings: GameSettings
    let onHowToPlay: () -> Void
    let onStart: () -> Void

    @State private var iconFloat = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // Subtle radial gradient background
            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            // How to Play icon — top-trailing corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: onHowToPlay) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: scaled(22), weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(16)
                    }
                }
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    Image(systemName: "hand.raised.fingers.spread")
                        .font(.system(size: scaled(48), weight: .light))
                        .foregroundColor(.accentPrimary)
                        .offset(y: iconFloat ? -6 : 6)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: iconFloat
                        )

                    Text("Ready?")
                        .font(.system(size: scaled(38), weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text("30 seconds. Answer as many as you can.")
                        .font(.system(size: scaled(15), weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                }

                Spacer().frame(height: 36)

                // Settings
                VStack(spacing: 24) {
                    // Hands
                    SettingRow(label: "Hands", systemIcon: "hand.raised") {
                        SegmentedPicker(
                            options: HandMode.allCases,
                            selected: $settings.handMode,
                            label: { $0.rawValue }
                        )
                    }

                    // Single-hand note
                    if settings.handMode.isSingleHand {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                            Text("Answers limited to 0–5")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.accentPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -8)
                    }

                    // Difficulty
                    SettingRow(label: "Difficulty", systemIcon: "speedometer") {
                        SegmentedPicker(
                            options: [MathChallengeGenerator.Difficulty.easy, .medium, .hard],
                            selected: $settings.difficulty,
                            label: { d in
                                switch d {
                                case .easy: return "Easy"
                                case .medium: return "Medium"
                                case .hard: return "Hard"
                                }
                            }
                        )
                    }
                    .opacity(settings.handMode.isSingleHand ? 0.35 : 1.0)
                    .disabled(settings.handMode.isSingleHand)

                    // Operations
                    SettingRow(label: "Operations", systemIcon: "plus.forwardslash.minus") {
                        OperationToggles(selected: $settings.operations)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                                .stroke(Color.borderFaint, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // Start button
                Button(action: onStart) {
                    Text("Start")
                        .primaryButtonStyle()
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { iconFloat = true }
        .animation(DesignTokens.springSnappy, value: settings.handMode)
    }
}

// MARK: - Tip Card
struct TipCard: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Setting Row
private struct SettingRow<Content: View>: View {
    let label: String
    let systemIcon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentPrimary)
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            content
        }
    }
}

// MARK: - Segmented Picker
private struct SegmentedPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(DesignTokens.springSnappy) {
                        selected = option
                    }
                } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(selected == option ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                .fill(selected == option ? Color.accentPrimary : .controlInactive)
                        )
                }
            }
        }
    }
}

// MARK: - Operation Toggles
private struct OperationToggles: View {
    @Binding var selected: Set<MathChallengeGenerator.OperationType>

    private let ops: [(MathChallengeGenerator.OperationType, String)] = [
        (.addition, "+"), (.subtraction, "−"), (.multiplication, "×"), (.division, "÷")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ops, id: \.0) { op, symbol in
                Button {
                    withAnimation(DesignTokens.springSnappy) {
                        if selected.contains(op) {
                            if selected.count > 1 {
                                selected.remove(op)
                            }
                        } else {
                            selected.insert(op)
                        }
                    }
                } label: {
                    Text(symbol)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(selected.contains(op) ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                .fill(selected.contains(op) ? Color.accentPrimary : .controlInactive)
                        )
                }
            }
        }
    }
}

// MARK: - Timer Bar
struct TimerBar: View {
    let timeRemaining: TimeInterval
    let maxTime: TimeInterval = 30

    @State private var pulse = false
    @State private var timePulse = false

    private var fraction: CGFloat {
        min(1, CGFloat(timeRemaining / maxTime))
    }

    private var barColor: Color {
        if timeRemaining > 10 {
            return .accentPrimary
        } else if timeRemaining > 5 {
            return .accentWarning
        } else {
            return .accentDanger
        }
    }

    private var isUrgent: Bool {
        timeRemaining <= 5 && timeRemaining > 0
    }

    var body: some View {
        VStack(spacing: 4) {
            // Time text
            Text(String(format: "%.1fs", timeRemaining))
                .font(.system(size: scaled(18), weight: .bold, design: .rounded))
                .foregroundColor(barColor)
                .scaleEffect(timePulse ? 1.15 : 1.0)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.borderSubtle)

                    // Filled portion with gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * fraction)
                        .animation(.linear(duration: 0.05), value: fraction)
                }
            }
            .frame(height: 8)
            .opacity(isUrgent ? (pulse ? 0.5 : 1.0) : 1.0)
            .animation(
                isUrgent
                    ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true)
                    : .default,
                value: isUrgent
            )
        }
        .padding(.horizontal, 4)
        .onChange(of: isUrgent) { _, newValue in
            pulse = newValue
            timePulse = newValue
        }
        .animation(
            isUrgent
                ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                : .default,
            value: timePulse
        )
    }
}

// MARK: - Game Over View
struct GameOverView: View {
    let score: Int
    let challengesCompleted: Int
    @Binding var highScore: Int
    let onPlayAgain: () -> Void

    @State private var isNewHighScore = false
    @State private var appeared = false
    @State private var displayedScore = 0
    @State private var trophyRotation: Double = 0
    @State private var showElements: [Bool] = Array(repeating: false, count: 5)

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            // Card
            VStack(spacing: 20) {
                // Title
                Text("Time's Up!")
                    .font(.system(size: scaled(36), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .opacity(showElements[0] ? 1 : 0)
                    .offset(y: showElements[0] ? 0 : 10)

                // Score
                VStack(spacing: 4) {
                    Text("Score")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text("\(displayedScore)")
                        .font(.system(size: scaled(56), weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentPrimary, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .opacity(showElements[1] ? 1 : 0)
                .offset(y: showElements[1] ? 0 : 10)

                // Challenges solved
                Text("\(challengesCompleted) challenge\(challengesCompleted == 1 ? "" : "s") solved")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .opacity(showElements[2] ? 1 : 0)
                    .offset(y: showElements[2] ? 0 : 10)

                Divider()
                    .background(Color.borderSubtle)

                // High score
                VStack(spacing: 4) {
                    if isNewHighScore {
                        Text("New High Score!")
                            .font(.headline)
                            .foregroundColor(.accentSuccess)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.accentWarning)
                            .rotationEffect(.degrees(trophyRotation))
                        Text("Best: \(highScore)")
                            .font(.system(size: scaled(20), weight: .semibold, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }
                }
                .opacity(showElements[3] ? 1 : 0)
                .offset(y: showElements[3] ? 0 : 10)

                // Play Again button
                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .primaryButtonStyle()
                }
                .padding(.top, 8)
                .opacity(showElements[4] ? 1 : 0)
                .offset(y: showElements[4] ? 0 : 10)

                Text("Sound effects by Bertrof via Freesound.org (CC BY 3.0)")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.textSecondary.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 40)
            .scaleEffect(appeared ? 1 : 0.6)
            .offset(y: appeared ? 0 : 40)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            // Check and update high score
            if score > highScore {
                highScore = score
                isNewHighScore = true
            }
            // Entrance animation
            withAnimation(DesignTokens.springBouncy) {
                appeared = true
            }
            // Staggered element entrance
            for i in 0..<5 {
                withAnimation(DesignTokens.springGentle.delay(Double(i) * 0.15 + 0.2)) {
                    showElements[i] = true
                }
            }
            // Score counter animation
            animateScore()
            // Trophy wobble
            if isNewHighScore {
                withAnimation(.easeInOut(duration: 0.3).delay(0.8).repeatCount(3, autoreverses: true)) {
                    trophyRotation = 15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        trophyRotation = 0
                    }
                }
            }
        }
    }

    private func animateScore() {
        let steps = 30
        let delay = 1.0 / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * delay + 0.4) {
                displayedScore = Int(Double(score) * Double(i) / Double(steps))
            }
        }
    }
}

// MARK: - Countdown Screen

struct CountdownScreen: View {
    @Binding var isHandDetected: Bool
    let onGo: () -> Void

    @State private var count = 3
    @State private var showGo = false
    @State private var started = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if showGo {
                Text("Go!")
                    .font(.system(size: scaled(80), weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentSuccess, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Countdown number
                Text("\(count)")
                    .font(.system(size: scaled(120), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .id(count)
                    .transition(.scale.combined(with: .opacity))

                // Hand warning
                if isHandDetected {
                    Label("Move your hands away", systemImage: "hand.raised.slash.fill")
                        .font(.system(size: scaled(17), weight: .semibold, design: .rounded))
                        .foregroundColor(.accentWarning)
                        .transition(.opacity)
                } else {
                    Text("Get ready...")
                        .font(.system(size: scaled(17), weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .transition(.opacity)
                }
            }

            Spacer()
        }
        .animation(DesignTokens.springBouncy, value: count)
        .animation(DesignTokens.springBouncy, value: showGo)
        .animation(DesignTokens.springSnappy, value: isHandDetected)
        .task { await runCountdown() }
    }

    private func runCountdown() async {
        guard !started else { return }
        started = true

        // Wait for hands to be clear before starting
        while isHandDetected {
            try? await Task.sleep(for: .milliseconds(100))
        }

        // Tick down: 3 → 2 → 1
        for nextCount in stride(from: 2, through: 0, by: -1) {
            try? await Task.sleep(for: .seconds(1))

            // Pause while hand is detected
            while isHandDetected {
                try? await Task.sleep(for: .milliseconds(100))
            }

            if nextCount > 0 {
                count = nextCount
            } else {
                showGo = true
                try? await Task.sleep(for: .seconds(0.6))
                onGo()
            }
        }
    }
}

// MARK: - Loading Screen
struct LoadingScreen: View {
    @State private var waveRotation: Double = 0
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    @State private var mathSymbolOffsets: [CGFloat] = Array(repeating: 0, count: 6)

    private let mathSymbols = ["+", "−", "×", "÷", "=", "?"]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // Subtle radial gradient
            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Floating math symbols in background
            ForEach(0..<6, id: \.self) { i in
                Text(mathSymbols[i])
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundColor(.textSecondary.opacity(0.15))
                    .offset(
                        x: CGFloat([-120, 100, -80, 130, -60, 90][i]),
                        y: mathSymbolOffsets[i] + CGFloat([-200, -140, -60, 30, 100, 170][i])
                    )
            }

            VStack(spacing: 24) {
                // Waving hand icon
                Image(systemName: "hand.raised.fingers.spread")
                    .font(.system(size: scaled(56), weight: .light))
                    .foregroundColor(.accentPrimary)
                    .rotationEffect(.degrees(waveRotation))

                Text("Get Ready!")
                    .font(.system(size: scaled(28), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                // Bouncing dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 10, height: 10)
                            .offset(y: dotOffsets[i])
                    }
                }
            }
        }
        .onAppear {
            // Hand wave animation
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                waveRotation = 20
            }
            // Bouncing dots with stagger
            for i in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
                ) {
                    dotOffsets[i] = -12
                }
            }
            // Floating math symbols
            for i in 0..<6 {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2.5...4.0))
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.3)
                ) {
                    mathSymbolOffsets[i] = CGFloat.random(in: -15...15)
                }
            }
        }
    }
}

// MARK: - Camera Warmup Screen

struct CameraWarmupScreen: View {
    @ObservedObject var cameraManager: CameraManager
    let onReady: () -> Void

    @State private var advanced = false
    @State private var pulse = false
    @State private var showContent = false
    @State private var messageIndex = 0
    @State private var dotCount = 1

    private let messages = [
        "Getting camera ready",
        "Looking for your hands",
        "Almost there",
        "Warming up"
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.07), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Pulsing camera icon
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(Color.accentPrimary.opacity(0.25), lineWidth: 1)
                            .frame(width: 84 + CGFloat(i) * 32, height: 84 + CGFloat(i) * 32)
                            .scaleEffect(pulse ? 1.5 : 1.0)
                            .opacity(pulse ? 0 : 0.7)
                            .animation(
                                Animation.easeOut(duration: 1.4)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.45),
                                value: pulse
                            )
                    }

                    Circle()
                        .fill(Color.accentPrimary.opacity(0.12))
                        .frame(width: 84, height: 84)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.accentPrimary)
                }
                .frame(width: 150, height: 150)

                VStack(spacing: 8) {
                    // Cycling message + animated dots
                    Text(messages[messageIndex] + String(repeating: ".", count: dotCount))
                        .font(.system(size: scaled(18), weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                        .animation(DesignTokens.springGentle, value: messageIndex)

                    Text("Just a moment")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                .frame(width: 260)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
        }
        .onAppear {
            withAnimation(DesignTokens.springGentle.delay(0.1)) {
                showContent = true
            }
            pulse = true
            if cameraManager.isRunning {
                advance()
            }
        }
        .onReceive(cameraManager.$isRunning) { running in
            guard running else { return }
            advance()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            dotCount = (dotCount % 3) + 1
        }
        .onReceive(Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(DesignTokens.springGentle) {
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            onReady()
        }
    }
}

// MARK: - Error Overlay View
struct ErrorOverlayView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentWarning)

            Text("Camera Error")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge)
                .stroke(Color.accentWarning.opacity(0.3), lineWidth: 1)
        )
        .padding(40)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
