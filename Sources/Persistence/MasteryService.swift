import Foundation

/// v3 §3.2 mastery runtime. Pure functions over PlayerProfile state.
/// Callers: PlayView after every outcome; app-open routine for decay check.
enum MasteryService {

    /// Compose the mastery storage key for a (chapterId, levelType) pair.
    /// Per GAME_v3_LOCKED.md §7.3 — key format "<chapterId>.<levelType>".
    static func key(chapterId: String, levelType: LevelTypeID) -> String {
        "\(chapterId).\(levelType.rawValue)"
    }

    /// Record an attempt. Mutates the profile's `levelTypeMasteries` map:
    /// - Appends the AttemptRecord
    /// - Bumps lastPracticedAt
    /// - Promotes status from .locked/.preview → .active on first attempt
    /// - Checks mastery threshold; if met and not already mastered, sets
    ///   status → .mastered + masteredAt + schedules first review
    ///
    /// Returns true iff this call promoted to .mastered (caller fires celebration).
    @discardableResult
    static func recordAttempt(
        _ attempt: AttemptRecord,
        chapterId: String,
        levelType: LevelTypeID,
        in profile: inout PlayerProfile,
        now: Date = Date()
    ) -> Bool {
        let storageKey = key(chapterId: chapterId, levelType: levelType)
        var mastery = profile.levelTypeMasteries[storageKey]
            ?? LevelTypeMastery.empty(levelTypeId: storageKey)

        mastery.attemptHistory.append(attempt)
        mastery.lastPracticedAt = now

        if mastery.status == .locked || mastery.status == .preview {
            mastery.status = .active
        }

        var didMaster = false
        let requiresFirstTryFlex = (levelType == .findBoth)
        if mastery.status != .mastered,
           mastery.meetsMasteryThreshold(requiresFirstTryFlex: requiresFirstTryFlex) {
            mastery.status = .mastered
            mastery.masteredAt = now
            mastery.nextReviewAt = now.addingTimeInterval(86_400)  // +1 day
            didMaster = true
        }

        profile.levelTypeMasteries[storageKey] = mastery
        return didMaster
    }

    /// On app open: any level type with status == .mastered AND
    /// lastPracticedAt > 14 days ago gets demoted to .inReview (Ebbinghaus
    /// rusty rule). Per GAME_v3_LOCKED.md §4 + LEARNING_DESIGN_v3 §5.
    ///
    /// Mutates the profile in place. Idempotent.
    static func applyDecay(
        to profile: inout PlayerProfile,
        now: Date = Date(),
        rustyAfterDays: Double = 14
    ) {
        let rustyThreshold = now.addingTimeInterval(-rustyAfterDays * 86_400)
        for (key, var mastery) in profile.levelTypeMasteries {
            guard mastery.status == .mastered,
                  let last = mastery.lastPracticedAt,
                  last < rustyThreshold else { continue }
            mastery.status = .inReview
            profile.levelTypeMasteries[key] = mastery
        }
    }

    /// v3 §4 — SM-2 ease factor bump after a review attempt.
    /// Returns the new (interval seconds, ease factor) based on score:
    ///   1.0 (clean first try)    → 2.5× interval, ease stays high
    ///   0.6 (one-hint first try) → 2.0× interval
    ///   0.3 (multi-hint or 2nd)  → 1.3× interval
    ///   0.0 (miss/quit)          → reset to 1-day interval, demote status
    static func reviewIntervalBump(
        currentIntervalSeconds: TimeInterval,
        score: Double,
        currentEase: Double
    ) -> (newIntervalSeconds: TimeInterval, newEase: Double) {
        switch score {
        case let s where s >= 0.9:
            let ease = min(currentEase + 0.05, 2.5)
            return (currentIntervalSeconds * ease, ease)
        case let s where s >= 0.5:
            return (currentIntervalSeconds * 2.0, currentEase)
        case let s where s >= 0.2:
            let ease = max(currentEase - 0.2, 1.3)
            return (currentIntervalSeconds * 1.3, ease)
        default:
            // Failure resets the interval. Caller demotes status to .inReview.
            return (86_400, max(currentEase - 0.4, 1.3))
        }
    }

    /// Which level types are due for review right now. Mastered + nextReviewAt <= now.
    static func dueForReview(
        in profile: PlayerProfile,
        now: Date = Date()
    ) -> [String] {
        profile.levelTypeMasteries
            .filter { _, m in
                m.status == .mastered &&
                (m.nextReviewAt ?? .distantFuture) <= now
            }
            .map { $0.key }
    }
}
