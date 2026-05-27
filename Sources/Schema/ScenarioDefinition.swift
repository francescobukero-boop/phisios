import Foundation

/// Top-level shape of a scenario JSON file. One file = one scenario.
/// Identifiable conformance is required for `.fullScreenCover(item:)` —
/// the scenarioId is unique per definition.
struct ScenarioDefinition: Codable, Sendable, Equatable, Identifiable {
    var id: ScenarioID { scenarioId }

    let schemaVersion: SemVer
    let scenarioId: ScenarioID
    let meta: MetaDefinition
    let situation: SituationDefinition
    let input: InputDefinition
    let simulation: SimulationConfig
    let outcome: OutcomeDefinition
    let hints: [HintDefinition]
    let solution: SolutionDefinition?         // v1.1 — older v1.0 scenarios may not have this
    let animations: AnimationsDefinition
    let voice: VoiceDefinition
    let smokeTest: SmokeTestDefinition

    /// v3: which variables the player is solving for. Drives input mode
    /// selection (find-θ-only → NUMPAD_SINGLE_THETA, etc.) and answer
    /// matching. Optional for v2 legacy scenarios — defaults to both
    /// theta+v at curriculum-build time per GAME_v3_LOCKED.md §3.7.
    let unknowns: [String]?

    /// Explicit keys so a leading `$comment` field in JSON (used for designer notes) is tolerated.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, scenarioId, meta, situation, input, simulation,
             outcome, hints, solution, animations, voice, smokeTest, unknowns
    }
}
