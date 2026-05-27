import Foundation

struct MetaDefinition: Codable, Sendable, Equatable {
    let title: String
    let subtitle: String
    let topic: String
    let type: ScenarioType
    let difficulty: Int        // 1–10 within tier
    let rankTier: String
    let season: String?
    let tags: [String]
    let authorIntent: String   // dev-only

    /// v3: which level type within a chapter this scenario belongs to.
    /// Optional for v2 legacy scenarios (they default to Ch 1 Level Type D
    /// at curriculum-build time, per GAME_v3_LOCKED.md §3.7).
    let levelType: LevelTypeID?

    /// v3: chapter assignment. Optional for v2 legacy scenarios.
    let chapterId: String?

    /// v3: difficulty bucket for the variation/mastery system. Drives the
    /// "hard variant present" mastery gate from GAME_v3_LOCKED.md §2.3.
    let difficultyBucket: DifficultyBucket?

    enum ScenarioType: String, Codable, Sendable {
        case scenario  = "SCENARIO"
        case scene     = "SCENE"
        case challenge = "CHALLENGE"
    }
}

/// v3: identifies which level type within a chapter a scenario serves.
/// Per GAME_v3_LOCKED.md §2.2 the four Earth-chapter types are find-θ,
/// find-v, find-d, find-both. Off-Earth chapters add find-g (L6) etc.
enum LevelTypeID: String, Codable, Sendable, Identifiable {
    case findTheta = "A_FIND_THETA"
    case findV     = "B_FIND_V"
    case findD     = "C_FIND_D"
    case findBoth  = "D_FIND_BOTH"
    case findG     = "E_FIND_G"   // off-Earth (Ch 8+)

    var id: String { rawValue }
}

/// v3: difficulty buckets per GAME_v3_LOCKED.md §2.5. The 50/35/15 mix
/// rule lives in the situation feeder, not here — this is just the label.
enum DifficultyBucket: String, Codable, Sendable {
    case easy   = "EASY"     // clean numbers, doable mentally
    case medium = "MEDIUM"   // one decimal, calculator helpful
    case hard   = "HARD"     // ugly numbers, calculator mandatory
}
