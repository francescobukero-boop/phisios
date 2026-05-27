import Foundation

/// File-backed, versioned player profile.
struct PlayerProfile: Codable, Sendable, Equatable {
    /// Bumped on any breaking schema change.
    var profileSchemaVersion: Int

    /// Cached rank rung; `totalXP` is authoritative. Call `recomputeRank()` after XP mutations.
    var rankRung: RankRung

    /// Monotonically grows; drives `rankRung`.
    var totalXP: Int

    var completedScenarios: [ScenarioID: ScenarioRecord]

    /// v2.1: lesson ids the player has read in full (tapped PRACTICE on
    /// LessonView). Drives first-play scenario gating per CONCEPT_v2.1 §3.
    /// Empty for legacy v1 profiles; defaults via `init(from:)` migration.
    var completedLessons: Set<String>

    /// v2.1 §8 — current consecutive-day streak. Reset to 0 if a day passes
    /// without a play; bumped by `recordPlayToday()`. Drives the home and
    /// profile streak surfaces.
    var currentStreak: Int

    /// Calendar day of the most recent play. Used to decide if today counts
    /// as a streak continuation, fresh start, or a no-op (already played).
    /// Stored as the start-of-day Date in the user's local calendar.
    var lastPlayedDate: Date?

    /// True until the first START tap on the first scenario. v1-era state
    /// for the dead IntroView's first-run choreography; persisted via the
    /// migration chain so existing player profiles keep loading. Safe to
    /// remove once a v6 migration drops it.
    var firstRun: Bool

    /// True until the first scenario is played. v1-era state for IntroView's
    /// theatrical reveal. Same persistence-only status as `firstRun`.
    var firstEverScenario: Bool

    /// Counter 0…3 from v1's INTRO briefing-hint dot. Persistence-only.
    var firstThreeScenariosBriefingHintSeen: Int

    /// Gates first-launch routing in PostSplashRouterView (false →
    /// V3OnboardingView, true → HomeView).
    var hasSeenOnboarding: Bool

    /// v3 mastery model — per-level-type rolling-window progress.
    /// Keyed by `LevelTypeMastery.levelTypeId` (e.g. "ch1_arc.A_FIND_THETA").
    /// Empty for legacy v4 profiles; defaults via migration.
    var levelTypeMasteries: [String: LevelTypeMastery]

    static func newProfile() -> PlayerProfile {
        PlayerProfile(
            profileSchemaVersion: PlayerProfile.currentSchemaVersion,
            rankRung: RankRung.from(xp: 0),
            totalXP: 0,
            completedScenarios: [:],
            completedLessons: [],
            currentStreak: 0,
            lastPlayedDate: nil,
            firstRun: true,
            firstEverScenario: true,
            firstThreeScenariosBriefingHintSeen: 0,
            hasSeenOnboarding: false,
            levelTypeMasteries: [:]
        )
    }

    static let currentSchemaVersion = 5

    /// Record a play happening today. Bumps `currentStreak` if it continues
    /// the streak (last played yesterday); resets to 1 if a day was missed;
    /// no-op if already played today.
    mutating func recordPlayToday(now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if let last = lastPlayedDate {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today { return }                             // already counted today
            let dayDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            currentStreak = (dayDiff == 1) ? currentStreak + 1 : 1
        } else {
            currentStreak = 1
        }
        lastPlayedDate = today
    }

    mutating func recomputeRank() {
        self.rankRung = RankRung.from(xp: totalXP)
    }
}
