<h1 align="center">Resus <sub>/REE-suss/</sub></h1>

<h3 align="center">
  Write your messy lecture notes scattered with shorthand notations and see them all come together through reviewable flash cards.
</h3>

<p align="center">
  <a href="https://github.com/kenyounot123/resus/releases"><img src="https://img.shields.io/badge/download-releases-ef7430?style=flat-square" alt="Download from releases"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square" alt="macOS 14 or later">
</p>

Resus is a local macOS app for writing notes, turning them into reviewable cards, and practicing offline.

## Features

- Write and format notes with headings, bold, italic, highlighting, and lists. Your notes autosave on your Mac.
- Create flashcards yourself or generate drafts with OpenAI or Anthropic using your own API key.
- Review and approve cards before studying, with the original note excerpt alongside each card.
- Study due flashcards with spaced repetition, or practice written answers and compare them with approved answers.
- Study offline and keep your library locally, without a Resus account.
- Import text or RTF notes, and export backups to keep your library safe.

## Download and install

[Download Resus for Mac](https://github.com/kenyounot123/resus/releases). Requires macOS 14 or later and supports Apple Silicon and Intel Macs.

1. Unzip the app, or open the disk image.
2. Drag **Resus** into **Applications** and open it.
3. If macOS blocks it, open **System Settings > Privacy & Security** and click **Open Anyway** for Resus.

This early release isn't notarized by Apple. Only approve it if you trust the download. See [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac).

## How it works

1. Click **New note** to write your notes, or import a text or RTF file.
2. Click **Add card** to create a card manually and choose its source excerpt. To use AI, add your OpenAI or Anthropic API key in **Settings**, then click **Create cards** on a note.
3. Clarify any unclear shorthand or exclude the line. Review the drafts and approve the cards you want to study.
4. Open **Cards** to study flashcards. **Study today** selects cards due for review.
5. Open **Practice** to write an answer, compare it with the approved answer, and rate your recall.

Remembered cards return at longer intervals. **Review again** brings a card back in 10 minutes. Flashcards and practice work offline.

When you edit a note's text, Resus pauses cards based on the previous version so you can review them before studying again. Formatting changes don't pause cards. Check your notes and answers for accuracy before approving them.

## Your notes and privacy

Your notes and cards stay on your Mac. AI generation sends the selected note and your clarifications to the provider you choose, only when you request it. Provider API usage is billed separately.

API keys are stored in macOS Keychain and aren't included in backups. There are no analytics or automatic AI processing.

Export backups from **Settings** or the **File** menu. Restoring a backup replaces your current library, and Resus keeps a copy of the library from before the restore.

## License

[MIT](LICENSE). Copyright 2026 Ken Lu.
