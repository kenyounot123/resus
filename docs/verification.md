# MVP verification

Verified on an Apple Silicon Mac with macOS 26 and Xcode 27. The universal package contains arm64 and x86_64 slices with a macOS 14 minimum version. Intel execution and macOS 14 execution were not available on this host.

## Automated checks

`swift test --scratch-path /tmp/resus-swift-build` passes 11 tests. Parameterized provider cases cover both request envelopes, exact draft values, unclear shorthand, invented quotes, omitted lines, blank answers, refusals, truncation, and sanitized HTTP failures. Domain checks cover offline scheduling, preserved approved answers, source invalidation, backup round trips, duplicate and broken records, clarification retention, and the archive size limit.

Provider tests use a URLProtocol HTTP fixture. No real provider request succeeded. The user deferred API key testing. The earlier UI fixture exercise stopped at Keychain access after a rebuild. Its disposable entry was removed. Settings now opens without reading a saved key. Key operations run off the UI thread and refuse interactive authentication. A stable signed build still needs live API verification.

## Native UI checks

The app was driven through cua_repl, with fresh accessibility observations between actions. Screenshots were inspected in the task transcript. Verification used an isolated `--library-path`, never the user's normal library.

- Created two notes through New note and edited their titles and bodies.
- Applied bold, italic, a heading, and bullets. Exercised list undo. Formatted notes survived process restart.
- Created a manual draft with an exact source excerpt. Study and Practice stayed disabled before approval.
- Approved the card. Flashcards hid its answer until Reveal answer. Source opened the saved original note beside it.
- Remembered and Review again produced persisted review counts and scheduled dates. Practice accepted a written answer and displayed it beside the approved answer.
- Formatting changes kept a card current. A text edit paused it and preserved its answer. Explicit review and reapproval made it available again.
- Exported a backup through the save dialog. Restored it after a note edit. The same note ID reloaded its restored text and reset the editor's undo state. The next edit did not resurrect the discarded text.
- Extracted the release zip and verified its code signature. Launched that extracted app against an intentionally damaged isolated library. It showed recovery, restored the prior valid library, retained native bullets and approved cards, and preserved the damaged original file.
- Read the resulting archives to confirm answers, source snapshots, review counts, restored text, and absence of the disposable key.

## Distribution

`scripts/package.sh` builds a universal app, zip, disk image, and checksums. `codesign --verify --strict` passed on the extracted app. `lipo -archs` reports x86_64 and arm64. `vtool -show-build` reports a 14.0 minimum for both slices. Disk image validation and checksums are recorded in the local evidence.

`security find-identity -v -p codesigning` showed Apple Development identities and no Developer ID identity. The preview is ad hoc signed and not notarized. It can trigger Gatekeeper on another Mac. Trusted public distribution remains open.

## Remaining limits

Live AI generation, clarification UI with a real provider, Keychain access across signed app upgrades, image attachments, lecture PDFs, sync, and AI grading are not verified or included. The first three require the next provider testing pass. The app uses conservative invalidation of every card after a note text edit. It retains review counts and intervals, but not every past answer revision.

## Evidence

Local `.evidence/` holds the test and package logs, exported backup, saved review library, recovered library, signing inventory, and the process sample for the fixed Keychain UI freeze. The folder is ignored by Git. The committed verification skill describes how to reproduce the native checks. Mock design references in `docs/design/` are prototypes, not verification screenshots.
