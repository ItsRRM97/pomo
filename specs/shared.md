# Shared models, Prefs, and constraints

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/singletons/`, `lib/helpers/`, `lib/models/`

Used by every feature that persists state or computes timer / hourly math.

---

## Hard constraints (always)

1. `--flavor` + `--target`; never run `lib/main.dart` as the real app.
2. `flutter pub get` + `flutter gen-l10n` (or `./scripts/setup.sh`) before analyze / test / build.
3. Helpers in `lib/helpers/` stay free of `BuildContext`.
4. Cubit states are immutable (`copyWith`).
5. No em dash (`U+2014`) in docs, comments, commits, or UI strings.
6. Do not invent remotes, force-push, or commit unless the user asks.
7. Secrets: never commit `.env` / `.env.*`. Template is tracked `sample.env` (not `.env.example`).

## Persistence

All durable client state is **`Prefs`** wrapping `SharedPreferences` (`lib/singletons/prefs.dart`). There is no sqflite.

Notable keys (prefix `pomo_`):

| Area | Keys / getters |
|------|----------------|
| Timer | duration, status, lap, lapNumber, activeTask JSON, activeLogPageId, syncedMinutes, session external id |
| Settings | durations, theme, fonts, webhooks, sounds, Notion IDs, time tracker, quiet hours, desktop notifications, launch at login, window size |
| Hourly | `trackerTags`, `hourlyLogs`, `pendingHourlyLogs` |
| Task sessions offline | `pendingTimeLogs` |

Empty tag list falls back to `TrackerTag.defaults`.

Hour slot replace: `Prefs.replaceHourlyLogsForHour(dateStr, hour, logs)` (does not append beside a full slot rewrite).

## Models

### `TrackerTag` (`lib/models/tracker_tag.dart`)

`id`, `name`, `icon` (emoji), `colorHex`, `isDefault`.

Built-in IDs: `tag_coding`, `tag_meetings`, `tag_deep_work`, `tag_reading`, `tag_workout`, `tag_admin`, `tag_sleep`.

Custom IDs: `tag_custom_<epoch>_<slug>`.

### `HourlyLog` (`lib/models/hourly_log.dart`)

One row per **tag per hour**: `id` = `hlog_<dateStr>_<hour>_<tagId>` (`QuietHoursHelper.logId`).

Fields: dateStr, hour (0-23), denormalized tag fields, optional `projectId` / `projectTitle` (comma-joined multi-project), notes, `durationMinutes` (default 60), `notionPageId`, `loggedAt`.

A single hour can have multiple logs whose minutes **sum to 60** when saved from `HourlyLogDialog` (equal split). Totals over 60 are possible if other writers upsert without rebalancing (not used by the dialog).

### `NotionTask` (`lib/models/notion_task.dart`)

PARA task / project / area page: id, title, status, priority/type, due, project link, cumulative `timeHours` / `timeMinutes`, archived.

Parsed from Notion API pages (`fromNotionApi`).

## Helpers (pure)

| Helper | Role |
|--------|------|
| `DurationHelper` | MM:SS, progress, lap complete |
| `LapHelper` | next lap from lapNumber + lapCount |
| `LapColorHelper` | lap → color / webhook RGB |
| `SoundHelper` | preset vs custom paths; quiet hours for **hourly** chime only |
| `HookHelper` | webhooks + hourly reminder loop (when app is warm) |
| `HourlyLogWriter` | build/persist hourly rows; Resting reconcile |
| `QuietHoursHelper` | window check, Resting logs, log ids |
| `NotificationHelper` | copy, quiet hours, payload parse (`hourly:H:YYYY-MM-DD[:action]`) |
| `HourlyAlarmSchedule` | Dart-side alarm window math |
| `NotionUrlHelper` | open Notion DBs in browser |
| `SessionHelper` / `TimerHelper` | session/display helpers |

## Gates (cross-feature)

| Flag | Effect |
|------|--------|
| `Prefs.enableTimeTracker` | Notion **task** session create/update; hourly alarms / Resting fill |
| `Prefs.enableNotionSync` | HTTP to Notion (needs API key + relevant database IDs) |
| `Prefs.enableQuietHours` | Suppress hourly beep; auto Resting on empty quiet slots |
| `Prefs.enableSound` | Timer action sounds; hourly chime also respects quiet hours |
| `Prefs.enableWebHooks` | `HookHelper` HTTP |
| `Prefs.enableDesktopNotifications` | macOS lap + hourly banners |

Timer sounds are **not** gated by quiet hours (direct user feedback). Hourly reminders are.

## Two tracking lanes (do not conflate)

| Lane | User object | Local model | Notion DB |
|------|-------------|-------------|-----------|
| Pomodoro session | `NotionTask` | TimerCubit + Time Logs page id | Time Logs |
| Hourly block | `TrackerTag` | `HourlyLog` | Hourly Timeline |

They share toggles and credentials. The Focus timer can **add minutes** to hourly tag rows when tags are selected (see [timer.md](timer.md)). Task Time Logs rows stay separate.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shared spec |
