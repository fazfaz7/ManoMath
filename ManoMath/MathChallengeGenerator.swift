import Foundation

// MARK: - Game Settings

enum HandMode: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case both = "Both"

    var isSingleHand: Bool { self != .both }
}

struct GameSettings {
    var difficulty: MathChallengeGenerator.Difficulty = .medium
    var operations: Set<MathChallengeGenerator.OperationType> = Set(MathChallengeGenerator.OperationType.allCases)
    var handMode: HandMode = .both

    var maxAnswer: Int {
        if handMode.isSingleHand { return 5 }
        switch difficulty {
        case .easy: return 10
        case .medium: return 30
        case .hard: return 99
        }
    }
}

// MARK: - MathChallenge
/// Represents a single math challenge with its question and answer
struct MathChallenge: Equatable {
    let id = UUID()

    /// The text to display (e.g., "15 + 18")
    let questionText: String

    /// The correct answer to the problem
    let answer: Int

    /// Whether this answer requires two-digit input (11-99)
    var requiresTwoDigits: Bool {
        return answer > 10
    }

    /// The tens digit of the answer (0-9)
    var tensDigit: Int {
        return (answer / 10) % 10
    }

    /// The ones digit of the answer (0-9)
    var onesDigit: Int {
        return answer % 10
    }
}

// MARK: - MathChallengeGenerator
/// Generates random math challenges for the game.
/// Supports addition, subtraction, multiplication, and division.
class MathChallengeGenerator {

    // MARK: - Operation Types

    /// The type of math operations available
    enum OperationType: CaseIterable {
        case addition
        case subtraction
        case multiplication
        case division
    }

    /// Current difficulty level affects number ranges
    enum Difficulty {
        case easy       // Answers 0-10, simple operations
        case medium     // Answers 0-30, all operations
        case hard       // Answers 0-99, larger numbers
    }

    /// Current difficulty setting
    var difficulty: Difficulty = .medium

    /// Which operations to include (default: all four)
    var allowedOperations: [OperationType] = [.addition, .subtraction, .multiplication, .division]

    /// Optional max answer cap (e.g. 5 for single-hand mode)
    var maxAnswer: Int? = nil

    // MARK: - Configuration

    /// Apply a GameSettings struct to this generator
    func apply(_ settings: GameSettings) {
        difficulty = settings.difficulty
        allowedOperations = Array(settings.operations)
        if allowedOperations.isEmpty { allowedOperations = [.addition] }
        maxAnswer = settings.handMode.isSingleHand ? 5 : nil
    }

    // MARK: - Generation

    /// Generates a new random math challenge based on current settings
    /// - Returns: A new MathChallenge
    func generateChallenge() -> MathChallenge {
        // If max answer is capped (single-hand), use dedicated generator
        if let cap = maxAnswer {
            return generateCappedChallenge(maxAnswer: cap)
        }

        let operation = allowedOperations.randomElement() ?? .addition

        switch difficulty {
        case .easy:
            return generateEasyChallenge(operation: operation)
        case .medium:
            return generateMediumChallenge(operation: operation)
        case .hard:
            return generateHardChallenge(operation: operation)
        }
    }

    // MARK: - Capped Challenges (single-hand, answers 0-maxAnswer)

