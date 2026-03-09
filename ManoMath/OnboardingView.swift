import SwiftUI
import Combine
import CoreMedia

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0
    @State private var navigatingForward = true
    @StateObject private var practiceVM = PracticeViewModel()

    private var showCamera: Bool { currentPage >= 6 }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // Persistent camera layer for all practice screens
            if showCamera {
                CameraPreviewView(session: practiceVM.cameraManager.captureSession)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            switch currentPage {
            case 0:
                StoryScreen1(onContinue: { goToPage(1) }, onSkip: onFinish)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 1:
                StoryScreen2(onContinue: { goToPage(2) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 2:
                StoryScreen3(onContinue: { goToPage(3) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 3:
                StoryScreen4(onContinue: { goToPage(4) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 4:
                SetupScreen(onContinue: { goToPage(5) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 5:
                CameraWarmupScreen(cameraManager: practiceVM.cameraManager, onReady: { goToPage(6) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 6:
                PracticeScreen(practiceVM: practiceVM, targetNumber: 4, headline: "Show 4 fingers", onComplete: { goToPage(7) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 7:
                PracticeScreen(practiceVM: practiceVM, targetNumber: 8, headline: "What about an 8?", subtitle: "Use both hands!", onComplete: { goToPage(8) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 8:
                PracticeScreen(practiceVM: practiceVM, targetNumber: 7, headline: "3 + 4 = ?", subtitle: "Show the answer!", onComplete: { goToPage(9) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 9:
                PracticeScreen(practiceVM: practiceVM, targetNumber: 0, headline: "Now show a 0", subtitle: "Close your fist!", icon: "✊", onComplete: { goToPage(10) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 10:
                TwoDigitPracticeScreen(practiceVM: practiceVM, onComplete: { goToPage(11) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 11:
                UndoPracticeScreen(practiceVM: practiceVM, onComplete: onFinish)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            default:
                EmptyView()
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage == 5 {
                practiceVM.start()
            }
        }

        .onDisappear {
            practiceVM.stop()
        }
    }

    private func goToPage(_ page: Int) {
        navigatingForward = page > currentPage
        withAnimation(DesignTokens.springGentle) {
            currentPage = page
        }
    }
}

// MARK: - Story Screen 1: The Question

private struct StoryScreen1: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showPart1 = false
    @State private var showPart2 = false
    @State private var showButton = false

    // (digit, xFraction, size, duration, startPhase, opacity) — ascend upward slowly
    private static let bgDigits: [(String, CGFloat, CGFloat, Double, Double, Double)] = [
        ("7", 0.08, 72, 14.0, 0.15, 0.055),
        ("3", 0.90, 52, 11.0, 0.60, 0.045),
        ("9", 0.22, 86, 16.0, 0.38, 0.065),
        ("1", 0.73, 60, 12.0, 0.80, 0.050),
        ("4", 0.42, 78, 15.0, 0.22, 0.060),
        ("8", 0.58, 48, 10.0, 0.55, 0.040),
        ("6", 0.15, 66, 13.0, 0.90, 0.050),
        ("2", 0.84, 80, 14.5, 0.35, 0.055),
        ("5", 0.35, 56, 11.5, 0.70, 0.045),
        ("0", 0.62, 70, 13.5, 0.10, 0.040),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ForEach(Array(Self.bgDigits.enumerated()), id: \.offset) { _, d in
                        FloatingDigitView(
                            digit: d.0,
                            xPosition: geo.size.width * d.1,
                            screenHeight: geo.size.height,
                            size: d.2, duration: d.3,
                            startPhase: d.4, opacity: d.5
                        )
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Color.black.opacity(0.3)))
                    }
                }
                .padding(.horizontal, 28).padding(.top, 16)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("When was the last time")
                        .font(.system(size: scaled(26), weight: .regular, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .opacity(showPart1 ? 1 : 0)
                        .offset(y: showPart1 ? 0 : 12)

                    Text("you did math\nin your head?")
                        .font(.system(size: scaled(46), weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .opacity(showPart2 ? 1 : 0)
                        .offset(y: showPart2 ? 0 : 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 36)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue").primaryButtonStyle()
                }
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(DesignTokens.springGentle.delay(0.5)) { showPart1 = true }
            withAnimation(DesignTokens.springGentle.delay(1.2)) { showPart2 = true }
            withAnimation(DesignTokens.springGentle.delay(2.5)) { showButton = true }
        }
    }
}

// MARK: - Floating Digit (slowly ascends, used by StoryScreen1)

private struct FloatingDigitView: View {
    let digit: String
    let xPosition: CGFloat
    let screenHeight: CGFloat
    let size: CGFloat
    let duration: Double
    let startPhase: Double  // 0 = starts at bottom, 1 = starts at top
    let opacity: Double

    @State private var yOffset: CGFloat = -2000

    private var topEdge: CGFloat    { -(size + 20) }
    private var bottomEdge: CGFloat { screenHeight + size + 20 }

    var body: some View {
        Text(digit)
            .font(.system(size: size, weight: .ultraLight, design: .monospaced))
            .foregroundColor(.white.opacity(opacity))
            .position(x: xPosition, y: yOffset)
            .task {
                let span = bottomEdge - topEdge
                yOffset = bottomEdge - span * startPhase   // place at phase position
                let remaining = startPhase
                if remaining > 0.02 {
                    withAnimation(.linear(duration: duration * remaining)) { yOffset = topEdge }
                    try? await Task.sleep(for: .seconds(duration * remaining))
                }
                while !Task.isCancelled {
                    yOffset = bottomEdge
                    withAnimation(.linear(duration: duration)) { yOffset = topEdge }
                    try? await Task.sleep(for: .seconds(duration + 0.05))
                }
            }
    }
}

// MARK: - Story Screen 2: The Problem

private struct StoryScreen2: View {
    let onContinue: () -> Void

    @State private var showHeadline = false
    @State private var showBadge = [false, false, false]
    @State private var showBody = false
    @State private var showButton = false
    @State private var symbolPhase = false

    private let scenarios: [(icon: String, label: String)] = [
        ("fork.knife",  "Splitting a restaurant bill"),
        ("cart",        "Calculating a discount"),
        ("clock",       "Quick estimates on the go"),
    ]
    private let opDurations: [Double] = [3.5, 4.1, 3.9, 5.0, 4.6, 3.3, 4.8, 3.7]
    private let ops: [(String, CGFloat, CGFloat)] = [
        ("+", 0.10, 0.18), ("−", 0.88, 0.12), ("×", 0.05, 0.55),
        ("÷", 0.92, 0.60), ("+", 0.50, 0.08), ("×", 0.78, 0.88),
        ("−", 0.22, 0.82), ("÷", 0.65, 0.30),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient operator symbols
            GeometryReader { geo in
                ForEach(Array(ops.enumerated()), id: \.offset) { index, op in
                    Text(op.0)
                        .font(.system(size: scaled(28), weight: .bold, design: .rounded))
                        .foregroundColor(.textSecondary.opacity(symbolPhase ? 0.09 : 0.03))
                        .position(x: geo.size.width * op.1, y: geo.size.height * op.2)
                        .animation(
                            .easeInOut(duration: opDurations[index])
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.35),
                            value: symbolPhase
                        )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Everything\nis instant.")
                    .font(.system(size: scaled(46), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .scaleEffect(showHeadline ? 1 : 0.9)

                Spacer().frame(height: 40)

                VStack(spacing: 12) {
                    ForEach(Array(scenarios.enumerated()), id: \.offset) { index, s in
                        HStack(spacing: 14) {
                            Image(systemName: s.icon)
                                .font(.system(size: scaled(18), weight: .medium))
                                .foregroundColor(.accentPrimary)
                                .frame(width: 26)
                            Text(s.label)
                                .font(.system(size: scaled(16), weight: .medium, design: .rounded))
                                .foregroundColor(.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                .fill(Color.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                    .stroke(Color.borderFaint, lineWidth: 1))
                        )
                        .scaleEffect(showBadge[index] ? 1 : 0.88)
                        .opacity(showBadge[index] ? 1 : 0)
                        .offset(x: showBadge[index] ? 0 : -24)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 32)

                Text("Your brain still handles all of this.\nBut convenience has quietly\ntrained it to forget.")
                    .font(.system(size: scaled(16), weight: .regular, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 8)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue").primaryButtonStyle()
                }
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
        }
        .onAppear {
            symbolPhase = true
            withAnimation(DesignTokens.springGentle.delay(0.3)) { showHeadline = true }
            for i in 0..<3 {
                withAnimation(DesignTokens.springBouncy.delay(1.1 + Double(i) * 0.45)) {
                    showBadge[i] = true
                }
            }
            withAnimation(DesignTokens.springGentle.delay(2.6)) { showBody = true }
            withAnimation(DesignTokens.springGentle.delay(3.1)) { showButton = true }
        }
    }
}

// MARK: - Story Screen 3: The History

private struct StoryScreen3: View {
    let onContinue: () -> Void

    @State private var showHand = [false, false, false]
    @State private var breathe = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showButton = false

    private let handIcons   = ["hand.point.up.left.fill", "hand.raised.fill", "hand.raised.fingers.spread.fill"]
    private let breatheAmt: [CGFloat] = [5, 8, 5]
    private let breatheSec: [Double]  = [2.8, 2.4, 3.1]
    private let amber = Color(red: 1.0, green: 0.72, blue: 0.28)

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.28).opacity(0.10), Color.clear],
                center: .bottom, startRadius: 0, endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 36) {
                    ForEach(Array(handIcons.enumerated()), id: \.offset) { index, icon in
                        Image(systemName: icon)
                            .font(.system(size: scaled(54), weight: .light))
                            .foregroundColor(amber)
                            .shadow(color: amber.opacity(0.45), radius: 18, y: 6)
                            .scaleEffect(showHand[index] ? 1 : 0.05)
                            .opacity(showHand[index] ? 1 : 0)
                            .offset(y: breathe ? -breatheAmt[index] : breatheAmt[index])
                            .animation(
                                .easeInOut(duration: breatheSec[index]).repeatForever(autoreverses: true),
                                value: breathe
                            )
                    }
                }
                .padding(.bottom, 44)

                Text("Before zero,\nthere were fingers.")
                    .font(.system(size: scaled(38), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 10)
                    .padding(.bottom, 16)

                Text("Long before calculators, humans counted\non their hands. The original interface\nbetween mind and number.")
                    .font(.system(size: scaled(16), weight: .regular, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 8)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue").primaryButtonStyle()
                }
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation(DesignTokens.springBouncy.delay(0.3 + Double(i) * 0.4)) {
                    showHand[i] = true
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                breathe = true
            }
            withAnimation(DesignTokens.springGentle.delay(1.8)) { showHeadline = true }
            withAnimation(DesignTokens.springGentle.delay(2.5)) { showBody = true }
            withAnimation(DesignTokens.springGentle.delay(3.2)) { showButton = true }
        }
    }
}

// MARK: - Story Screen 4: The Reveal

private struct StoryScreen4: View {
    let onContinue: () -> Void

    private let questions = ["3 + 4 = ?", "8 − 3 = ?", "2 × 4 = ?"]
    private let answers   = [7, 5, 8]

    @State private var questionIndex = 0
    @State private var holdProgress: CGFloat = 0
    @State private var confirmed = false
    @State private var showHeadline = false
    @State private var showDemo = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.07), Color.clear],
                center: .top, startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Train the\noriginal way.")
                        .font(.system(size: scaled(42), weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Answer math problems with your fingers.\nThe camera reads your hand pose.")
                        .font(.system(size: scaled(16), weight: .regular, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showHeadline ? 1 : 0)
                .scaleEffect(showHeadline ? 1 : 0.9)

                Spacer().frame(height: 40)

                // Looping demo
                VStack(spacing: 20) {
                    Text(questions[questionIndex])
                        .font(.system(size: scaled(32), weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                .fill(Color.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                    .stroke(Color.borderSubtle, lineWidth: 1))
                        )
                        .id(questionIndex)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))

                    HStack(spacing: 20) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: scaled(50)))
                            .foregroundColor(.textSecondary.opacity(0.5))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary.opacity(0.3))

                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium).fill(Color.cardBackground)
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                .stroke(confirmed ? Color.accentSuccess.opacity(0.6) : Color.accentPrimary.opacity(0.4), lineWidth: 2)
                            if holdProgress > 0 {
                                GeometryReader { geo in
                                    VStack(spacing: 0) {
                                        Color.clear.frame(height: geo.size.height * (1 - holdProgress))
                                        (confirmed ? Color.accentSuccess : Color.accentPrimary)
                                            .opacity(0.2)
                                            .frame(height: geo.size.height * holdProgress)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium))
                            }
                            if confirmed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: scaled(32), weight: .bold))
                                    .foregroundColor(.accentSuccess)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Text("\(answers[questionIndex])")
                                    .font(.system(size: scaled(42), weight: .bold, design: .rounded))
                                    .foregroundColor(holdProgress > 0.1 ? .accentPrimary : .textPrimary)
                            }
                        }
                        .frame(width: scaled(84), height: scaled(100))
                        .animation(DesignTokens.springBouncy, value: confirmed)
                    }
                }
                .opacity(showDemo ? 1 : 0)
                .scaleEffect(showDemo ? 1 : 0.92)

                Spacer()

                Button(action: onContinue) {
                    Text("Let's start").primaryButtonStyle()
                }
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
            .padding(.horizontal, 32)
        }
        .animation(DesignTokens.springGentle, value: questionIndex)
        .onAppear {
            withAnimation(DesignTokens.springGentle.delay(0.3)) { showHeadline = true }
            withAnimation(DesignTokens.springGentle.delay(0.9)) { showDemo = true }
            withAnimation(DesignTokens.springGentle.delay(1.1)) { showButton = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            while !Task.isCancelled {
                withAnimation(.linear(duration: 1.4)) { holdProgress = 1.0 }
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(DesignTokens.springBouncy) { confirmed = true }
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(DesignTokens.springSnappy) { confirmed = false; holdProgress = 0 }
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(DesignTokens.springGentle) { questionIndex = (questionIndex + 1) % questions.count }
                try? await Task.sleep(for: .seconds(0.9))
            }
        }
    }
}

// MARK: - Setup Screen: Device Positioning Instructions

private struct SetupScreen: View {
    let onContinue: () -> Void

    @State private var showEyebrow = false
    @State private var showHeadline = false
    @State private var showCards = [false, false, false]
    @State private var showButton = false

    private let tips: [(emoji: String, title: String, detail: String)] = [
        ("📱", "Prop your device",    "Set it on a surface at eye level — hands-free works best."),
        ("↔️",  "Arm's length away",   "About 40–60 cm between you and the camera is ideal."),
        ("🙌", "Both hands in frame", "For numbers above 5 you'll need both hands visible."),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.06), Color.clear],
                center: .top, startRadius: 0, endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("BEFORE WE START")
                    .font(.system(size: scaled(12), weight: .semibold, design: .rounded))
                    .tracking(2.5)
                    .foregroundColor(.accentPrimary)
                    .opacity(showEyebrow ? 1 : 0)
                    .offset(y: showEyebrow ? 0 : 8)

                Spacer().frame(height: 12)

                Text("Set yourself up\nfor success.")
                    .font(.system(size: scaled(38), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .scaleEffect(showHeadline ? 1 : 0.92)

                Spacer().frame(height: 36)

                VStack(spacing: 14) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                        HStack(spacing: 16) {
                            Text(tip.emoji)
                                .font(.system(size: scaled(30)))
                                .frame(width: scaled(44))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tip.title)
                                    .font(.system(size: scaled(16), weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Text(tip.detail)
                                    .font(.system(size: scaled(13), weight: .regular, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                .fill(Color.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                        .stroke(Color.borderSubtle, lineWidth: 1)
                                )
                        )
                        .opacity(showCards[i] ? 1 : 0)
                        .offset(y: showCards[i] ? 0 : 14)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: onContinue) {
                    Text("Got it!").primaryButtonStyle()
                }
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(DesignTokens.springGentle.delay(0.3)) { showEyebrow = true }
            withAnimation(DesignTokens.springGentle.delay(0.7)) { showHeadline = true }
            for i in 0..<3 {
                withAnimation(DesignTokens.springGentle.delay(1.1 + Double(i) * 0.2)) {
                    showCards[i] = true
                }
            }
            withAnimation(DesignTokens.springGentle.delay(1.9)) { showButton = true }
        }
    }
}

// MARK: - Practice View Model (shared across practice screens)

@MainActor
private class PracticeViewModel: ObservableObject {
    let cameraManager = CameraManager()
    let handPoseDetector = HandPoseDetector()
    private var frameBridge: FrameDelegateBridge?
    private var cancellables = Set<AnyCancellable>()

    @Published var fingerCount: Int = 0
    @Published var isHandDetected: Bool = false

    init() {
        let detector = handPoseDetector
        let bridge = FrameDelegateBridge { buffer in
            detector.processFrame(buffer)
        }
        cameraManager.frameDelegate = bridge
        self.frameBridge = bridge

        handPoseDetector.$detectedFingerCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in self?.fingerCount = count }
            .store(in: &cancellables)

        handPoseDetector.$isHandDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in self?.isHandDetected = detected }
            .store(in: &cancellables)
    }

    func start() { cameraManager.startSession() }
    func stop() { cameraManager.stopSession() }
}

// MARK: - Practice Screen (content overlay, camera is behind)

private struct PracticeScreen: View {
    @ObservedObject var practiceVM: PracticeViewModel
    let targetNumber: Int
    let headline: String
    var subtitle: String? = nil
    var icon: String? = nil
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isComplete = false

    private let holdDuration: TimeInterval = 2.0
    private let frameRate: Double = 30

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Headline + subtitle in a backdrop pill
            VStack(spacing: 8) {
                Text(headline)
                    .font(.system(size: scaled(28), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: scaled(18), weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(Color.black.opacity(0.3))
                    )
            )

            // Optional icon hint
            if let icon {
                Text(icon)
                    .font(.system(size: scaled(56)))
            }

            // The filling number
            ZStack {
                // Dim background number
                Text("\(targetNumber)")
                    .font(.system(size: scaled(200), weight: .bold, design: .rounded))
                    .foregroundColor(.dimContent)

                // Filled number (clips from bottom to top)
                Text("\(targetNumber)")
                    .font(.system(size: scaled(200), weight: .bold, design: .rounded))
                    .foregroundStyle(isComplete ? Color.accentSuccess : Color.accentPrimary)
                    .shadow(color: progress > 0.5 ? Color.accentPrimary.opacity(0.4) : .clear, radius: 12)
                    .mask(
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: geo.size.height * (1 - progress))
                                Color.white
                                    .frame(height: geo.size.height * progress)
                            }
                        }
                    )
            }
            .frame(height: scaled(240))

            // Checkmark when complete
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: scaled(48)))
                    .foregroundColor(.accentSuccess)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(practiceVM.isHandDetected ? "Hold steady..." : "Show your hand to the camera")
                    .font(.system(size: scaled(15), weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .onReceive(Timer.publish(every: 1.0 / frameRate, on: .main, in: .common).autoconnect()) { _ in
            guard !isComplete else { return }

            if practiceVM.fingerCount == targetNumber && practiceVM.isHandDetected {
                progress = min(1.0, progress + (1.0 / frameRate) / holdDuration)
                if progress >= 1.0 {
                    withAnimation(DesignTokens.springBouncy) {
                        isComplete = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        onComplete()
                    }
                }
            } else {
                progress = 0
            }
        }
    }
}

// MARK: - Two-Digit Practice Screen (content overlay)

private struct TwoDigitPracticeScreen: View {
    @ObservedObject var practiceVM: PracticeViewModel
    let onComplete: () -> Void

    private let tensDigit = 7
    private let onesDigit = 4

    private enum Phase: Equatable {
        case intro       // Big "74" displayed
        case split       // Animating split into two boxes
        case enterTens   // User enters 7
        case enterOnes   // User enters 4
    }

    @State private var phase: Phase = .intro
    @State private var hasSplit = false
    @State private var progress: CGFloat = 0
    @State private var tensConfirmed = false
    @State private var isComplete = false
    @State private var showIntroNumber = false
    @State private var showMerged = false

    private let holdDuration: TimeInterval = 2.0
    private let frameRate: Double = 30

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Headline card
            VStack(spacing: 10) {
                Text(headlineText)
                    .font(.system(size: scaled(28), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .multilineTextAlignment(.center)

                if phase == .enterTens || phase == .enterOnes || isComplete {
                    Text(instructionText)
                        .font(.system(size: scaled(17), weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(Color.black.opacity(0.3))
                    )
            )

            // Big number OR split boxes
            ZStack {
                // Big "74" — visible before split
                if !hasSplit {
                    Text("74")
                        .font(.system(size: scaled(120), weight: .bold, design: .rounded))
                        .foregroundColor(.accentPrimary)
                        .shadow(color: .accentPrimary.opacity(0.3), radius: 16)
                        .scaleEffect(showIntroNumber ? 1 : 0.5)
                        .opacity(showIntroNumber ? 1 : 0)
                        .transition(.scale.combined(with: .opacity))
                }

                // Split boxes — visible after split, before merge
                if hasSplit && !showMerged {
                    HStack(spacing: 16) {
                        FillingDigitBox(
                            digit: tensDigit,
                            progress: phase == .enterTens ? progress : (tensConfirmed ? 1.0 : 0),
                            isConfirmed: tensConfirmed,
                            isActive: phase == .enterTens && !isComplete
                        )

                        FillingDigitBox(
                            digit: onesDigit,
                            progress: phase == .enterOnes ? progress : (isComplete ? 1.0 : 0),
                            isConfirmed: isComplete,
                            isActive: phase == .enterOnes && !isComplete
                        )
                    }
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                // Merged number — boxes join into one unified number
                if showMerged {
                    Text("74")
                        .font(.system(size: scaled(120), weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.accentPrimary, Color.accentSuccess],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: Color.accentSuccess.opacity(0.5), radius: 24)
                        .shadow(color: Color.accentPrimary.opacity(0.3), radius: 12)
                        .transition(.scale(scale: 0.3, anchor: .center).combined(with: .opacity))
                }
            }
            .frame(height: scaled(140))

            // Status
            if showMerged {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: scaled(48)))
                    .foregroundColor(.accentSuccess)
                    .transition(.scale.combined(with: .opacity))
            } else if hasSplit {
                Text(practiceVM.isHandDetected ? "Hold steady..." : "Show your hand to the camera")
                    .font(.system(size: scaled(15), weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .animation(DesignTokens.springGentle, value: phase)
        .animation(DesignTokens.springBouncy, value: hasSplit)
        .animation(DesignTokens.springBouncy, value: isComplete)
        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: showMerged)
        .onAppear {
            // Animate the big number in
            withAnimation(DesignTokens.springBouncy.delay(0.3)) {
                showIntroNumber = true
            }
            // After a pause, split into two boxes
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    hasSplit = true
                    phase = .enterTens
                }
            }
        }
        .onReceive(Timer.publish(every: 1.0 / frameRate, on: .main, in: .common).autoconnect()) { _ in
            guard hasSplit, !isComplete else { return }

            let target = phase == .enterTens ? tensDigit : onesDigit

            if practiceVM.fingerCount == target && practiceVM.isHandDetected {
                progress = min(1.0, progress + (1.0 / frameRate) / holdDuration)
                if progress >= 1.0 {
                    if phase == .enterTens {
                        withAnimation(DesignTokens.springSnappy) {
                            tensConfirmed = true
                            phase = .enterOnes
                            progress = 0
                        }
                    } else {
                        withAnimation(DesignTokens.springBouncy) {
                            isComplete = true
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(0.5))
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                                showMerged = true
                            }
                            try? await Task.sleep(for: .seconds(1.8))
                            onComplete()
                        }
                    }
                }
            } else {
                progress = 0
            }
        }
    }

    private var headlineText: String {
        switch phase {
        case .intro, .split: return "What about bigger numbers?"
        case .enterTens, .enterOnes: return isComplete ? "You got it!" : "Enter it digit by digit"
        }
    }

    private var instructionText: String {
        if isComplete { return "One digit at a time!" }
        switch phase {
        case .enterTens:
            return "Show 7 fingers for the tens"
        case .enterOnes:
            return "Now show 4 fingers for the ones"
        default:
            return ""
        }
    }
}

// MARK: - Filling Digit Box

private struct FillingDigitBox: View {
    let digit: Int
    let progress: CGFloat
    let isConfirmed: Bool
    let isActive: Bool

    var body: some View {
        ZStack {
            // Box background — more opaque for legibility over camera
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(Color.cardBackground.opacity(0.95))

            // Active background tint
            if isActive && !isConfirmed {
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(Color.accentPrimary.opacity(0.12))
            }

            // Box border
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .stroke(borderColor, lineWidth: isActive ? 3 : 1)

            // Dim digit
            Text("\(digit)")
                .font(.system(size: scaled(72), weight: .bold, design: .rounded))
                .foregroundColor(.dimContent)

            // Filling digit
            Text("\(digit)")
                .font(.system(size: scaled(72), weight: .bold, design: .rounded))
                .foregroundStyle(isConfirmed ? Color.accentSuccess : Color.accentPrimary)
                .mask(
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: geo.size.height * (1 - progress))
                            Color.white
                                .frame(height: geo.size.height * progress)
                        }
                    }
                )
        }
        .frame(width: scaled(100), height: scaled(120))
        .shadow(color: isActive ? Color.accentPrimary.opacity(0.5) : .clear, radius: isActive ? 20 : 0, y: 0)
        .animation(DesignTokens.springSnappy, value: isActive)
    }

    private var borderColor: Color {
        if isConfirmed { return Color.accentSuccess.opacity(0.7) }
        if isActive { return Color.accentPrimary }
        return .borderSubtle
    }
}

