# AGENTS.md - AI Coding Agent Operating Rules for Pomo

This file provides universal operating rules for all AI coding agents (Claude Code, Cursor, Antigravity, OpenClaw, Codex) working inside the `pomo` repository (`github.com/recoskyler/pomo`).

## 1. Fast Orientation

- **Product Overview**: `pomo` is an open-source, cross-platform Pomodoro timer built with Flutter. It supports adjustable work/break durations, custom sound alerts, RGB Webhook triggers (for HomeAssistant light synchronization), and multi-window desktop floating timers (`desktop_multi_window` / `tray_manager`).
- **Full Guidance**: Read `CLAUDE.md` and `ARCHITECTURE.md` before making architectural or state management modifications.

## 2. Command Prefixing with RTK

To minimize context token usage during autonomous operations, all shell interactions must use the `rtk` prefix where applicable:
```bash
rtk git status
rtk git diff
rtk grep "TimerCubit"
rtk ls lib/pages/timer/cubit
```

## 3. Build & Run Prerequisites

Never run `flutter build` or `flutter test` without ensuring `flutter pub get` and `flutter gen-l10n` have executed first:
```bash
flutter pub get
flutter gen-l10n
```
Or run `./scripts/setup.sh` to ensure all prerequisites are satisfied.

To run the application locally, always specify both `--flavor` and `--target`:
```bash
flutter run --flavor development -d macos --target lib/main_development.dart
```

## 4. Quality Assurance & Regression Verification

Before finishing any task, you must verify code cleanliness and run regression tests:
```bash
./scripts/verify.sh
```
If `./scripts/verify.sh` reports static analysis errors (`very_good_analysis`), formatting issues (`dart format`), or failing tests (`test/`), you must fix them before committing or opening a pull request.

## 5. Coding & Style Constraints

- **Strict Analysis**: The project uses `very_good_analysis`. Do not suppress lint rules (`// ignore: ...`) without clear technical justification.
- **State Immutable Updates**: `flutter_bloc` state mutations must use `state.copyWith(...)` with function-based parameter passing (as established in `TimerState` and `SettingsState`).
- **Separation of Concerns**: Keep purely computational helpers (e.g., duration formatting, lap calculation, color math) inside `lib/helpers/` (`DurationHelper`, `LapHelper`, `LapColorHelper`). Do not couple helper logic directly to `BuildContext` or UI components.
- **No Em Dashes**: Do not use the em dash (`\u2014`) in any generated markdown, comments, code strings, commit messages, or documentation. Use hyphens (`-`), colons (`:`), or semicolons instead.
