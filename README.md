# ManoMath

**ManoMath** is an iOS mental math game where you answer problems with your hands — no tapping, just fingers in front of the camera.

> Built with SwiftUI, Apple Vision, and Game Center. Requires iOS 18+ and a real device.

---

## How It Works

A math problem appears on screen. You hold up the answer using your fingers. The app detects your hand pose via the camera and confirms your answer after a short hold. Fast, physical, and surprisingly fun.

- **Single-digit answers (0–10):** Hold up fingers, keep steady for 1.5 seconds
- **Two-digit answers (11–99):** Input tens digit first, then ones digit sequentially
- **Undo:** Show all 10 fingers while entering the ones digit to reset to tens

---

## Features

### Core Gameplay
- 30-second timed rounds with +3s per correct answer
- Streak bonus: +5s every 5 correct in a row
- Scoring: +10 pts for single-digit, +20 pts for two-digit answers
- Visual hold-to-confirm progress ring — no accidental inputs

### Hand Detection
- Detects up to 2 hands simultaneously using Apple's Vision framework
- Counts raised fingers (0–10) at 10fps with confidence filtering
- Smart thumb detection: only counts when fully extended, not folded
- Mirrored camera preview so your hands feel natural

### Difficulty & Customization
| Setting | Options |
|---|---|
| Difficulty | Easy (0–10), Medium (0–30), Hard (0–99) |
| Hand Mode | Left, Right, or Both |
| Operations | Addition, Subtraction, Multiplication, Division (mix and match) |

### Daily Challenge
- Same math problems globally each day (seeded RNG by UTC date)
- Game Center leaderboard — compete with anyone worldwide
- One attempt per day

### Onboarding
- 4-screen interactive tutorial with live camera practice
- Teaches single-digit input, two-digit input, and the hold mechanic
- Skippable after the first time

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI (iOS 18+) |
| Hand Detection | Vision — `VNDetectHumanHandPoseRequest` |
| Camera | AVFoundation |
| State Management | Combine + `@Published` |
| Social / Leaderboards | GameKit (Game Center) |
| Audio | AVAudioPlayer |
| Architecture | MVVM |

No external dependencies — pure Apple frameworks.

---

## Architecture

```
Camera frames (AVFoundation, background queue)
        ↓
HandPoseDetector (Vision, 10fps, @MainActor)
        ↓ @Published: fingerCount, isHandDetected
GameViewModel (state machine, timers, scoring)
        ↓ AppPhase enum
ContentView (SwiftUI, reactive rendering)
```

### AppPhase flow
```
splash → onboarding → loading → settings → warmup → countdown → playing → game over
```

### Key files

| File | Responsibility |
|---|---|
| `ContentView.swift` | All game UI and phase routing |
| `GameViewModel.swift` | Game logic, timers, scoring, input state machine |
| `HandPoseDetector.swift` | Vision hand detection, finger counting |
| `CameraManager.swift` | AVCaptureSession management |
| `MathChallengeGenerator.swift` | Problem generation with seeded RNG support |
| `OnboardingView.swift` | 4-screen interactive tutorial |
| `SplashView.swift` | Landing screen and daily challenge card |
| `GameCenterManager.swift` | Game Center auth and leaderboard submission |

---

## Requirements

- iOS 18.0+
- Real device (Vision hand detection doesn't work in Simulator)
- Camera permission

---

## Running the Project

1. Open `ManoMath.xcodeproj` in Xcode
2. Select a real iOS device as the build target
3. Build and run (`⌘R`)

No package dependencies to resolve — everything is built on system frameworks.

---

## Game Center

Leaderboard ID: `com.manomath.daily`

Players are authenticated automatically on launch. Daily challenge scores are submitted after each completed daily session.