// MARK: - Undo Practice Screen

private struct UndoPracticeScreen: View {
    @ObservedObject var practiceVM: PracticeViewModel
    let onComplete: () -> Void

    private enum Phase: Equatable {
        case enterNumber     // "Show 4 fingers" — lock as tens digit
        case revealMistake   // "What if you made a mistake?" — show 10 to undo
        case undoing         // Holding 10 fingers, undo icon fills in ones box
        case solveTens       // After undo, show 6×5=? — enter 3 for tens
        case solveOnes       // Enter 0 for ones
    }

    @State private var phase: Phase = .enterNumber
    @State private var progress: CGFloat = 0
    @State private var confirmedTens: Int? = nil
    @State private var confirmedOnes: Int? = nil
    @State private var isComplete = false
    @State private var showProblem = false

    private let holdDuration: TimeInterval = 2.0
    private let undoHoldDuration: TimeInterval = 1.5
    private let frameRate: Double = 30

    private var isUndoing: Bool {
        phase == .undoing
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Headline + problem + instruction in a backdrop card
            VStack(spacing: 10) {
                Text(headlineText)
                    .font(.system(size: scaled(28), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .multilineTextAlignment(.center)

                if showProblem {
                    Text("6 × 5 = ?")
                        .font(.system(size: scaled(24), weight: .semibold, design: .rounded))
                        .foregroundColor(.accentPrimary)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .transition(.scale.combined(with: .opacity))
                }

                Text(phaseInstruction)
                    .font(.system(size: scaled(17), weight: .medium, design: .rounded))
                    .foregroundColor(instructionColor)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(Color.black.opacity(0.3))
                    )
            )

            // Digit boxes — same style as the real game
            HStack(spacing: 12) {
                // Tens box
                TutorialDigitBox(
                    confirmedDigit: confirmedTens,
                    liveCount: tensLiveCount,
                    isActive: phase == .enterNumber || phase == .solveTens,
                    holdProgress: tensHoldProgress,
                    isUndoing: false
                )

                // Ones box — shows undo icon when undoing
                TutorialDigitBox(
                    confirmedDigit: confirmedOnes,
                    liveCount: onesLiveCount,
                    isActive: phase == .revealMistake || phase == .undoing || phase == .solveOnes,
                    holdProgress: onesHoldProgress,
                    isUndoing: isUndoing
                )
            }

            // Status
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: scaled(48)))
                    .foregroundColor(.accentSuccess)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(statusText)
                    .font(.system(size: scaled(15), weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .animation(DesignTokens.springGentle, value: phase)
        .animation(DesignTokens.springBouncy, value: showProblem)
        .onReceive(Timer.publish(every: 1.0 / frameRate, on: .main, in: .common).autoconnect()) { _ in
            guard !isComplete else { return }
            guard practiceVM.isHandDetected else {
                progress = 0
                return
            }

            switch phase {
            case .enterNumber:
                // Accept 4 fingers to lock as tens
                if practiceVM.fingerCount == 4 {
                    progress = min(1.0, progress + (1.0 / frameRate) / holdDuration)
                    if progress >= 1.0 {
                        withAnimation(DesignTokens.springSnappy) {
                            confirmedTens = 4
                            progress = 0
                        }
                        // Brief pause, then reveal the mistake
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            withAnimation(DesignTokens.springBouncy) {
                                phase = .revealMistake
                            }
                        }
                    }
                } else {
                    progress = 0
                }

            case .revealMistake:
                // Wait for 10 fingers
                if practiceVM.fingerCount == 10 {
                    withAnimation(DesignTokens.springSnappy) {
                        phase = .undoing
                        progress = 0
                    }
                }

            case .undoing:
                if practiceVM.fingerCount == 10 {
                    progress = min(1.0, progress + (1.0 / frameRate) / undoHoldDuration)
                    if progress >= 1.0 {
                        withAnimation(DesignTokens.springBouncy) {
                            confirmedTens = nil
                            showProblem = true
                            phase = .solveTens
                            progress = 0
                        }
                    }
                } else {
                    progress = 0
                    withAnimation(DesignTokens.springSnappy) {
                        phase = .revealMistake
                    }
                }

            case .solveTens:
                if practiceVM.fingerCount == 3 {
                    progress = min(1.0, progress + (1.0 / frameRate) / holdDuration)
                    if progress >= 1.0 {
                        withAnimation(DesignTokens.springSnappy) {
                            confirmedTens = 3
                            phase = .solveOnes
                            progress = 0
                        }
                    }
                } else {
                    progress = 0
                }

            case .solveOnes:
                if practiceVM.fingerCount == 0 {
                    progress = min(1.0, progress + (1.0 / frameRate) / holdDuration)
                    if progress >= 1.0 {
                        withAnimation(DesignTokens.springBouncy) {
                            confirmedOnes = 0
                            isComplete = true
                            progress = 0
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            onComplete()
                        }
                    }
                } else {
                    progress = 0
                }
            }
        }
    }

