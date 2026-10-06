import Foundation
import Testing
@testable import ResusCore

@Test func approvedAnswersPauseAfterTextEditsAndSurviveBackup() throws {
    let course = Course(title: "Pharmacology")
    var note = Note(courseID: course.id, title: "PK", text: "PK = what the body does to a drug")
    let card = Card(source: Source(noteID: note.id, noteText: note.text, excerpt: note.text), question: "What is PK?", answer: "What the body does to a drug", approval: .approved)
    note.rtf = Data("formatting only".utf8)
    #expect(card.isCurrent(in: [note]))
    note.text += "\nADME = absorption, distribution, metabolism, excretion"
    #expect(!card.isCurrent(in: [note]))
    #expect(card.answer == "What the body does to a drug")
    let library = Library(courses: [course], notes: [note], cards: [card])
    let restored = try Archive.decode(Archive.encode(library))
    #expect(restored == library)
    #expect(!restored.cards[0].isCurrent(in: restored.notes))
}

@Test func archivePreservesLastGoodSaveAndRecoversCorruptPrimary() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.json")
    let archive = Archive(url: url)
    let course = Course(title: "First")
    let first = Library(courses: [course])
    try await archive.save(first, revision: 1)
    let second = Library(courses: [course, Course(title: "Second")])
    try await archive.save(second, revision: 2)
    try await archive.save(first, revision: 1)
    #expect(try Archive.read(url) == second)
    #expect(try Archive.read(url.appendingPathExtension("previous")) == first)
    try Data("damaged".utf8).write(to: url)
    await #expect(throws: (any Error).self) { try await archive.save(second, revision: 3) }
    #expect(try Archive.read(url.appendingPathExtension("previous")) == first)
    let recovered = try await archive.previous()
    #expect(recovered == first)
    try await archive.restore(recovered)
    #expect(try Archive.read(url) == first)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains(where: { $0.contains("before-restore-") }))
}

@Test func importedArchivesRejectBrokenReferencesAndInventedSources() throws {
    let course = Course(title: "Course")
    let note = Note(courseID: course.id, title: "Note", text: "Receptor")
    let valid = Card(source: Source(noteID: note.id, noteText: note.text, excerpt: "Receptor"), question: "What?", answer: "Receptor")
    #expect(throws: (any Error).self) { try Library(courses: [], notes: [note], cards: [valid]).validated() }
    var bad = valid; bad.source.excerpt = "Invented"
    #expect(throws: (any Error).self) { try Library(courses: [course], notes: [note], cards: [bad]).validated() }
    #expect(throws: (any Error).self) { try Library(courses: [course, course], notes: [note], cards: [valid]).validated() }
    var newer = Library(); newer.version = 2
    #expect(throws: (any Error).self) { try Archive.decode(JSONEncoder().encode(newer)) }
}

@Test func ratingsScheduleOfflineReview() {
    let now = Date(timeIntervalSince1970: 1000)
    var card = Card(source: Source(noteID: UUID(), noteText: "Text", excerpt: "Text"), question: "Question", answer: "Answer", approval: .approved)
    card.rate(.remembered, now: now)
    #expect(card.dueAt == now.addingTimeInterval(86400))
    card.rate(.remembered, now: now)
    #expect(card.intervalDays == 2)
    card.rate(.again, now: now)
    #expect(card.dueAt == now.addingTimeInterval(600))
    #expect(card.intervalDays == 0)
    #expect(card.reviews == 3)
}

@Test func followUpClarificationsRetainMeaningsAndOmissions() throws {
    let first = Clarification(excerpt: "A", question: "Meaning?", response: .meaning("Alpha"))
    let omitted = Clarification(excerpt: "B", question: "Use this?", response: .omit)
    let next = Clarification(excerpt: "C", question: "Meaning?")
    let result = try Preparation(noteText: "A B C", clarifications: [first, omitted]).adding([next])
    #expect(result.clarifications == [first, omitted, next])
    let repeated = Clarification(excerpt: "A", question: "More detail?")
    let revised = try result.adding([repeated])
    #expect(revised.clarifications == [first, omitted, next, repeated])
}

@Test func archiveCannotSaveBytesItWouldRefuseToReopen() throws {
    let course = Course(title: "Course")
    let text = String(repeating: "x", count: 1_000_000)
    let note = Note(courseID: course.id, title: "Large", text: text)
    let cards = (0..<101).map { _ in Card(source: Source(noteID: note.id, noteText: text, excerpt: "x"), question: "What?", answer: "x") }
    #expect(throws: (any Error).self) { try Archive.encode(Library(courses: [course], notes: [note], cards: cards)) }
}
