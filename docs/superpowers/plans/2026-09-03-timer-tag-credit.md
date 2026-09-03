# Timer tag credit Implementation Plan

> **For Claude:** Implement task-by-task with TDD. Do not commit unless the user asks.

**Goal:** Credit Pomodoro work minutes to selected hourly activity tags (Approach A), on macOS, Android, and PWA; deploy the PWA first.

**Architecture:** Pure helpers (`TrackerTagHelper`, `TimerTagCreditHelper`) plus `HourlyLogWriter.creditTimerMinutes`. `TimerCubit` holds selected tags and credits deltas on pause / lap / reset / task change. Shared Flutter UI on `TimerPage` so all three clients get the same picker. Overlay stays display-only.

**Tech Stack:** Flutter, `flutter_bloc`, Prefs, existing Notion hourly sync.

---

### Task 1: Helpers + tests (duplicate names, equal split, hour slice, additive merge)

### Task 2: Prefs last tag IDs + HourlyLogWriter persist path

### Task 3: TimerCubit credit hooks (work-only, delta, preserve tags on reset)

### Task 4: Tag create duplicate check; delete custom-only

### Task 5: Timer tag bar UI + hourly overfill hint + l10n

### Task 6: `./scripts/verify.sh`; promote specs; PWA build + production deploy

**Policy recap:** equal split; additive merge; wall-clock hour boundary; totals may exceed 60m; no credit without tags; Resting notes=`Resting` stripped on user credit.
