# AGENTS.md

Project notes for coding agents working on this repository.

## Stack

Flutter (FVM) + Riverpod 3 + drift/SQLite. Android is the target platform; the
web build exists only for quick visual inspection.

- Format/analyze: `fvm flutter analyze`
- Tests: `fvm flutter test`
- Codegen (after changing drift tables/DAOs): `fvm dart run build_runner build`
- Localization: edit `lib/l10n/app_en.arb` + `app_zh.arb`, then
  `fvm flutter gen-l10n` (also runs automatically).

## Deploy

When the user says **"deploy the app"**, run exactly:

```bash
fvm flutter build apk
adb install build/app/outputs/flutter-apk/app-release.apk
```

Notes:

- `fvm flutter build apk` defaults to release; the artifact is
  `build/app/outputs/flutter-apk/app-release.apk`.
- `adb` is on `PATH` (`/usr/bin/adb`); the SDK copy lives at
  `~/.android/sdk/platform-tools/adb`. Target device is whatever `adb devices`
  reports (usually `emulator-5554`).
- If the install fails with `INSTALL_FAILED_ALREADY_EXISTS` / `UPDATE_INCOMPATIBLE`,
  re-run with `adb install -r <apk>`; use `adb uninstall io.github.chemio9.gtd`
  only when the user agrees to lose the local database.
- Release builds currently fall back to the **debug signing key**
  (`android/app/build.gradle.kts`), which installs fine but is not publishable.
  Adding `android/key.properties` switches it to the upload key.
- Report back: device serial, APK size and the package id (`io.github.chemio9.gtd`).

## Docs

`docs/DESIGN.md` (decisions), `docs/EDGE-CASES.md` (corner cases),
`docs/PROBLEMS.md` (bug journal), `docs/TESTING.md` (test patterns). Update them
when a decision or invariant changes.

## Conventions

- Conventional Commits, and every commit ends with:
  `Co-Authored-By: Deepseek v4.1 flash <noreply@deepseek.com>`
- Every behavioural change ships with tests (`flutter_test`, in-memory drift,
  fake gateways for platform channels) — no adb-driven end-to-end testing.
- UI strings go through `context.l10n`; keep both ARB files in sync.
- Search with the `ffgrep` / `fffind` tools, not `grep`/`rg`/`find` in bash —
  they are git-aware (skip `build/`, `.dart_tool/`) and frecency-ranked.
