import Foundation

/// One Daily Question — a bite-size, counterintuitive physics prompt tied to a
/// sport. Shown once a day on the Daily card: the user guesses, then the answer
/// reveals with a one-line "why" and a fun fact. Pure value type; the content
/// lives in `DailyQuestionCatalog`.
struct DailyQuestion: Identifiable, Equatable, Sendable {
    let id: String
    /// 1…N authoring order, also the rotation slot.
    let day: Int
    let sport: Sport
    /// Short principle tag, e.g. "Magnus effect". Shown as the eyebrow.
    let principle: String
    let prompt: String
    /// 2–3 answer choices, in display order.
    let options: [String]
    /// Index into `options` of the correct choice.
    let answerIndex: Int
    /// One-line explanation shown on reveal.
    let why: String
    /// One-line "huh, cool" shown on reveal.
    let funFact: String
    /// Asset name in the catalog (Resources/Illustrations/daily/), or nil for a
    /// clean type-only card. Lets us ship before any image is generated.
    let imageName: String?

    func isCorrect(_ pick: Int) -> Bool { pick == answerIndex }
}
