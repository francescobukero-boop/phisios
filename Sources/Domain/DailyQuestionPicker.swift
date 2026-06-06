import Foundation

/// Picks today's Daily Question. Deterministic per calendar day: every player
/// sees the same question on a given day (it's a shared daily, like a crossword),
/// and it rotates at local midnight. Walks the catalog in order, wrapping every
/// `count` days, so the 30 authored questions cycle cleanly.
enum DailyQuestionPicker {

    /// Index into `questions` for the given day. Uses whole days since the Unix
    /// epoch (in the user's calendar) so the rotation is smooth across month and
    /// year boundaries — no reset.
    static func index(for date: Date, count: Int, calendar: Calendar = .current) -> Int {
        guard count > 0 else { return 0 }
        let startOfDay = calendar.startOfDay(for: date)
        let dayNumber = Int(floor(startOfDay.timeIntervalSince1970 / 86_400))
        return ((dayNumber % count) + count) % count   // always 0..<count, even pre-1970
    }

    /// Today's question from the catalog (or a supplied list, for tests).
    static func todays(
        on date: Date = Date(),
        from questions: [DailyQuestion] = DailyQuestionCatalog.all,
        calendar: Calendar = .current
    ) -> DailyQuestion? {
        guard !questions.isEmpty else { return nil }
        return questions[index(for: date, count: questions.count, calendar: calendar)]
    }
}
