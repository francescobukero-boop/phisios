import Foundation

/// v3 mastery model — per-level-type rolling-window progress tracking.
/// Per GAME_v3_LOCKED.md §2.3 mastery formula and §4 spaced review.
struct LevelTypeMastery: Codable, Sendable, Equatable {
    /// e.g. "ch1_arc.A_FIND_THETA"
    let levelTypeId: String

    /// Append-only attempt history. Rolling-window mastery score reads
    /// the last `masteryWindowSize` entries.
    var attemptHistory: [AttemptRecord]

    var status: MasteryStatus

    /// When mastery was first earned. Nil until threshold first cleared.
    var masteredAt: Date?

    /// Drives spaced-review surfacing per §4.
    var lastPracticedAt: Date?

    /// Next time this level type should be surfaced as a review attempt.
    /// Computed from `masteredAt` + the SM-2 interval ladder. Nil until mastered.
    var nextReviewAt: Date?

    /// SM-2 ease factor for spaced-review interval calculation. Default 2.5.
    /// Adjusted up/down by review attempt scores per §4.
    var easeFactor: Double

    static let masteryWindowSize: Int = 6
    static let masteryScoreThreshold: Double = 0.75    // sum(s_i) / window_size

    static func empty(levelTypeId: String) -> LevelTypeMastery {
        LevelTypeMastery(
            levelTypeId: levelTypeId,
            attemptHistory: [],
            status: .locked,
            masteredAt: nil,
            lastPracticedAt: nil,
            nextReviewAt: nil,
            easeFactor: 2.5
        )
    }

    /// The rolling-window mastery score in [0.0, 1.0]. Sum of per-attempt
    /// scores in the last `masteryWindowSize` attempts divided by window.
    /// Returns 0.0 if window not full.
    var masteryScore: Double {
        let window = Array(attemptHistory.suffix(Self.masteryWindowSize))
        guard window.count == Self.masteryWindowSize else { return 0.0 }
        let total = window.reduce(0.0) { $0 + $1.attemptScore }
        return total / Double(Self.masteryWindowSize)
    }

    /// True if all mastery conditions are met. Caller decides what to do
    /// with the result (typically: bump status to .mastered, schedule
    /// first review, fire celebration). See GAME_v3_LOCKED.md §2.3.
    func meetsMasteryThreshold(requiresFirstTryFlex: Bool) -> Bool {
        let window = Array(attemptHistory.suffix(Self.masteryWindowSize))
        guard window.count == Self.masteryWindowSize else { return false }
        guard masteryScore >= Self.masteryScoreThreshold else { return false }
        // At least one hard variant in window — desirable-difficulty stress test.
        guard window.contains(where: { $0.difficultyBucket == .hard }) else { return false }
        if requiresFirstTryFlex {
            // Level Type D additional gate: ≥1 first-try SWISH on a
            // never-seen-before situation.
            let seenIds = Set(attemptHistory.dropLast(Self.masteryWindowSize).map(\.situationId))
            let freshFirstTrySwish = window.contains { att in
                att.isFirstTry && att.outcome == .swish && !seenIds.contains(att.situationId)
            }
            guard freshFirstTrySwish else { return false }
        }
        return true
    }
}

/// One attempt at one situation. Append-only into LevelTypeMastery.attemptHistory.
struct AttemptRecord: Codable, Sendable, Equatable {
    let situationId: String         // ScenarioID raw value
    let levelTypeId: String
    let outcome: AttemptOutcome
    let isFirstTry: Bool
    let hintsUsed: Int              // 0, 1, 2, or 3
    let timeToAnswerMs: Int
    let difficultyBucket: DifficultyBucket
    let wasReview: Bool             // surfaced by spaced-review scheduler
    let wasInterleaved: Bool        // surfaced from a different level type than the active push
    let timestamp: Date

    /// Per-attempt mastery score per GAME_v3_LOCKED.md §2.3.
    var attemptScore: Double {
        switch outcome {
        case .swish, .glass:
            if isFirstTry && hintsUsed == 0 { return 1.0 }
            if isFirstTry && hintsUsed == 1 { return 0.6 }
            if isFirstTry && hintsUsed >= 2 { return 0.3 }
            return 0.3   // not first try
        case .rimDrop:
            // Rim drop is a make but the math wasn't clean — does NOT
            // count toward mastery per §2.3.
            return 0.0
        case .miss, .quit:
            return 0.0
        }
    }
}

enum AttemptOutcome: String, Codable, Sendable {
    case swish    = "SWISH"
    case glass    = "GLASS"
    case rimDrop  = "RIM_DROP"
    case miss     = "MISS"
    case quit     = "QUIT"
}

enum MasteryStatus: String, Codable, Sendable {
    /// Not yet unlocked (prior level type not mastered).
    case locked
    /// Available for PREVIEW attempts (curious player can scout ahead).
    /// Preview attempts don't count toward mastery. See §2.4.
    case preview
    /// Active practice — mastery push in progress.
    case active
    /// Mastery threshold cleared. In spaced-review rotation.
    case mastered
    /// A review attempt failed; demoted back to active practice.
    case inReview
}
