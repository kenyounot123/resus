# SwiftData candidate

## Problem and usage

The caller saves a note with an expected revision, answers generation clarifications, and approves drafts. Practice reads approved cards offline.

## Shape

Proposed declarations. IDs wrap UUIDs. Domain values are Sendable.

```swift
struct Course { let id: CourseID; var title: String }
struct Note {
	let id: NoteID
	let courseID: CourseID
	let revision: Revision
	let body: RichText
}
struct RichText { let rtf: Data; let plainText: String }
struct Source {
	let noteID: NoteID
	let textDigest: Digest
	let plainText: String
	let excerpt: String
	let range: UTF16Range
}
struct Card {
	let id: CardID
	let revision: Revision
	let source: Source
	let state: CardState
}
enum CardState {
	case draft(question: String, answer: String)
	case approved(question: String, answer: String, at: Date)
}
enum SourceStatus { case current; case changed; case noteDeleted }
struct Clarification { let id: ClarificationID; let excerpt: String; let question: String }
enum ClarificationResponse { case meaning(String); case omit }
enum GenerationResult {
	case clarify(GenerationID, [Clarification])
	case review(GenerationID, [Card])
}
enum PracticeResponse {
	case recall(Rating)
	case written(answer: String, rating: Rating)
}
```

`Domain` owns pure approval, source-status, and practice rules. `Library` owns private SwiftData records and one context. `Generation` owns provider requests and persisted clarification sessions. `App` owns SwiftUI and the AppKit editor.

```swift
@ModelActor actor Library {
	func note(_ id: NoteID) throws -> Note
	func save(_ id: NoteID, body: RichText, expecting: Revision) throws -> Note
	func store(_ result: GenerationResult, from snapshot: Note) throws
	func approve(_ id: CardID, expecting: Revision) throws -> Card
	func export(to url: URL) throws
	func importBackup(from url: URL) throws
}
actor Generation {
	func generate(_ id: NoteID, expecting: Revision) async throws -> GenerationResult
	func clarify(_ id: GenerationID,
		responses: [ClarificationID: ClarificationResponse]) async throws -> GenerationResult
}
```

Records use stable UUID foreign keys and queryable scalar columns. Codable payloads hold enum state and source snapshots. Explicit saves disable implicit autosave. Failed operations roll back. No mutation awaits networking.

Source construction validates an exact nonempty excerpt against its UTF-16 range. Any plain-text change flags older sources. Formatting changes preserve the text digest. Approval checks the current digest and draft revision. Approved answers remain immutable. Editing creates a replacement draft and retains approval history.

An `NSTextView` owns rich text, selection, marked input, and undo. Its independent buffer produces debounced RTF snapshots. Switching notes, generation, export, and termination flush pending saves. Errors retain the dirty buffer. SwiftUI updates never reset active text storage after keystrokes.

Generation sends immutable snapshots through one provider adapter. Keychain owns keys. Ambiguous excerpts require user meanings or omission before draft generation. The adapter validates returned quotes and never approves cards. Generation IDs prevent duplicate draft insertion. Interrupted requests require explicit retry. Manual cards and practice work without credentials.

Backup exports versioned domain records and RTF, excluding keys. Import validates all records, builds a sibling container, reads it back, and switches libraries only after verification. A pre-import portable backup and recovery journal protect replacement. Startup preserves failed stores. Never copy an open SQLite store. Start with VersionedSchema at release one.

## Tradeoffs and alternatives

SwiftData accepts mapping and migration complexity for record fetches and commits. Atomic Codable archives make recovery simpler but rewrite the complete library. Direct `@Query` editing leaks persistence and approval policy into screens. `NSDocument` per note scatters library-wide backup and card ownership.

## Decision and verification

Model the Domain selects explicit card states. Boundary Discipline keeps storage and provider payloads private. Foundational Thinking establishes snapshots first. Choose SwiftData only after macOS 14 spikes prove rich-text round trips, interrupted import recovery, and schema migration. No real API verification is claimed.

Apple documents [ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor), [migration plans](https://developer.apple.com/documentation/swiftdata/schemamigrationplan), and [NSTextView](https://developer.apple.com/documentation/appkit/nstextview).
