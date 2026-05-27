import XCTest
@testable import PhysicsGame

/// v3 §3.2 mastery formula tests. Verifies the rolling-window scoring,
/// hard-variant gate, and first-try-flex bonus on Level D per the locked spec.
final class MasteryServiceTests: XCTestCase {

    // MARK: - mastery score arithmetic

    func test_emptyHistory_scoreIsZero() {
        let m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        XCTAssertEqual(m.masteryScore, 0.0)
    }

    func test_underfullWindow_scoreIsZero_evenIfAllClean() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 5 clean attempts — window size is 6, so still 0.
        for i in 0..<5 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        XCTAssertEqual(m.masteryScore, 0.0)
    }

    func test_fullWindow_allCleanFirstTry_scoreIsOne() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        for i in 0..<6 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        XCTAssertEqual(m.masteryScore, 1.0, accuracy: 0.001)
    }

    func test_oneHint_scoresPartial() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 5 clean + 1 with one-hint = (5×1.0 + 0.6) / 6 = 0.933
        for i in 0..<5 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        m.attemptHistory.append(att(.swish, firstTry: true, hints: 1, bucket: .easy, sit: "s5"))
        XCTAssertEqual(m.masteryScore, (5.0 + 0.6) / 6.0, accuracy: 0.001)
    }

    func test_missDoesNotReset_justShiftsWindow() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 6 clean then 1 miss — window now has 5 clean + 1 miss.
        for i in 0..<6 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        m.attemptHistory.append(att(.miss, firstTry: false, hints: 0, bucket: .easy, sit: "s6"))
        XCTAssertEqual(m.masteryScore, 5.0 / 6.0, accuracy: 0.001)
    }

    // MARK: - mastery threshold (the 0.75 + hard-variant gate)

    func test_mastery_meetsThreshold_whenScoreAboveAndHardPresent() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 5 easy clean + 1 hard clean = 1.0 score AND hard present.
        for i in 0..<5 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .hard, sit: "h0"))
        XCTAssertTrue(m.meetsMasteryThreshold(requiresFirstTryFlex: false))
    }

    func test_mastery_denied_whenAllEasy_noHardVariant() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 6 easy clean = 1.0 score but NO hard variant. Denied (anti-grind).
        for i in 0..<6 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        XCTAssertEqual(m.masteryScore, 1.0)
        XCTAssertFalse(m.meetsMasteryThreshold(requiresFirstTryFlex: false))
    }

    func test_mastery_denied_whenScoreBelowThreshold() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.A")
        // 4 clean + 2 misses, one hard. Score = 4/6 = 0.667 < 0.75. Denied.
        for i in 0..<4 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)"))
        }
        m.attemptHistory.append(att(.miss, firstTry: false, hints: 0, bucket: .hard, sit: "h0"))
        m.attemptHistory.append(att(.miss, firstTry: false, hints: 0, bucket: .medium, sit: "s5"))
        XCTAssertFalse(m.meetsMasteryThreshold(requiresFirstTryFlex: false))
    }

    // MARK: - Level D first-try-flex bonus

    func test_levelD_requiresFirstTrySwish_onFreshSituation() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.D")
        // Pre-seed history so all window situations are "seen before".
        for i in 0..<6 {
            m.attemptHistory.append(att(.swish, firstTry: false, hints: 0, bucket: .easy, sit: "seen\(i)"))
        }
        // 6 clean first-try on the SAME pre-seeded situations — no fresh situation.
        for i in 0..<5 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "seen\(i)"))
        }
        m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .hard, sit: "seen5"))
        XCTAssertEqual(m.masteryScore, 1.0)
        // Non-D mode: passes (hard variant + score met).
        XCTAssertTrue(m.meetsMasteryThreshold(requiresFirstTryFlex: false))
        // D mode: denied — no fresh first-try swish in window.
        XCTAssertFalse(m.meetsMasteryThreshold(requiresFirstTryFlex: true))
    }

    func test_levelD_passes_whenWindowIncludesFreshFirstTrySwish() {
        var m = LevelTypeMastery.empty(levelTypeId: "ch1.D")
        for i in 0..<6 {
            m.attemptHistory.append(att(.swish, firstTry: false, hints: 0, bucket: .easy, sit: "seen\(i)"))
        }
        for i in 0..<5 {
            m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "seen\(i)"))
        }
        // Last attempt: a NEW situation, first-try SWISH, hard bucket.
        m.attemptHistory.append(att(.swish, firstTry: true, hints: 0, bucket: .hard, sit: "fresh"))
        XCTAssertTrue(m.meetsMasteryThreshold(requiresFirstTryFlex: true))
    }

    // MARK: - MasteryService.recordAttempt + decay

    func test_recordAttempt_promotesLockedToActive() {
        var profile = PlayerProfile.newProfile()
        let a = att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s0")
        MasteryService.recordAttempt(a, chapterId: "ch1_arc", levelType: .findTheta, in: &profile)
        let key = MasteryService.key(chapterId: "ch1_arc", levelType: .findTheta)
        XCTAssertEqual(profile.levelTypeMasteries[key]?.status, .active)
        XCTAssertEqual(profile.levelTypeMasteries[key]?.attemptHistory.count, 1)
    }

    func test_recordAttempt_returnsTrue_onMasteryPromotion() {
        var profile = PlayerProfile.newProfile()
        var didMaster = false
        // 5 easy clean + 1 hard clean = mastery on the 6th call.
        for i in 0..<5 {
            let a = att(.swish, firstTry: true, hints: 0, bucket: .easy, sit: "s\(i)")
            let promoted = MasteryService.recordAttempt(a, chapterId: "ch1_arc", levelType: .findTheta, in: &profile)
            XCTAssertFalse(promoted, "Should not master on attempt \(i + 1)")
        }
        let hardA = att(.swish, firstTry: true, hints: 0, bucket: .hard, sit: "h0")
        didMaster = MasteryService.recordAttempt(hardA, chapterId: "ch1_arc", levelType: .findTheta, in: &profile)
        XCTAssertTrue(didMaster, "Sixth attempt should promote to mastered")

        let key = MasteryService.key(chapterId: "ch1_arc", levelType: .findTheta)
        XCTAssertEqual(profile.levelTypeMasteries[key]?.status, .mastered)
        XCTAssertNotNil(profile.levelTypeMasteries[key]?.masteredAt)
        XCTAssertNotNil(profile.levelTypeMasteries[key]?.nextReviewAt)
    }

    func test_decay_demotes_masteredAfter14Days() {
        var profile = PlayerProfile.newProfile()
        let key = MasteryService.key(chapterId: "ch1_arc", levelType: .findTheta)
        let old = Date(timeIntervalSinceNow: -15 * 86_400)   // 15 days ago
        profile.levelTypeMasteries[key] = LevelTypeMastery(
            levelTypeId: key,
            attemptHistory: [],
            status: .mastered,
            masteredAt: old,
            lastPracticedAt: old,
            nextReviewAt: nil,
            easeFactor: 2.5
        )
        MasteryService.applyDecay(to: &profile)
        XCTAssertEqual(profile.levelTypeMasteries[key]?.status, .inReview)
    }

    // MARK: - Spaced review interval bumps (v3 §4)

    func test_reviewBump_cleanFirstTry_doublesPlus() {
        let result = MasteryService.reviewIntervalBump(
            currentIntervalSeconds: 86_400,   // 1 day
            score: 1.0,
            currentEase: 2.5
        )
        // 1.0 score → ease stays at 2.5, interval × 2.5 = 2.5 days
        XCTAssertEqual(result.newEase, 2.5, accuracy: 0.01)
        XCTAssertEqual(result.newIntervalSeconds, 86_400 * 2.5, accuracy: 1.0)
    }

    func test_reviewBump_oneHint_bumps2x() {
        let result = MasteryService.reviewIntervalBump(
            currentIntervalSeconds: 86_400,
            score: 0.6,
            currentEase: 2.5
        )
        XCTAssertEqual(result.newIntervalSeconds, 86_400 * 2.0, accuracy: 1.0)
    }

    func test_reviewBump_multiHint_bumps1_3x() {
        let result = MasteryService.reviewIntervalBump(
            currentIntervalSeconds: 86_400,
            score: 0.3,
            currentEase: 2.5
        )
        XCTAssertEqual(result.newIntervalSeconds, 86_400 * 1.3, accuracy: 1.0)
        XCTAssertEqual(result.newEase, 2.3, accuracy: 0.01)
    }

    func test_reviewBump_failure_resetsInterval() {
        let result = MasteryService.reviewIntervalBump(
            currentIntervalSeconds: 86_400 * 21,  // 21d
            score: 0.0,
            currentEase: 2.5
        )
        // Reset to 1d, ease drops by 0.4.
        XCTAssertEqual(result.newIntervalSeconds, 86_400, accuracy: 1.0)
        XCTAssertEqual(result.newEase, 2.1, accuracy: 0.01)
    }

    func test_reviewBump_easeFloor_neverDropsBelow1_3() {
        var ease = 2.5
        // Hammer it with 10 failures.
        for _ in 0..<10 {
            ease = MasteryService.reviewIntervalBump(
                currentIntervalSeconds: 86_400,
                score: 0.0,
                currentEase: ease
            ).newEase
        }
        XCTAssertGreaterThanOrEqual(ease, 1.3)
    }

    func test_dueForReview_picksMasteredWithPastInterval() {
        var profile = PlayerProfile.newProfile()
        let dueKey = MasteryService.key(chapterId: "ch1_arc", levelType: .findTheta)
        let notDueKey = MasteryService.key(chapterId: "ch1_arc", levelType: .findV)
        let yesterday = Date(timeIntervalSinceNow: -86_400)
        let tomorrow = Date(timeIntervalSinceNow: 86_400)
        profile.levelTypeMasteries[dueKey] = LevelTypeMastery(
            levelTypeId: dueKey, attemptHistory: [], status: .mastered,
            masteredAt: yesterday, lastPracticedAt: yesterday,
            nextReviewAt: yesterday, easeFactor: 2.5
        )
        profile.levelTypeMasteries[notDueKey] = LevelTypeMastery(
            levelTypeId: notDueKey, attemptHistory: [], status: .mastered,
            masteredAt: yesterday, lastPracticedAt: yesterday,
            nextReviewAt: tomorrow, easeFactor: 2.5
        )
        let due = MasteryService.dueForReview(in: profile)
        XCTAssertEqual(due, [dueKey])
    }

    func test_decay_leaves_freshMasteredAlone() {
        var profile = PlayerProfile.newProfile()
        let key = MasteryService.key(chapterId: "ch1_arc", levelType: .findTheta)
        let recent = Date(timeIntervalSinceNow: -3 * 86_400)  // 3 days ago
        profile.levelTypeMasteries[key] = LevelTypeMastery(
            levelTypeId: key,
            attemptHistory: [],
            status: .mastered,
            masteredAt: recent,
            lastPracticedAt: recent,
            nextReviewAt: nil,
            easeFactor: 2.5
        )
        MasteryService.applyDecay(to: &profile)
        XCTAssertEqual(profile.levelTypeMasteries[key]?.status, .mastered)
    }

    // MARK: - Helpers

    private func att(
        _ outcome: AttemptOutcome,
        firstTry: Bool,
        hints: Int,
        bucket: DifficultyBucket,
        sit: String
    ) -> AttemptRecord {
        AttemptRecord(
            situationId: sit,
            levelTypeId: "ch1.A",
            outcome: outcome,
            isFirstTry: firstTry,
            hintsUsed: hints,
            timeToAnswerMs: 15_000,
            difficultyBucket: bucket,
            wasReview: false,
            wasInterleaved: false,
            timestamp: Date()
        )
    }
}
