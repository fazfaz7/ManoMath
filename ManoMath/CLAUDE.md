# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Handy is a Swift Playgrounds app (.swiftpm) for the Apple Swift Student Challenge. Users answer mental math problems by holding up fingers in front of the device camera. Hand poses are detected via the Vision framework and finger counts are used as numeric input.

## Build & Run

This is a Swift Playgrounds app package. There is no traditional Xcode project file.

- **Open in Swift Playgrounds** on iPad, or open `Package.swift` in Xcode on Mac
- **Build**: `swift build` from the repo root (limited — camera/Vision require a real device)
- **Run**: Must run on a physical iOS/iPadOS device (camera required); iOS 18.0+ target
- **No test suite** exists currently

## Architecture

The app follows an MVVM pattern with an onboarding tutorial flow leading into the main game:

```
Camera frames (CameraManager)
    → FrameDelegateBridge
    → Hand pose detection (HandPoseDetector)
    → Combine publishers
    → Game logic (GameViewModel)
    → SwiftUI views (ContentView)
```

### Data Flow

1. **CameraManager** captures front-camera frames on a background `sessionQueue` and forwards each `CMSampleBuffer` to its `frameDelegate`
2. **FrameDelegateBridge** (in GameViewModel.swift) adapts the `CameraFrameDelegate` protocol to a closure, connecting camera output to the detector
3. **HandPoseDetector** runs `VNDetectHumanHandPoseRequest` on each frame (throttled to 10fps), counts raised fingers across up to 2 hands, and publishes results via `@Published` properties
4. **GameViewModel** subscribes to detector updates via Combine, manages the hold-to-confirm timer (1.5 seconds with visual progress ring), two-digit input state machine, scoring, countdown timer, and challenge progression
5. **ContentView** manages app phase (`onboarding` → `loading` → `settings` → `playing`) and layers: camera preview → gradient → timer bar + question bar + hand status + answer section

### App Phase Flow

ContentView uses an `AppPhase` enum to manage transitions:
- `.onboarding` → shows `OnboardingView` (6-screen tutorial)
- `.loading` → shows `LoadingScreen`, starts the game camera in the background, waits for `cameraManager.$isRunning` + 1.5s stabilization buffer before transitioning
- `.settings` → shows `SettingsScreen` (hands, difficulty, operations), user taps Start to begin
- `.playing` → shows the game UI with 30-second countdown

This loading phase prevents the camera lag that occurs when initializing a new AVCaptureSession after the onboarding practice sessions stop. After game over, "Play Again" returns to `.settings` (camera stays running).

### Onboarding Flow (OnboardingView.swift)

A `@State currentPage` index drives a 6-screen tutorial with button/camera-driven navigation (not TabView):

| Page | Screen | Type |
|------|--------|------|
| 0 | Welcome | Static — "Handy Math" title, Start button, debug skip |
| 1 | Nostalgia Hook | Static — "How did you first learn to count?" |
| 2 | Practice: Show 4 | Camera — hold 4 fingers, number fills bottom-to-top over 2s |
| 3 | Practice: Show 8 | Camera — "Use both hands!", hold 8 fingers |
| 4 | Exercise: 3+4 | Camera — "Show the answer!", hold 7 fingers |
| 5 | Two-Digit: 2×7=14 | Camera — guided two-phase input (tens then ones) |

**Key components:**
- **PracticeScreen** — Reusable camera screen with configurable `headline`, `subtitle`, `targetNumber`. Uses bottom-to-top fill animation (dim background number + colored number masked with a growing rectangle). 2-second hold to confirm. Resets progress if finger count changes.
- **TwoDigitPracticeScreen** — Two-phase guided input with `FillingDigitBox` pair. Tens digit confirmed first, then ones digit. Each box has its own fill animation.
- **PracticeViewModel** — Lightweight `@MainActor ObservableObject` that owns its own `CameraManager` + `HandPoseDetector` + `FrameDelegateBridge`. Each practice screen gets an independent camera session.
- **FillingDigitBox** — Compact digit box with the same bottom-to-top mask fill technique, active/confirmed border states.

The view takes an `onFinish: () -> Void` closure; adding new pages means adding a `case` to the switch and chaining the previous page's completion.

### Two-Digit Input State Machine

