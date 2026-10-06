# Resus

Give your rough study notes another life. Resus is a local macOS app for writing notes, turning them into reviewable cards, and practicing offline.

## Download and run

Download the Mac app from this repository's releases. Resus requires macOS 14 or later. The universal binary contains Apple Silicon and Intel builds.

Unzip the app, or open the disk image and drag Resus into Applications. This first build is ad hoc signed and is not notarized. macOS can block a downloaded copy. Follow Apple's [instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac). Do not disable Gatekeeper globally. You can also build from source.

## Study with Resus

1. Click **New note** and write directly in the editor. Use headings, bold, italic, highlighting, and lists. Notes autosave locally.
2. Click **Add card** to write a card manually. Choose an exact source excerpt and save a draft or approve the card.
3. To generate drafts with AI, open **Settings**, choose OpenAI or Anthropic, and save your own API key. Click **Create cards** on a note.
4. Answer unclear shorthand or exclude the line. Review and approve the resulting drafts before studying.
5. Open **Cards** to study, or **Practice** to write an answer before comparing it with the approved answer.

Flashcards and practice work offline. **Study today** selects due cards. Remembered cards return after one day, then twice the previous interval up to 90 days. **Review again** schedules another review in 10 minutes. Practice uses self-rating, without AI grading.

Editing note text pauses every card made from the older source version. Formatting changes do not pause cards. Review changed cards explicitly before studying them again. Source inspectors retain the original note text. Exact source matching establishes provenance, not factual or medical correctness.

## Keep your library

The library is stored at `~/Library/Application Support/Resus/library.json`. A previous valid save is retained beside it. Settings and the File menu provide backup export and restore. Restore replaces the complete library and preserves the pre-restore file. API keys are stored in macOS Keychain and never enter backups.

Generation sends the selected note and clarified meanings to the chosen provider. There is no Resus account, backend, analytics, or automatic AI processing. Provider API usage has separate billing. Notes can be imported as UTF-8 text or RTF. Image attachments, lecture PDFs, sync, and AI grading are not part of this MVP.

A note supports up to 2 MB of text and 10 MB of RTF. AI generation accepts up to 100 KB of text per request. The archive supports up to 100 MB. Export a backup regularly.

## Build from source

Install Xcode with Swift 6 or later. Run these commands from the repository root.

```bash
swift test
scripts/build-app.sh
open dist/Resus.app
```

Create a universal download with `scripts/package.sh`. The output contains a zip, a disk image, and SHA-256 checksums in `dist/`. The build has no third-party dependencies.

For a checkout inside an iCloud-backed Documents folder, keep generated bundles and build intermediates outside that folder to avoid Finder metadata signing failures.

```bash
swift test --scratch-path /tmp/resus-build
RESUS_BUILD_DIR=/tmp/resus-build RESUS_DIST_DIR=/tmp/resus-dist scripts/package.sh
```

`RESUS_VERSION` selects the package version. `RESUS_SIGN_IDENTITY` selects a signing identity. It defaults to an ad hoc signature. A trusted public release needs a Developer ID identity and Apple notarization. Ad hoc builds can lose Keychain access after a rebuild, so API credential testing should use a stable signed build.

For native UI verification, use [.agents/skills/verify-resus/SKILL.md](.agents/skills/verify-resus/SKILL.md). The app accepts `--library-path PATH` to isolate test storage. Debug builds can use the loopback provider fixture. Release builds ignore that fixture setting.

## Verification status

Core and provider contract tests pass. Native UI checks cover writing, formatting, restart persistence, manual card approval, recall, written practice, source inspection, and backup behavior. Live provider requests are deferred. See [docs/verification.md](docs/verification.md) for the exact evidence and limits.

## License

[MIT](LICENSE). Copyright 2026 Ken Lu.
