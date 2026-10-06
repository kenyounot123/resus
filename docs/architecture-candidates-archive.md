# Codable archive candidate

## Problem

Resus must keep notes and approved answers usable without a network or API key. Generation adds uncertainty and requires review. A changed note must never silently replace an approved answer. The brief is the source of requirements. This proposal is a sketch, not verified implementation.

## Usage

The view asks the library to complete domain operations. It does not coordinate persistence or interpret provider JSON.

```swift
let noteID = library.addNote(to: courseID, title: "Shock")
library.editNote(noteID, body: editedBody)
await library.generate(from: noteID)
library.answer(clarificationID, with: "Mean arterial pressure")
await library.continueGeneration(for: noteID)
library.approve(cardID)
try await library.flush()
```

The editor owns the active text selection and undo stack. The library owns durable content. A provider failure leaves the note and any completed draft available.

## Shape

Define value types before framework delegates. The following names and signatures describe the intended contract. Bodies and private helper types remain unspecified.

```swift
struct Course: Identifiable, Codable, Sendable {
	let id: CourseID
	var title: String
}

struct Note: Identifiable, Codable, Sendable {
	let id: NoteID
	let courseID: CourseID
	var title: String
	var body: RichText
	var textRevision: UInt64
}

struct RichText: Codable, Sendable {
	let rtf: Data
	let plainText: String
}

struct Source: Codable, Sendable {
	let noteID: NoteID
	let textRevision: UInt64
	let noteText: String
	let excerpt: String
	let utf16Range: TextRange
}

struct Card: Identifiable, Codable, Sendable {
	let id: CardID
	var question: String
	var answer: String
	let source: Source
	var approval: Approval
}

enum Approval: Codable, Sendable {
	case draft
	case approved(at: Date)
}

enum SourceStatus {
	case current
	case changed
	case noteDeleted
}

enum Generation: Codable, Sendable {
	case clarification(Source, [Clarification])
	case drafts(Source, [CardID])
}

struct Clarification: Identifiable, Codable, Sendable {
	let id: ClarificationID
	let excerpt: String
	let question: String
	var answer: String?
}

struct LibraryArchive: Codable, Sendable {
	let schemaVersion: Int
	var revision: UInt64
	var courses: [Course]
	var notes: [Note]
	var cards: [Card]
	var generations: [Generation]
	var reviews: [Review]
}

@MainActor @Observable final class Library {
	private(set) var archive: LibraryArchive
	func addNote(to courseID: CourseID, title: String) -> NoteID
	func editNote(_ id: NoteID, body: RichText)
	func generate(from id: NoteID) async
	func answer(_ id: ClarificationID, with answer: String)
	func continueGeneration(for id: NoteID) async
	func approve(_ id: CardID)
	func sourceStatus(for id: CardID) -> SourceStatus
	func record(_ rating: Rating, for id: CardID, writtenAnswer: String?)
	func flush() async throws
}

actor Archive {
	func open() throws -> OpenResult
	func save(_ archive: LibraryArchive) throws
	func export(_ archive: LibraryArchive, to destination: URL) throws
	func importArchive(from source: URL) throws -> LibraryArchive
}

struct Generator {
	func clarify(_ source: Source) async throws -> [Clarification]
	func draft(_ source: Source, answers: [Clarification]) async throws -> [Card]
}
```

IDs are distinct UUID wrappers. Ratings are an enum. A review contains a card ID, timestamp, rating, and optional written answer. Manual cards use the same source selection and draft approval path. Written practice exposes the approved answer after submission and records the learner's rating. It needs no provider.

`RichText` accepts construction only through the editor codec. The codec derives plain text from the same attributed string that produces RTF. Decode validates that both representations agree. This confines AppKit objects to the main actor. Heading, bold, italic, and list actions use one `NSTextView` inside `NSViewRepresentable`. Its coordinator translates edits and selection. It does not save, generate, or rate cards. Preserve the text view instance and apply external content only when its identity or content actually changes, so SwiftUI updates do not reset selection or undo.

A note's text revision changes only when its canonical plain text changes. Formatting alone does not invalidate cards. `Source` preserves exact text and a UTF-16 range. The constructor checks that the range selects the stored excerpt. Provider output must match an exact excerpt in the submitted snapshot. Ambiguous repeated excerpts require a validated position. Source status derives from the live note revision. Any textual edit flags all cards from earlier revisions. Approval preserves the answer but does not clear this flag. A separate explicit re-review action can replace the source and answer together. Deleting a note retains card snapshots and produces `noteDeleted`.