For answers > 10, the game uses sequential digit entry:
- `InputPhase.tensDigit` → user holds fingers for tens place → confirmed → transitions to `.onesDigit`
- `InputPhase.onesDigit` → user holds fingers for ones place → confirmed → answer checked
- Showing 10 fingers during `.onesDigit` phase and holding resets back to `.tensDigit`
- For answers 0-10, uses `.singleDigit` phase (direct input)

### Timed Game Mechanic

- **30-second countdown** with `TimerBar` at top of game view (progress bar + time text)
- Timer uses absolute `gameEndDate` (avoids floating-point drift), ticks every 50ms
- **+5 seconds** added per correct answer, **+10 seconds** streak bonus every 5 correct in a row
- Timer bar color: blue (>10s) → orange (5–10s) → red (<5s) with pulsing animation when urgent
- `isPreGame` state: camera runs but timer doesn't start until user taps Start on settings screen
- `isGameOver`: when timer hits 0, game freezes, `GameOverView` overlay shows score/high score
- High score persisted via `@AppStorage("highScore")`

### Settings Screen

Full-page `SettingsScreen` shown before each game round (`.settings` app phase):
- **Hands**: Left / Right / Both — single-hand mode caps answers at 0–5
- **Difficulty**: Easy (0–10) / Medium (0–30) / Hard (0–99) — disabled when single-hand
- **Operations**: Toggle any combination of +, −, ×, ÷ (at least one must stay selected)
- Settings are passed to `GameViewModel.beginCountdown(with:)` which applies them to the `MathChallengeGenerator`
- `GameSettings` struct and `HandMode` enum live in `MathChallengeGenerator.swift`
- Settings persist across rounds via `@State` in ContentView (not persisted to disk)

### Hold-to-Confirm & Progress Ring

- Player holds a finger count for 1.5 seconds to confirm input
- `holdProgress` (0.0–1.0) drives a visual progress ring (`.trim()` on `RoundedRectangle`) around digit boxes
- 30ms timer (`startHoldProgressTimer`) updates progress continuously
- Progress resets if finger count changes
- When no hand detected: digit boxes show "–" instead of "0" (avoids ghost input from Combine publisher race condition)

### Scoring

- Single-digit correct: +10 points
- Two-digit correct: +20 points
- Streak tracking: resets on wrong answer
- Streak bonus animation ("+10s STREAK!") every 5 correct in a row

## Key Conventions

- **Swift 6 strict concurrency**: `CameraManager` is `@unchecked Sendable` (thread safety via `sessionQueue`). `HandPoseDetector` is `@MainActor` but detection methods are `nonisolated` with `nonisolated(unsafe)` storage for Vision objects.
- **Front camera mirroring**: Both the preview layer and video output connection are manually mirrored.
- **Color theme**: Defined as `Color` extensions in ContentView.swift (`.appBackground`, `.cardBackground`, `.accentPrimary`, `.accentSuccess`, `.accentWarning`, `.textPrimary`, `.textSecondary`). Used across both onboarding and game screens.
- **All source files are in the root directory** — flat structure required by Swift Playgrounds .swiftpm format.
- **Package.swift is auto-generated** by Swift Playgrounds — do not manually restructure targets.

## Key Files

| File | Purpose |
|------|---------|
| `ContentView.swift` | App phase management, game UI, color theme, settings screen, game-over screen, timer bar, all game sub-views (QuestionBar, AnswerSection, DigitBox, SingleDigitBox, SettingsScreen, GameOverView, TimerBar, etc.) |
| `OnboardingView.swift` | 6-screen onboarding tutorial (WelcomeScreen, NostalgiaScreen, PracticeScreen, TwoDigitPracticeScreen, PracticeViewModel, FillingDigitBox) |
| `GameViewModel.swift` | Game state, Combine subscriptions, hold-to-confirm logic with progress timer, two-digit state machine, scoring, countdown timer, streak tracking. Also contains `FrameDelegateBridge`. |
| `HandPoseDetector.swift` | Vision hand pose detection, finger counting, thumb extension logic, palm position tracking |
| `CameraManager.swift` | AVCaptureSession setup, front camera, frame delegate delivery |
| `CameraPreviewView.swift` | UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer |
| `MathChallengeGenerator.swift` | Math problem generation (4 operations, 3 difficulty levels), `GameSettings` struct, `HandMode` enum, single-hand capped generation |