    private var tensLiveCount: Int? {
        guard practiceVM.isHandDetected else { return nil }
        if phase == .enterNumber || phase == .solveTens { return practiceVM.fingerCount }
        return nil
    }

    private var onesLiveCount: Int? {
        guard practiceVM.isHandDetected else { return nil }
        if phase == .solveOnes { return practiceVM.fingerCount }
        return nil
    }

    private var tensHoldProgress: CGFloat {
        if phase == .enterNumber || phase == .solveTens { return progress }
        return 0
    }

    private var onesHoldProgress: CGFloat {
        if phase == .undoing { return progress }
        if phase == .solveOnes { return progress }
        return 0
    }

    private var headlineText: String {
        switch phase {
        case .enterNumber: return "Show 4 fingers"
        case .revealMistake, .undoing: return "What if you made a mistake?"
        case .solveTens, .solveOnes: return "Now solve it!"
        }
    }

    private var phaseInstruction: String {
        if isComplete { return "Now you know how to undo!" }
        switch phase {
        case .enterNumber:
            return "Hold to lock it as the tens digit"
        case .revealMistake:
            return "Show all 10 fingers to undo"
        case .undoing:
            return "Hold to undo..."
        case .solveTens:
            return "Show 3 fingers for the tens"
        case .solveOnes:
            return "Close your fist (0) for the ones"
        }
    }

