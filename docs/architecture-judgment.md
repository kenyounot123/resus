# Architecture judgment

For a greenfield, single-user native macOS app, use the **Codable archive** as the base. Both proposals are sketches. These scores assess their stated contracts, not observed runtime behavior.

| Criterion | Archive | SwiftData | Reason |
| --- | ---: | ---: | --- |
| Source lifecycle invariants | 4 | 5 | Both retain source snapshots and derive staleness. SwiftData also defines immutable approved answers, replacement history, and an explicit omission response for clarifications. |
| Portable recovery | 5 | 3 | The archive has one versioned representation and an atomic replacement path. SwiftData needs a second format, container switching, a recovery journal, and schema migration. Those paths remain unproved. |
| Native editor correctness | 4 | 4 | Both keep one `NSTextView`, its selection, and undo state. Heading, list, paste, and relaunch behavior still need a macOS editor exercise. |
| Concurrency and stale responses | 4 | 4 | The archive has one domain writer, save revisions, and request IDs. SwiftData has one model writer, expected revisions, and generation IDs. Both need failure and race exercises. |
| Interface depth | 5 | 4 | Archive calls cover complete user actions. SwiftData's separate generation and library actors leave result storage coordination at their boundary. |

**Total:** Archive 22 of 25. SwiftData 20 of 25.

Graft two ideas from SwiftData. First, make approved answers immutable and retain the prior approval when an edited answer replaces one. This makes review history explicit without adopting database records. Second, add an explicit `omit` response to each clarification. A learner can reject an irrelevant or unanswerable prompt without inventing a meaning.

The archive's whole-library write cost is its material risk. Measure realistic library sizes and save latency during implementation. Do not add SwiftData until that evidence shows the archive fails the writing experience. Foundational Thinking favors one canonical value model and writer here. Experience First makes editor responsiveness and reliable recovery the deciding outcomes. Prove It Works makes the editor, crash recovery, and import exercises gates before either sketch counts as verified.
