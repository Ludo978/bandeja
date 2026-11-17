# Bandeja

Garmin Connect IQ device app (Monkey C) that keeps padel match score on the Forerunner 265 / 265S and records the match as a Padel activity in Garmin Connect.

## Source of truth
The repo is public. `SPEC.md`, `TASKS.md`, `docs/` and `spike/` are the maintainer's local notes: gitignored, not in the repo, and missing from a fresh clone (their history until the public release is in the private `bandeja-archive` repo). When they're missing, work from the code and ask the maintainer.
- `SPEC.md`: the specification. Before coding a task, read the spec sections the task lists.
- `TASKS.md`: the work breakdown. Phases 0, 1 and 2 are detailed; Phase 3 is epics.
- Mockups: the canvas linked in `SPEC.md` §8. UI must match them.
- `docs/spikes.md`: results of the Phase 0 spikes (create it on the first spike).

## Working rules
- One task per session. A task is done only when everything under its "Done when" is true; then tick it in `TASKS.md`.
- If the implementation changes a decision, update `SPEC.md` in the same session.
- Stay in scope: no Phase 3 features and no tournament formats unless the task says so.
- The scoring engine (`source/engine/`) is pure logic: no `WatchUi`, `ActivityRecording` or `Attention` imports. Write its `(:test)` unit tests in `source/tests/` first, from the spec rules.
- Monkey C type checking at "Strict", zero warnings.
- UI work: check both `fr265` (416 px) and `fr265s` (360 px) in the simulator, in English and French.
- Open-source references (`SPEC.md` §3.5) are for ideas only. Never copy code from a repo without a license.
- Never commit the developer key or build output (see `.gitignore`).
- Code comments never cite the local notes (no `SPEC §…`, task IDs, `docs/` files, spike numbers or mockup names): the public repo doesn't have them. Write the reason itself in the comment.
- Never run `git clean -x` (or `-X`): it deletes the gitignored local notes, which nothing else backs up.
- Commit messages use [gitmoji](https://gitmoji.dev): one emoji first, then a short imperative summary, with the task ID when there is one (e.g. `✨ P1.3 Add points, games and deuce rules`, `✅ P1.1 Add config tests`, `🐛 P1.4 Fix super tie-break games count`, `📝 Update SPEC §9.3 field budget`).

## Commands
`scripts/dev.sh` wraps the SDK. Device defaults to `fr265`. Every build uses strict type checking and fails on any compiler warning.
- Build: `scripts/dev.sh build [fr265|fr265s]` → `bin/bandeja-<device>.prg`
- Run in the simulator: `scripts/dev.sh run [device]` (starts the simulator if needed)
- Unit tests: `scripts/dev.sh test [device]` (runs the `(:test)` functions in the simulator, exits non-zero on any failure)
- Store package: `scripts/dev.sh export` → `bin/bandeja.iq` (release mode, with the app ID of `manifest.xml`, kept for the public release).
- Private beta package: `scripts/dev.sh export-beta` → `bin/bandeja-beta.iq`: the same app under the beta's own app ID (`11803f603c474b86af7d65c5cf70c437`, `BETA_ID` in `scripts/dev.sh`) and the name "Bandeja beta", in release mode like `export`, so it runs as the store build will (speed, battery) and has none of the debug tools (sensor lock debug menu and fixtures, the match menu's crash item): use the sideloaded debug build (`scripts/dev.sh deploy`, listed as "Bandeja") for those. Garmin never publishes a beta, so it never uses the release ID: upload it to the store's "Bandeja beta" app as a new version, never edit `manifest.xml` for it. Connect shows the developer fields only for a store-installed build.
- Bundled fonts: `scripts/make-fonts.sh` regenerates `bundled-fonts/` (Roboto Condensed as bitmap fonts for the watches without vector fonts: Descent G2, Instinct 3 AMOLED; macOS, downloads Roboto). What differs per watch (launcher icon size, bundled fonts, touchscreen, the Instinct glance window) is in `monkey.jungle`.
- Spike app (local only): same commands with `-p spike`, e.g. `scripts/dev.sh -p spike run fr265s`
- Developer key: `~/.garmin/developer_key.der` (override with `CIQ_KEY`). SDK: the SDK Manager's current SDK (override with `CIQ_SDK`).
- Sideload on the watch: plug it in (quit Garmin Express and OpenMTP), `scripts/dev.sh deploy [device]`, then unplug: the watch installs `GARMIN/Apps/BANDEJA.PRG` and removes the file. Uses libmtp (`brew install libmtp`); OpenMTP drag and drop into `GARMIN/Apps` also works. Garmin Connect doesn't show developer fields for sideloaded builds: those need the store beta.
- From the plugged-in watch: `scripts/dev.sh fit [count]` copies the newest activity FIT files to `bin/fit/`; `scripts/dev.sh logs` copies `GARMIN/Apps/LOGS` (crash reports) to `bin/logs/`.
- Debug output on the watch: `System.println` doesn't reach a file for sideloaded apps on the FR265, and `Application.Storage` is encrypted on disk. What works: keep lines in storage and write them into a saved recording as a string lap field, then `fit` + `fitdecode` (the spike's Button logger and **Export log** do this, see `docs/spikes.md`).