    private var instructionColor: Color {
        switch phase {
        case .revealMistake, .undoing: return .accentWarning
        default: return .textSecondary
        }
    }

    private var statusText: String {
        if !practiceVM.isHandDetected { return "Show your hand to the camera" }
        switch phase {
        case .enterNumber, .solveTens, .solveOnes: return "Hold steady..."
        case .undoing: return "Hold steady..."
        case .revealMistake: return "Raise all 10 fingers"
        }
    }
}

// MARK: - Tutorial Digit Box (game-style box for onboarding)

private struct TutorialDigitBox: View {
    let confirmedDigit: Int?
    let liveCount: Int?
    let isActive: Bool
    var holdProgress: CGFloat = 0
    var isUndoing: Bool = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(backgroundColor)
                .frame(width: scaled(80), height: scaled(96))

            // Hold progress fill (bottom to top)
            if isActive && holdProgress > 0 && confirmedDigit == nil {
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(fillColor)
                    .frame(width: scaled(80), height: scaled(96))
                    .mask(
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: scaled(96) * (1 - holdProgress))
                            Color.white
                                .frame(height: scaled(96) * holdProgress)
                        }
                        .frame(width: scaled(80), height: scaled(96))
                    )
            }

            // Border
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .stroke(borderColor, lineWidth: isActive ? 2 : 1)
                .frame(width: scaled(80), height: scaled(96))

            // Content
            if isUndoing {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: scaled(30), weight: .bold))
                    .foregroundColor(.accentWarning)
                    .transition(.scale.combined(with: .opacity))
            } else if let confirmed = confirmedDigit {
                Text("\(confirmed)")
                    .font(.system(size: scaled(40), weight: .bold, design: .rounded))
                    .foregroundColor(.accentSuccess)
            } else if let live = liveCount, isActive {
                Text("\(live)")
                    .font(.system(size: scaled(40), weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            } else {
                Text("–")
                    .font(.system(size: scaled(36), weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary.opacity(0.4))
            }
        }
        .shadow(color: isActive ? (isUndoing ? Color.accentWarning.opacity(0.2) : Color.accentPrimary.opacity(0.15)) : .clear, radius: 8, y: 2)
        .animation(DesignTokens.springSnappy, value: isUndoing)
        .animation(DesignTokens.springSnappy, value: confirmedDigit != nil)
    }

    private var fillColor: Color {
        isUndoing ? Color.accentWarning.opacity(0.2) : Color.accentPrimary.opacity(0.2)
    }

    private var backgroundColor: Color {
        if isUndoing { return Color(red: 0.18, green: 0.14, blue: 0.08) }
        if confirmedDigit != nil { return Color(red: 0.08, green: 0.18, blue: 0.10) }
        if isActive { return Color(red: 0.10, green: 0.12, blue: 0.22) }
        return Color.cardBackground.opacity(0.95)
    }

    private var borderColor: Color {
        if isUndoing { return Color.accentWarning.opacity(0.5) }
        if confirmedDigit != nil { return Color.accentSuccess.opacity(0.5) }
        if isActive { return Color.accentPrimary.opacity(0.4) }
        return .borderSubtle
    }
}
