# Architecture

Resus uses Codable values in one versioned local library. SwiftUI owns presentation. A main-actor store owns user actions. AppKit owns the rich text editor and undo. The archive owns atomic disk writes and recovery. Provider transport owns JSON parsing and source validation.

The caller writes a note, requests generation, resolves unclear terms, approves drafts, and rates approved cards. A card stores the original note text and an exact excerpt. The current note text determines whether the card can be studied. Formatting never changes that comparison. Re-review is explicit.

Course, Note, Card, Source, Clarification, and Library are plain domain nouns. Lecture was rejected because notes can also come from reading. StudyItem was rejected because it hides what the record contains.

The archive candidate is the base. Parent scoring favored portable recovery and smaller persistence surface. Independent gpt-6-sol review scored archive22/25 and SwiftData20/25. Both reviewers use OpenAI models, so agreement is not cross-vendor evidence. SwiftData contributed explicit omission of unclear lines. History is limited to review counts and intervals in this MVP. It does not retain every answer revision.

We accept whole-library writes for a portable, inspectable archive. We accept conservative source invalidation after every text edit rather than semantic inference. All writes occur through one store. Failed writes preserve the prior disk archive. The app retains in-memory edits and lets the user reduce content, remove cards, export when valid, or retry saving.

Generated cards remain drafts. Prompt instructions describe notes as study context, not verified facts. Responses require exact excerpts. A source match establishes provenance, not medical correctness. Written practice uses reveal and self-rating offline. AI grading is deferred.

The empty repository has no reusable production components. The native views reuse the Paper palette, sidebar dimensions, formatting actions, and source inspector. SwiftUI standard controls and one NSTextView replace static HTML.