    private func generateCappedChallenge(maxAnswer cap: Int) -> MathChallenge {
        let operation = allowedOperations.randomElement() ?? .addition
        switch operation {
        case .addition:
            let answer = Int.random(in: 0...cap)
            let a = Int.random(in: 0...answer)
            return MathChallenge(questionText: "\(a) + \(answer - a)", answer: answer)
        case .subtraction:
            let answer = Int.random(in: 0...cap)
            let b = Int.random(in: 0...cap)
            return MathChallenge(questionText: "\(answer + b) − \(b)", answer: answer)
        case .multiplication:
            let answer = Int.random(in: 0...cap)
            let divisors = (1...9).filter { answer == 0 || answer % $0 == 0 || $0 == 1 }
            let b = divisors.randomElement() ?? 1
            let a = answer / b
            if a * b == answer && a <= 12 {
                return MathChallenge(questionText: "\(a) × \(b)", answer: answer)
            }
            return MathChallenge(questionText: "1 × \(answer)", answer: answer)
        case .division:
            let answer = Int.random(in: 1...cap)
            let divisor = Int.random(in: 1...5)
            return MathChallenge(questionText: "\(answer * divisor) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Easy Challenges (Answers 0-10)

    private func generateEasyChallenge(operation: OperationType) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = Int.random(in: 0...10)
            let firstNumber = Int.random(in: 0...answer)
            let secondNumber = answer - firstNumber
            return MathChallenge(questionText: "\(firstNumber) + \(secondNumber)", answer: answer)

        case .subtraction:
            let answer = Int.random(in: 0...10)
            let secondNumber = Int.random(in: 0...10)
            let firstNumber = answer + secondNumber
            return MathChallenge(questionText: "\(firstNumber) − \(secondNumber)", answer: answer)

        case .multiplication:
            // Easy: small multiplications (0-10 answers)
            let pairs: [(Int, Int)] = [
                (0, 5), (1, 5), (2, 2), (2, 3), (2, 4), (2, 5),
                (3, 2), (3, 3), (1, 8), (1, 9), (1, 10), (5, 2)
            ]
            let (a, b) = pairs.randomElement()!
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)

        case .division:
            // Easy: simple divisions with answers 0-10
            let answer = Int.random(in: 1...10)
            let divisor = Int.random(in: 1...5)
            let dividend = answer * divisor
            return MathChallenge(questionText: "\(dividend) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Medium Challenges (Answers 0-30)

    private func generateMediumChallenge(operation: OperationType) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = Int.random(in: 0...30)
            let maxFirst = min(answer, 20)
            let firstNumber = Int.random(in: 0...maxFirst)
            let secondNumber = answer - firstNumber
            return MathChallenge(questionText: "\(firstNumber) + \(secondNumber)", answer: answer)

        case .subtraction:
            let answer = Int.random(in: 0...30)
            let secondNumber = Int.random(in: 0...20)
            let firstNumber = answer + secondNumber
            return MathChallenge(questionText: "\(firstNumber) − \(secondNumber)", answer: answer)

        case .multiplication:
            // Medium: times tables up to 6×6 (max answer 36, but we cap at 30)
            let a = Int.random(in: 2...6)
            let maxB = min(6, 30 / a)
            let b = Int.random(in: 1...maxB)
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)

        case .division:
            // Medium: divisions with answers up to 15
            let answer = Int.random(in: 1...15)
            let divisor = Int.random(in: 2...6)
            let dividend = answer * divisor
            return MathChallenge(questionText: "\(dividend) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Hard Challenges (Answers 0-99)

    private func generateHardChallenge(operation: OperationType) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = Int.random(in: 20...99)
            let maxFirst = min(answer, 60)
            let firstNumber = Int.random(in: 10...maxFirst)
            let secondNumber = answer - firstNumber
            return MathChallenge(questionText: "\(firstNumber) + \(secondNumber)", answer: answer)

        case .subtraction:
            let answer = Int.random(in: 10...99)
            let secondNumber = Int.random(in: 10...50)
            let firstNumber = answer + secondNumber
            return MathChallenge(questionText: "\(firstNumber) − \(secondNumber)", answer: answer)

        case .multiplication:
            // Hard: larger times tables (answers up to 99)
            let a = Int.random(in: 3...12)
            let maxB = min(12, 99 / a)
            let b = Int.random(in: 2...maxB)
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)

        case .division:
            // Hard: divisions with answers up to 30
            let answer = Int.random(in: 5...30)
            let divisor = Int.random(in: 2...9)
            let dividend = answer * divisor
            return MathChallenge(questionText: "\(dividend) ÷ \(divisor)", answer: answer)
        }
    }
}
