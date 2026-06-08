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
    /// OnboardingView, true → HomeView).
    var hasSeenOnboarding: Bool

    /// v3 mastery model — per-level-type rolling-window progress.
    /// Keyed by `LevelTypeMastery.levelTypeId` (e.g. "ch1_arc.A_FIND_THETA").
    /// Empty for legacy v4 profiles; defaults via migration.
    var levelTypeMasteries: [String: LevelTypeMastery]

    // MARK: - Daily Question

    /// Start-of-day date the player last answered the Daily Question. Drives the
    /// "already answered today → show the result, locked until tomorrow" gate.
    /// Additive optional field — old profiles decode it as nil with no migration.
    var lastDailyAnsweredDate: Date? = nil

    /// The option index the player picked on their last Daily answer, so a
    /// re-open can show the same revealed state (with their pick marked).
    var lastDailyAnsweredPick: Int? = nil

    /// The id of the question the player last answered. Lets the picker hand
    /// back the *exact* question they answered today — so a re-open (or any
    /// state refresh while the card is on screen) restores the right reveal
    /// instead of swapping in a different question. Additive optional; old
    /// profiles decode it as nil with no migration.
    var lastDailyAnsweredQuestionID: String? = nil

    /// The Sports IQ value last shown on the Profile screen, so the next visit
    /// can count up from it and surface the gain. Additive optional; old
    /// profiles decode it as nil with no migration.
    var lastSeenIQ: Int? = nil

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

    // MARK: - Sports IQ awards (XP; 10 XP = 1 IQ)

    /// Answering the Daily Question moves Sports IQ once per day — a correct
    /// read is worth more, but seeing the why (even when wrong) still counts.
    static let dailyCorrectXP = 30
    static let dailyWrongXP = 10
    /// Reading a lesson in full for the first time. Re-reads award nothing.
    static let lessonFirstReadXP = 40

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

    // MARK: - Daily Question

    /// True if the player has already answered today's Daily Question.
    func hasAnsweredDailyToday(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastDailyAnsweredDate else { return false }
        return calendar.startOfDay(for: last) == calendar.startOfDay(for: now)
    }

    /// Record today's Daily answer: remember the pick + that it was answered,
    /// and count it toward the streak (answering the daily keeps it alive, the
    /// same as playing a scenario). Idempotent within a day via `recordPlayToday`.
    mutating func recordDailyAnswer(pick: Int, questionID: String? = nil, correct: Bool = false, now: Date = Date(), calendar: Calendar = .current) {
        let alreadyAnsweredToday = hasAnsweredDailyToday(now: now, calendar: calendar)
        lastDailyAnsweredDate = calendar.startOfDay(for: now)
        lastDailyAnsweredPick = pick
        lastDailyAnsweredQuestionID = questionID
        recordPlayToday(now: now, calendar: calendar)
        // Sports IQ moves once per day; guarding on the pre-write state keeps it
        // idempotent if the daily is ever recorded twice in the same day.
        if !alreadyAnsweredToday {
            totalXP += correct ? Self.dailyCorrectXP : Self.dailyWrongXP
            recomputeRank()
        }
    }

    /// Mark a lesson read in full. The first read moves Sports IQ; re-reads
    /// don't. Returns whether this was the first read.
    @discardableResult
    mutating func recordLessonRead(_ lessonId: String) -> Bool {
        let isFirstRead = completedLessons.insert(lessonId).inserted
        if isFirstRead {
            totalXP += Self.lessonFirstReadXP
            recomputeRank()
        }
        return isFirstRead
    }
}
