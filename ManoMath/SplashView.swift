import SwiftUI

// MARK: - Floating Operator Symbol

private struct FloatingSymbol: View {
    let symbol: String
    let xPosition: CGFloat
    let screenHeight: CGFloat
    let size: CGFloat
    let duration: Double
    let startPhase: Double
    let opacity: Double

    @State private var yOffset: CGFloat = 0

    private var topEdge: CGFloat    { -(size + 20) }
    private var bottomEdge: CGFloat { screenHeight + size + 20 }

    var body: some View {
        Text(symbol)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(opacity))
            .position(x: xPosition, y: yOffset)
            .task {
                let span = bottomEdge - topEdge
                yOffset = bottomEdge - span * startPhase
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

// MARK: - Splash View

struct SplashView: View {
    let isFirstLaunch: Bool
    let onPlay: () -> Void
    let onLearn: () -> Void

    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showButtons = false
    @State private var breathe = false
    @State private var glowPulse = false

    // (symbol, xFraction, size, duration, startPhase, opacity)
    private static let symbols: [(String, CGFloat, CGFloat, Double, Double, Double)] = [
        ("+", 0.08, 32, 12.0, 0.15, 0.08),
        ("−", 0.90, 26, 10.0, 0.60, 0.06),
        ("×", 0.22, 38, 14.0, 0.38, 0.09),
        ("÷", 0.73, 28, 11.0, 0.80, 0.07),
        ("+", 0.42, 34, 13.0, 0.22, 0.08),
        ("×", 0.58, 24, 9.5, 0.55, 0.05),
        ("−", 0.15, 30, 12.5, 0.90, 0.07),
        ("÷", 0.84, 36, 13.5, 0.35, 0.08),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.13), Color.clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentPrimary.opacity(0.06), Color.clear],
                center: .bottom,
                startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            // Floating symbols
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(Self.symbols.enumerated()), id: \.offset) { _, s in
                        FloatingSymbol(
                            symbol: s.0,
                            xPosition: geo.size.width * s.1,
                            screenHeight: geo.size.height,
                            size: s.2,
                            duration: s.3,
                            startPhase: s.4,
                            opacity: s.5
                        )
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon with glow ring + breathing
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(glowPulse ? 0.12 : 0.04))
                        .frame(width: scaled(140), height: scaled(140))
                        .blur(radius: 20)
                        .scaleEffect(glowPulse ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)

                    Image(systemName: "hand.raised.fingers.spread")
                        .font(.system(size: scaled(72), weight: .light))
                        .foregroundColor(.accentPrimary)
                        .shadow(color: .accentPrimary.opacity(0.5), radius: 24)
                        .scaleEffect(showIcon ? (breathe ? 1.04 : 0.97) : 0.3)
                        .opacity(showIcon ? 1 : 0)
                        .animation(
                            showIcon ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                            value: breathe
                        )
                }

                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    Text("ManoMath")
                        .font(.system(size: scaled(44), weight: .heavy, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 14)

                    Text("Train the original way.")
                        .font(.system(size: scaled(16), weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 8)
                }

                Spacer()

                // Play is always the primary blue button
                VStack(spacing: 12) {
                    Button(action: onPlay) {
                        Text("Play").primaryButtonStyle()
                    }
                    Button(action: onLearn) {
                        Text("How it Works").secondaryButtonStyle()
                    }
                }
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 16)
                .padding(.bottom, 60)
            }
        }
        .task {
            withAnimation(DesignTokens.springBouncy) { showIcon = true }
            withAnimation(DesignTokens.springGentle.delay(0.3)) { showTitle = true }
            withAnimation(DesignTokens.springGentle.delay(0.55)) { showTagline = true }
            SoundManager.shared.warmUp()
            try? await Task.sleep(for: .seconds(0.2))
            glowPulse = true
            breathe = true
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(DesignTokens.springBouncy) { showButtons = true }
        }
    }
}

// MARK: - Secondary Button Style

extension View {
    func secondaryButtonStyle() -> some View {
        self.font(.system(size: scaled(20), weight: .bold, design: .rounded))
            .foregroundColor(.textSecondary)
            .frame(maxWidth: scaled(260))
            .padding(.vertical, scaled(16))
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    )
            )
    }
}