Generation captures a source snapshot before network work. First request asks for unclear shorthand. Every clarification requires an explicit learner answer. Draft generation receives those answers and must return structured questions, answers, and exact source excerpts. Provider output cannot approve a card. Further ambiguity returns to clarification. The library validates the originating revision before accepting results. If the note changed, it retains the response for inspection but does not attach it as current or allow approval until generation restarts. Only one active request per note exists. Request IDs reject late responses after cancellation or replacement. Transient network progress is separate from the durable generation state, so relaunch never pretends a request still runs.

`Generator` owns provider payloads, response parsing, HTTP errors, request limits, and cancellation. The UI receives domain results. API keys live in Keychain and never enter archives or backups. The app shows the selected provider and explains that generation sends the selected note. A missing key leaves editing, manual cards, and study available. Real API verification requires actual credentials and must be reported separately from a local mock server test.

`Library` is the single main-actor writer for domain state. `Archive` serializes whole snapshots. The library increments archive revision before each mutation reaches the save queue. The archive rejects a revision older than the last committed revision, even if tasks arrive out of order. A short autosave debounce coalesces editor changes. The window shows pending, saved, or failed status. Window close and application termination await `flush` through an AppKit termination delegate. Save failure retains dirty content and offers retry or export.

The archive uses a versioned JSON envelope in Application Support. Write a temporary sibling, flush and close it, validate its complete decode, and atomically replace the primary file. Keep the prior validated primary as an independently written backup before replacement. Never overwrite the last good backup with unreadable primary bytes. An empty library is valid only on a confirmed first launch. On corrupt or unsupported archives, preserve all files and return a typed recovery result. Offer the valid backup if one exists. Newer schemas open a recovery screen, not an empty writable library. Migrations operate on a copy and retain the original until success.

Export produces the same self-contained archive without credentials. Import validates schema, references, IDs, source ranges, and rich text before any live change. The first implementation replaces the library as one operation, with a retained pre-import backup and explicit confirmation. It does not merge partial object graphs. Flush the current library first. A failed import leaves it active.

Use five ownership groups within one app target. Domain types and lifecycle rules are pure Swift. `Library` owns observable state and user operations. `Archive` owns disk representation and recovery. `Generator` owns provider transport. Views and the editor adapter own presentation. No repository protocol, generic service layer, or forwarding view model is required.

This interface hides save sequencing, source validation, and provider parsing behind complete operations. Callers retain only the domain choices they actually present. It passes the red-flag screen because no caller coordinates load, validate, transform, and save stages.

## Synthesis decision

This is the archive candidate for comparison with SwiftData. The parent design synthesis selects the base. This candidate favors portable recovery and an explicit domain model.

## Tradeoffs accepted

- Whole-library writes trade update efficiency for one inspectable backup and one atomic consistency boundary. Measure real note sizes before replacing this design.
- RTF plus canonical text duplicates data but preserves native editing and exact source checks. The codec must enforce agreement.
- Revision-wide invalidation can flag unaffected cards. It avoids guessing that a local edit has no semantic effect.
- Main-actor domain changes simplify editor coordination. Disk encoding and file work remain off that actor.

## Alternatives considered

SwiftData hides object tracking and incremental persistence. It exposes context lifetime, migration behavior, and relationships to domain operations unless wrapped carefully. A portable export still needs a separate validated schema. Choose it if measured archive size or query cost warrants those obligations.

A document package with one RTF file per note reduces rewriting. It needs cross-file transactions for cards, note revisions, and indexes. That complexity becomes visible during backup and crash recovery. The single archive hides more of it behind one commit.

A semantic block tree gives portable rich text and precise block references. It also requires a custom edit model and explicit conversion for paste, lists, selection, and undo. Native RTF is the stronger MVP choice for the requested writing experience.

## Open questions and risks

Can the native RTF editor preserve list and heading behavior across paste, undo, export, and relaunch? Prove this with an early editor slice.

At what real library size do whole-archive autosaves disrupt typing or shutdown? Measure that workload before setting limits.

Does the first provider reliably return exact excerpts and explicit ambiguity? Validate hostile and malformed responses before exposing approval.

## Next implementation step

Build one note editor that survives save, process restart, corruption recovery, and backup import before adding network generation.

The model-the-domain principle changed approval and generation into explicit states. Foundational-thinking changed mutation ownership to one main actor and one archive writer. Prove-it-works requires direct inspection of this sketch now and real editor, disk, and network exercises during implementation. This document defines the candidate only. No runtime behavior has been verified.
