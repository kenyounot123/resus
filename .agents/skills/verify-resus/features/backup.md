# Backup

## Sub-features

Export the complete local library without keys. Restore a validated backup with confirmation. Recover a corrupt primary from its previous save.

## How to get to it (user POV)

Settings and File menu expose Export backup and Restore backup. A failed startup shows Recover previous backup.

## Driving it with cua_repl

Export through the save panel. Add another note. Restore the exported file through the open panel and confirm replacement. Inspect library equality. For recovery only, quit the isolated app, corrupt its isolated primary, relaunch, and recover the previous save. Verify the damaged file remains preserved.

## Gotchas

Restore replaces the whole library. It does not merge. Malformed and newer-version backups fail before live data changes. Never corrupt a real user library.
