import Foundation

public struct Course: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public init(id: UUID = UUID(), title: String) { self.id = id; self.title = title }
}

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var courseID: UUID
    public var title: String
    public var rtf: Data
    public var text: String
    public var modifiedAt: Date
    public var preparation: Preparation?
    public init(id: UUID = UUID(), courseID: UUID, title: String, rtf: Data = Data(), text: String = "", modifiedAt: Date = Date()) {
        self.id = id; self.courseID = courseID; self.title = title
        self.rtf = rtf; self.text = text; self.modifiedAt = modifiedAt
    }
}

public struct Source: Codable, Equatable, Sendable {
    public var noteID: UUID
    public var noteText: String
    public var excerpt: String
    public init(noteID: UUID, noteText: String, excerpt: String) {
        self.noteID = noteID; self.noteText = noteText; self.excerpt = excerpt
    }
}

public enum Approval: String, Codable, Sendable { case draft, approved }
public enum Rating: String, Codable, Sendable { case again, remembered }

public struct Card: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var source: Source
    public var question: String
    public var answer: String
    public var approval: Approval
    public var dueAt: Date
    public var intervalDays: Int
    public var reviews: Int
    public init(id: UUID = UUID(), source: Source, question: String, answer: String, approval: Approval = .draft) {
        self.id = id; self.source = source; self.question = question; self.answer = answer
        self.approval = approval; self.dueAt = Date(); self.intervalDays = 0; self.reviews = 0
    }
    public func isCurrent(in notes: [Note]) -> Bool {
        notes.first(where: { $0.id == source.noteID })?.text == source.noteText
    }
    public mutating func rate(_ rating: Rating, now: Date = Date()) {
        reviews += 1
        intervalDays = rating == .again ? 0 : min(max(intervalDays * 2, 1), 90)
        dueAt = rating == .again ? now.addingTimeInterval(600) : now.addingTimeInterval(Double(intervalDays) * 86400)
    }
}

public enum ClarificationResponse: Codable, Equatable, Sendable {
    case unanswered
    case meaning(String)
    case omit
    public var isAnswered: Bool { if case .unanswered = self { return false }; return true }
}

public struct Clarification: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var excerpt: String
    public var question: String
    public var response: ClarificationResponse
    public init(id: UUID = UUID(), excerpt: String, question: String, response: ClarificationResponse = .unanswered) {
        self.id = id; self.excerpt = excerpt; self.question = question; self.response = response
    }
}

public struct Preparation: Codable, Equatable, Sendable {
    public var noteText: String
    public var clarifications: [Clarification]
    public init(noteText: String, clarifications: [Clarification]) {
        self.noteText = noteText; self.clarifications = clarifications
    }
    public func adding(_ questions: [Clarification]) throws -> Preparation {
        let combined = clarifications + questions
        guard combined.count <= 20 else { throw ResusError.invalid("This note needs too many clarifications. Split it into smaller notes.") }
        return Preparation(noteText: noteText, clarifications: combined)
    }
}

public struct Library: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var courses: [Course]
    public var notes: [Note]
    public var cards: [Card]
    public init(courses: [Course] = [], notes: [Note] = [], cards: [Card] = []) {
        self.courses = courses; self.notes = notes; self.cards = cards
    }
    public func validated() throws -> Library {
        guard version == 1 else { throw ResusError.invalid("This backup uses an unsupported version.") }
        guard courses.count <= 1000, notes.count <= 10000, cards.count <= 100000,
              Set(courses.map(\.id)).count == courses.count,
              Set(notes.map(\.id)).count == notes.count,
              Set(cards.map(\.id)).count == cards.count else { throw ResusError.invalid("This library contains duplicate records or exceeds the supported size.") }
        for note in notes {
            guard courses.contains(where: { $0.id == note.courseID }), note.text.utf8.count <= 2_000_000,
                  note.rtf.count <= 10_000_000 else { throw ResusError.invalid("A note in this library is invalid.") }
            if let preparation = note.preparation {
                guard preparation.clarifications.count <= 20,
                      preparation.clarifications.allSatisfy({ !$0.excerpt.isEmpty && preparation.noteText.contains($0.excerpt) }) else {
                    throw ResusError.invalid("A clarification has an invalid source.")
                }
            }
        }
        for card in cards {
            guard notes.contains(where: { $0.id == card.source.noteID }),
                  !card.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.source.excerpt.isEmpty, card.source.noteText.contains(card.source.excerpt),
                  card.intervalDays >= 0, card.reviews >= 0 else { throw ResusError.invalid("A card in this library has an invalid answer or source.") }
        }
        return self
    }
}

public enum ResusError: Error, LocalizedError, Sendable {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): message } }
}

public enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI, anthropic
    public var id: String { rawValue }
    public var title: String { self == .openAI ? "OpenAI" : "Anthropic" }
    public var defaultModel: String { self == .openAI ? "gpt-4.1-mini" : "claude-sonnet-4-5" }
}

public struct GeneratedCard: Codable, Equatable, Sendable {
    public var question: String
    public var answer: String
    public var excerpt: String
    public init(question: String, answer: String, excerpt: String) { self.question = question; self.answer = answer; self.excerpt = excerpt }
}
public struct GeneratedClarification: Codable, Equatable, Sendable {
    public var excerpt: String
    public var question: String
    public init(excerpt: String, question: String) { self.excerpt = excerpt; self.question = question }
}
public struct GenerationResult: Codable, Equatable, Sendable {
    public var clarifications: [GeneratedClarification]
    public var cards: [GeneratedCard]
    public init(clarifications: [GeneratedClarification], cards: [GeneratedCard]) { self.clarifications = clarifications; self.cards = cards }
}
