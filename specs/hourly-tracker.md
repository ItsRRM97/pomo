# Hourly tracker and activity tags

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/pages/tracker/`

---

## Purpose

Tab 1 logs **clock hours** against **activity tags** (and optional PARA projects), then charts the day/week/month. The Focus timer can **add** Pomodoro minutes into the same rows (see [timer.md](timer.md)).

## Shell (`TrackerShellPage`)

Inner tabs:

1. **Activity Grid & Analytics** (`HourlyTrackerView`)
2. **Missed Hours Check** (`MissedTrackingView`)

App bar can open the Notion Hourly Timeline database in the browser when sync is on. Android may show `AndroidTrackerStatusPrompt` (battery / alarm status).

## Tags

Stored in `Prefs.trackerTags`. Create: `TagCreateDialog` (name, emoji, color). Duplicate names (trim + case-insensitive) are blocked, with **Use existing**. Save: `NotionSyncService.saveActivityTag`.

Delete: custom tags only (close on chip or long-press on timer). Historical `HourlyLog` rows keep denormalized name/icon/color.

## Logging an hour (`HourlyLogDialog`)

- Pick one or more tags (toggle chips).
- Optional multi-select PARA projects/areas.
- Notes; optional hour **range** (bulk fill).
- Empty tags + empty notes **clears** the slot (archives Notion rows).
- Multiple tags: **equal split of 60 minutes**; first tag gets the remainder (`60 ~/ k`, first gets leftover).

Persist: `NotionSyncService.replaceHourlyLogsForHour` (local replace + Notion).

One-tap from Android notification **Log 60m Work** uses `HourlyLogWriter.build` with the default Work-style tag path (Deep Work / first configured behavior in navigation tests: `tag_deep_work`) for that hour.

## Grid and analytics (`HourlyTrackerView`)

- 24 rows for the selected date.
- Tapping a row opens the dialog for that hour.
- Aggregates minutes per tag for day / week / month (sums `durationMinutes`; custom charts, not `fl_chart`).

## Missed hours (`MissedTrackingView`)

Hours with no user log (outside auto-Resting) listed for catch-up.

## Quiet hours / Resting

If `enableQuietHours`, `HourlyLogWriter.reconcileResting` fills **empty** quiet-hour slots with Sleep & Rest (`tag_sleep`, notes `Resting`). User logs in a slot win; Resting is not written beside them. Resting-first merge after a remote Work pull keeps Work.

Hourly **chimes** are suppressed in the quiet window (`NotificationHelper` / native fire-time gate).

## Reminders

- Warm app: `HookHelper` hourly loop.
- Android killed/Doze: native exact alarms ([android.md](android.md)).
- macOS: `LocalNotificationService` when desktop notifications are on.

Actions: Log 60m Work (instant write), Switch Tag (opens dialog), Open Grid (tab 1).

## Platforms

Dart UI is shared on **macOS, Android, web**. Alarm reliability is Android-native; web/macOS depend on a running process or desktop notification permission.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped hourly tracker spec |
