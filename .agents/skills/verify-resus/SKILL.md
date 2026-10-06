---
name: verify-resus
description: Build and drive Resus on macOS through its native UI, with isolated storage and evidence. Use when verifying notes, card generation, approval, study, or backup behavior.
---

# Verify Resus

## Launch

Use one UI driver. Keep test storage separate from the user's library. Run from the repository root.

```bash
RESUS_BUILD_DIR=/tmp/resus-swift-build RESUS_DIST_DIR=/tmp/resus-debug scripts/build-app.sh
mkdir -p .evidence
python3 scripts/provider-fixture.py --log .evidence/provider.jsonl
```

Keep the fixture's process handle. In another terminal, launch the debug app with a fresh storage folder.

```bash
RESUS_TEST_ENDPOINT=http://127.0.0.1:18765/v1/responses /tmp/resus-debug/Resus.app/Contents/MacOS/Resus --library-path /tmp/resus-verification/library.json
```

Keep the app's process handle. Bind it with `await cua.getApp("/tmp/resus-debug/Resus.app")`. The ready screen has **Start with your notes** or the existing isolated library. The production release ignores `RESUS_TEST_ENDPOINT`.

## Doctor

Read the running process arguments. They must include the isolated `--library-path`. Check the current AX state through the bound app. A recovery screen or an unexpected library is not ready for ordinary feature testing. Never kill another Resus process to make verification easier.

## Drive

Use `mcp__cua_repl` for native UI actions. Read AX state after each action group and use its fresh indices. Select controls by their displayed labels. The editor is **Note body**. The title is **Note title**. Do not edit library JSON to create a claimed UI result.

Live provider testing was deferred by the user during MVP delivery. Use manual cards for offline verification. For a later generation verification, open **Settings**, choose OpenAI, enter the nonsensitive fixture value `resus-local-fixture`, and click **Save key**. This saves a disposable value in the isolated library's Keychain service. Return to notes. Paste the following text into **Note body**.

```text
PK = what body does to drug
ADME = absorption, distribution, metabolism, excretion
antag = binds, no activation
```

Click **Create cards**. Answer the clarification with `Antagonist` through **Clarified meaning**, then **Save and next** and **Create drafts**. Review the returned cards and approve them. The fixture is a real HTTP boundary test, not proof of real provider quality.

Use [features/README.md](features/README.md) for the rest of the user paths.

## Evidence

Capture action and resulting AX state, screenshots, fixture request log, and the isolated archive. Inspect the archive after a UI edit and after restart. Formatting must survive. Approved answers must stay unchanged after text edits, and affected cards must pause. Verify backup restoration through the UI and inspect restored data. API keys must be absent from the library and backups. A screenshot alone does not establish persistence.

Save evidence in `.evidence/`. Report real-provider calls separately. The fixture must not be described as an AI success.

## Cleanup

In Settings, click **Remove key** for the fixture provider. Quit the app through its menu so the save path runs. Stop the fixture using the retained process handle. Remove only the isolated test storage if no longer needed. Keep `.evidence/` and screenshots. Do not kill by process name.

## Helpers

`scripts/build-app.sh` builds the native bundle. `scripts/provider-fixture.py --log .evidence/provider.jsonl` runs a loopback HTTP fixture. `swift test --scratch-path /tmp/resus-swift-build` runs domain, archive, and provider tests.
