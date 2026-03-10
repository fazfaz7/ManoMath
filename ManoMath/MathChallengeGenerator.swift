import Foundation

// MARK: - Seeded RNG (xorshift64)

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Seed derived from today's date at UTC midnight — same value globally on the same calendar day.
    static func dailySeed() -> UInt64 {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let startOfDay = cal.date(from: comps) ?? Date()
        return UInt64(startOfDay.timeIntervalSince1970)
    }
}

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

    static let daily = GameSettings(
        difficulty: .medium,
        operations: Set(MathChallengeGenerator.OperationType.allCases),
        handMode: .both
    )
}

// MARK: - MathChallenge

struct MathChallenge: Equatable {
    let id = UUID()
    let questionText: String
    let answer: Int

    var requiresTwoDigits: Bool { answer > 10 }
    var tensDigit: Int { (answer / 10) % 10 }
    var onesDigit: Int { answer % 10 }
}

// MARK: - MathChallengeGenerator

class MathChallengeGenerator {

    enum OperationType: CaseIterable {
        case addition
        case subtraction
        case multiplication
        case division
    }

    enum Difficulty {
        case easy
        case medium
        case hard
    }

    var difficulty: Difficulty = .medium
    var allowedOperations: [OperationType] = [.addition, .subtraction, .multiplication, .division]
    var maxAnswer: Int? = nil

    func apply(_ settings: GameSettings) {
        difficulty = settings.difficulty
        // Filter from a fixed order so the array is always deterministic —
        // Set iteration order is random, which would break seeded RNG reproducibility.
        let fixed: [OperationType] = [.addition, .subtraction, .multiplication, .division]
        allowedOperations = fixed.filter { settings.operations.contains($0) }
        if allowedOperations.isEmpty { allowedOperations = [.addition] }
        maxAnswer = settings.handMode.isSingleHand ? 5 : nil
    }

    // MARK: - Generation

    func generateChallenge(using rng: inout (any RandomNumberGenerator)?) -> MathChallenge {
        if let cap = maxAnswer {
            return generateCappedChallenge(maxAnswer: cap, rng: &rng)
        }
        let operation = randomElement(allowedOperations, rng: &rng) ?? .addition
        switch difficulty {
        case .easy:   return generateEasyChallenge(operation: operation, rng: &rng)
        case .medium: return generateMediumChallenge(operation: operation, rng: &rng)
        case .hard:   return generateHardChallenge(operation: operation, rng: &rng)
        }
    }

    // MARK: - RNG Helpers

    private func randomInt(in range: ClosedRange<Int>, rng: inout (any RandomNumberGenerator)?) -> Int {
        if var r = rng {
            let value = Int.random(in: range, using: &r)
            rng = r
            return value
        }
        return Int.random(in: range)
    }

    private func randomElement<T>(_ array: [T], rng: inout (any RandomNumberGenerator)?) -> T? {
        guard !array.isEmpty else { return nil }
        if var r = rng {
            let value = array.randomElement(using: &r)
            rng = r
            return value
        }
        return array.randomElement()
    }

    // MARK: - Capped Challenges

    private func generateCappedChallenge(maxAnswer cap: Int, rng: inout (any RandomNumberGenerator)?) -> MathChallenge {
        let operation = randomElement(allowedOperations, rng: &rng) ?? .addition
        switch operation {
        case .addition:
            let answer = randomInt(in: 0...cap, rng: &rng)
            let a = randomInt(in: 0...answer, rng: &rng)
            return MathChallenge(questionText: "\(a) + \(answer - a)", answer: answer)
        case .subtraction:
            let answer = randomInt(in: 0...cap, rng: &rng)
            let b = randomInt(in: 0...cap, rng: &rng)
            return MathChallenge(questionText: "\(answer + b) − \(b)", answer: answer)
        case .multiplication:
            let answer = randomInt(in: 0...cap, rng: &rng)
            let divisors = (1...9).filter { answer == 0 || answer % $0 == 0 || $0 == 1 }
            let b = randomElement(divisors, rng: &rng) ?? 1
            let a = answer / b
            if a * b == answer && a <= 12 {
                return MathChallenge(questionText: "\(a) × \(b)", answer: answer)
            }
            return MathChallenge(questionText: "1 × \(answer)", answer: answer)
        case .division:
            let answer = randomInt(in: 1...cap, rng: &rng)
            let divisor = randomInt(in: 1...5, rng: &rng)
            return MathChallenge(questionText: "\(answer * divisor) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Easy (0–10)

    private func generateEasyChallenge(operation: OperationType, rng: inout (any RandomNumberGenerator)?) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = randomInt(in: 0...10, rng: &rng)
            let a = randomInt(in: 0...answer, rng: &rng)
            return MathChallenge(questionText: "\(a) + \(answer - a)", answer: answer)
        case .subtraction:
            let answer = randomInt(in: 0...10, rng: &rng)
            let b = randomInt(in: 0...10, rng: &rng)
            return MathChallenge(questionText: "\(answer + b) − \(b)", answer: answer)
        case .multiplication:
            let pairs: [(Int, Int)] = [
                (0,5),(1,5),(2,2),(2,3),(2,4),(2,5),(3,2),(3,3),(1,8),(1,9),(1,10),(5,2)
            ]
            let (a, b) = randomElement(pairs, rng: &rng)!
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)
        case .division:
            let answer = randomInt(in: 1...10, rng: &rng)
            let divisor = randomInt(in: 1...5, rng: &rng)
            return MathChallenge(questionText: "\(answer * divisor) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Medium (0–30)

    private func generateMediumChallenge(operation: OperationType, rng: inout (any RandomNumberGenerator)?) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = randomInt(in: 0...30, rng: &rng)
            let a = randomInt(in: 0...min(answer, 20), rng: &rng)
            return MathChallenge(questionText: "\(a) + \(answer - a)", answer: answer)
        case .subtraction:
            let answer = randomInt(in: 0...30, rng: &rng)
            let b = randomInt(in: 0...20, rng: &rng)
            return MathChallenge(questionText: "\(answer + b) − \(b)", answer: answer)
        case .multiplication:
            let a = randomInt(in: 2...6, rng: &rng)
            let b = randomInt(in: 1...min(6, 30 / a), rng: &rng)
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)
        case .division:
            let answer = randomInt(in: 1...15, rng: &rng)
            let divisor = randomInt(in: 2...6, rng: &rng)
            return MathChallenge(questionText: "\(answer * divisor) ÷ \(divisor)", answer: answer)
        }
    }

    // MARK: - Hard (0–99)

    private func generateHardChallenge(operation: OperationType, rng: inout (any RandomNumberGenerator)?) -> MathChallenge {
        switch operation {
        case .addition:
            let answer = randomInt(in: 20...99, rng: &rng)
            let a = randomInt(in: 10...min(answer, 60), rng: &rng)
            return MathChallenge(questionText: "\(a) + \(answer - a)", answer: answer)
        case .subtraction:
            let answer = randomInt(in: 10...99, rng: &rng)
            let b = randomInt(in: 10...50, rng: &rng)
            return MathChallenge(questionText: "\(answer + b) − \(b)", answer: answer)
        case .multiplication:
            let a = randomInt(in: 3...12, rng: &rng)
            let b = randomInt(in: 2...min(12, 99 / a), rng: &rng)
            return MathChallenge(questionText: "\(a) × \(b)", answer: a * b)
        case .division:
            let answer = randomInt(in: 5...30, rng: &rng)
            let divisor = randomInt(in: 2...9, rng: &rng)
            return MathChallenge(questionText: "\(answer * divisor) ÷ \(divisor)", answer: answer)
        }
    }
}
