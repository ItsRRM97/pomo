# Android improvements backlog

**Date:** 2026-08-12  
**Scope:** Full platform scan vs macOS / Web PWA, prioritized for Android parity and reliability.  
**Baseline:** `DESIGN.md` (2026-07-13), `TODOS.md`, `docs/superpowers/DESIGN-GAP-MATRIX.md`, `ARCHITECTURE.md`.

This is a planning deliverable only. No product code was changed in this pass.

---

## What Android already has (working baseline)

| Area | Evidence |
|------|----------|
| API 36 target + flavors | `android/app/build.gradle` (`compileSdk`/`targetSdk` 36; production/staging/development) |
| Foreground service (timer) | `TimerForegroundService.kt`, manifest `FOREGROUND_SERVICE` + `SPECIAL_USE` |
| D5 FGS start crash guard | `startForegroundService` try/catch → fallback `NotificationManager.notify` |
| Ongoing timer notification + Play/Pause/Stop | `TimerForegroundService.buildNotification` (timer mode); Dart bridge in `android_notification_service.dart` |
| POST_NOTIFICATIONS prompt | `MainActivity.checkAndRequestNotificationPermission` |
| Battery-opt **native** channel | `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations` in `MainActivity.kt` |
| Hourly reminder when Dart loop is alive | `HookHelper.startHourlyTrackerLoop` → `AndroidNotificationService.showHourlyReminderNotification` |
| Quiet hours suppress hourly beep/notify | `HookHelper._checkAndTriggerHourlyReminder` + `SoundHelper.isQuietHours` |
| Tracker UI (grid + missed hours) | `lib/pages/tracker/` |
| Notion sync + activity tags + pending queues | `NotionSyncService`, `Prefs.pendingTimeLogs` / hourly pending |
| Pomodoro tick while process alive | `DesktopShell` starts `TimerTickService` on IO (including Android) |
| Three-tab `HomeShell` (HEAD) | `lib/app/view/home_shell.dart` via `App` routes; Android uses bottom `NavigationBar` when width < 800. Tagged `v1.2.0+1` lacks this (see A0). |
| Release keep rules for native classes | `android/app/proguard-rules.pro` |

**Desktop-only (N/A for Android, not gaps):** floating overlay, macOS menu bar, launch at login, always-on-top, Document PiP (Web). Do not prioritize Android ports of these.

**Web PWA vs Android:** PWA has service-worker notifications + Document PiP (`web/pwa_service_worker.js`, `web_pwa_service_web.dart`). Android uses a native FGS instead. Neither replaces exact alarms when the process is dead.

---

## Must-fix for Android

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A0 | Three-tab shell on Android (Focus Timer / Hourly Tracker / Settings) | **P0** | Android parity / ship gate | **HEAD source already has tabs:** `lib/app/view/home_shell.dart` + `App` routes `/` → `HomeShell` for all platforms (`lib/app/view/app.dart`). `DesktopShell` on Android is a passthrough (`!Platform.isMacOS`). Narrow screens use `NavigationBar` (`width < 800`). **No** `Platform.isAndroid` / `kIsWeb` branch skips the shell. **Tagged release gap:** latest tag `v1.2.0+1` still routes `/` → `TimerPage` only (no `HomeShell`, no Tracker). User report of missing tabs matches an **old APK / pre-HomeShell build**, not a current-main platform skip. **No** widget test locks `HomeShell` destinations. | Without the three tabs, Android is not the Time Tracker product (DESIGN nav shell). Background work (A1–A5) is pointless if users cannot reach Hourly Tracker / Settings. Ship gate before other Android work. | (1) Add widget test: narrow viewport shows three `NavigationDestination` labels and switches pages. (2) Rebuild/install from **current main** (not `v1.2.0`). (3) Device QA: confirm bottom bar visible above system gesture nav; fix SafeArea/insets only if obscured. (4) Do not re-implement `HomeShell` unless QA proves HEAD is broken. |
| A1 | Exact hourly alarms when app is killed / Dozing | P0 | Android parity | `HookHelper.startHourlyTrackerLoop` (Dart `Timer.periodic` only); **no** `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` in `AndroidManifest.xml`; **no** `android_alarm_manager_plus` / AlarmManager; DESIGN success criterion #3 | Hourly check-ins are the core Time Tracker promise. A 1-minute Dart timer dies with the process; Doze will skip reminders unless the user keeps the app warm. | Spec + implement AlarmManager / `android_alarm_manager_plus` (or equivalent) with quiet-hours check in the native/callback path; add manifest permissions and OEM QA on API 36. |
| A2 | Wire battery-optimization Settings UI | P0 | Android parity | `TODOS.md`; `MainActivity.kt` channel exists; **no** Dart callers of `requestIgnoreBatteryOptimizations`; Settings has no Android tile (`settings_page.dart`); `permission_handler` in `pubspec.yaml` but unused in `lib/` | Without ignore-battery-optimizations, exact alarms and background work are unreliable on Android 16. Native half is done; users cannot opt in. | Add Android-only Settings switch/button that calls the existing MethodChannel (and/or `permission_handler`); surface current ignoring state. |
| A3 | Hourly notification 1-tap actions (DESIGN actions) | P0 | Android parity | `TimerForegroundService.buildNotification`: hourly branch sets category only; **no** actions. DESIGN wants `[ Log 60m Work ]`, `[ Switch Tag ]`, `[ Open Grid ]`. Gap matrix: Partial. | Shade 1-tap logging is the Android UX differentiator vs unlocking and navigating. Timer mode already has Play/Pause/Stop; hourly does not. | Extend FGS + channel with Log / Switch Tag / Open Grid; route via `AppNavigationController` / `HourlyLogDialog` with hour+date extras. |
| A4 | Notification tap → open hourly log dialog | P0 | Android parity | Android `openAppPendingIntent` → `MainActivity` only (no payload). macOS path: `LocalNotificationService` → `NotificationHelper.parsePayload` → `AppNavigationController.handleNotificationAction`. | Tapping the hourly reminder should land on the log dialog (parity with macOS), not a cold launch to the last tab. | Pass `hourly:H:YYYY-MM-DD` (or Intent extras) into launch Intent; on resume, call `AppNavigationController`. |
| A5 | Persist a reliable hourly / tracker FGS strategy | P1 | Reliability | Same `NOTIFICATION_ID` (1001) for timer and hourly; hourly `startForeground` can replace timer UI; FGS returns `START_NOT_STICKY`; hourly FGS only starts **after** Dart fires (chicken-and-egg when process is dead) | Shared ID causes UX collision; sticky policy and lifecycle do not match "always ready for top-of-hour." | Separate notification IDs/channels; decide sticky policy; keep a thin tracker FGS or use exact alarms + high-importance notification without relying on Dart being alive. |

---

## Should improve

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A6 | Auto-mark quiet hours as `Resting` | P1 | Product | DESIGN sleep criterion; `MissedTrackingView` skips sleep hours but does not write Resting logs; no auto Resting elsewhere | Missed list omits sleep hours, but analytics/Notion may still lack explicit Resting blocks vs DESIGN. | On quiet-hour boundary (or daily reconcile), write Resting hourly logs (local + optional Notion sync). |
| A7 | Honor `enableQuietHours` in missed-hours scan | P1 | Reliability | `MissedTrackingView._isSleepHour` always applies window; never reads `Prefs.enableQuietHours` | Turning quiet hours off still hides those hours from “missed,” which is wrong. | Gate `_isSleepHour` on `Prefs.enableQuietHours`. |
| A8 | Prompt battery-opt / notification status at bootstrap (Android) | P1 | Android parity | DESIGN success #2: prompt if denied; today only POST_NOTIFICATIONS on `onCreate`; battery request never called from Dart | Users who deny once have no path except Settings (once A2 ships). Soft prompt on first tracker enable reduces silent failure. | After `enableTimeTracker` or first launch on Android, check channel + show rationale dialog. |
| A9 | Background audio for hourly chime | P1 | Reliability | `HookHelper` plays `digital_beep.wav` via `AudioPlayer` in Dart; DESIGN mentions `pop.aac`; no audio focus / short WakeLock around chime | When process is restricted, chime may be silent even if a notification posts. | Play via notification sound / channel attributes, or brief audio focus + WakeLock in the alarm callback. Align asset with DESIGN (`pop.aac`) if desired. |
| A10 | FGS fallback notification lacks actions | P1 | Reliability | `postFallbackNotification` in `TimerForegroundService.kt` (D5 path): ongoing notify, no action buttons | On Android 16 background-start denial, user gets a mute tile without 1-tap actions. | Mirror timer/hourly actions on the fallback builder; document when fallback is expected. |
| A11 | Custom small icon for notifications | P2 | DX | Uses `android.R.drawable.ic_lock_idle_alarm` | System icon looks generic; Play / OEM policies often expect a monochrome app icon. | Add white silhouette drawable and set `setSmallIcon`. |
| A12 | Instrument / integration tests for Android notify path | P1 | DX | Unit tests cover `NotificationHelper` payloads; **no** tests for `AndroidNotificationService` or Kotlin FGS actions | Regression risk on the highest-value Android surface. | Add MethodChannel fake unit tests + a short device QA checklist (API 34/36) in `docs/superpowers/`. |
| A13 | Document Android background architecture in ARCHITECTURE.md | P2 | DX | ARCHITECTURE covers macOS notifications/shell; almost no Android FGS/Doze section | Agents and future plans miss the real Android constraints. | Add section: FGS, MethodChannel, hourly loop limits, battery channel, planned exact alarms. |

---

## Nice-to-have / backlog

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A14 | Package / launcher rename to Time Tracker | P2 | Product | DESIGN: `com.recoskyler.timetracker`; still `com.recoskyler.pomo`, label `Pomo` | Branding consistency; migration cost if Play listing exists. | Decide keep `pomo` id vs migrate; update `manifestPlaceholders` labels only if rename deferred. |
| A15 | `fl_chart` analytics | P2 | Product | Gap matrix Not started; custom Activity Grid instead | Nice visualization; not Android-specific. | Confirm DESIGN vs custom UI before adding dependency. |
| A16 | `pendingTimeLogs` → sqflite | P2 | Product | `TODOS.md` scalability note | Only if offline queue grows large. | Monitor queue size; migrate when threshold hit. |
| A17 | Unused `permission_handler` cleanup or real use | P2 | DX | In `pubspec.yaml`, no `lib/` imports | Dead weight unless used for A2/A8. | Use it in Settings/bootstrap or remove after A2 lands with MethodChannel-only. |
| A18 | Android deep links / App Links | P2 | Product | Manifest has MAIN/LAUNCHER only; PWA has `/focus` routes | Optional share-to-log / Notion deep links. | Spec only if a concrete mobile deep-link use case appears. |
| A19 | Boot-complete reschedule | P2 | Reliability | No `BOOT_COMPLETED` receiver | Exact alarms (A1) need reschedule after reboot. | Implement with A1. |
| A20 | Separate notification channels (timer vs hourly) | P2 | Reliability | Single channel `pomo_timer_channel_v2` titled “Focus Timer” | Users cannot silence hourly independently of timer progress. | Create `hourly_tracker` channel with IMPORTANCE_HIGH + sound. |

---

## Platform feature matrix (quick)

| Feature | macOS | Web PWA | Android today | Notes |
|---------|-------|---------|---------------|-------|
| Hourly reminder (in-process) | Yes (`LocalNotificationService`) | Yes (SW notify) | Yes (FGS notify) | All need process or SW alive |
| Hourly when killed / Doze | Soft (menu bar / wake) | Weak (tab/SW limits) | **No** | A1 |
| Quiet hours gating | Yes | Yes (Dart loop) | Yes (Dart loop) | |
| Battery opt request UI | N/A | N/A | Native only, **no Settings** | A2 |
| Persistent timer notify + actions | Menu bar | Document PiP | Yes (Play/Pause/Stop) | |
| Persistent hourly 1-tap log actions | Tap opens dialog | Tap depends on SW | **Notify only, no actions** | A3/A4 |
| Notion / tags / missed hours | Yes | Yes | Yes | Shared Dart |
| Overlay / menu bar / login item | Yes | PiP analog | N/A | Not gaps |

---

## Recommended implementation order

1. **A0** (three-tab shell verify + regression test + install from HEAD; ship gate)  
2. **A2** (small, unblocks user trust) + **A4** (tap routing)  
3. **A3** (hourly actions)  
4. **A1** + **A19** + **A5** (exact alarms + lifecycle; largest reliability win)  
5. **A6/A7**, **A8/A9/A10**, then P2 backlog  

Pair each product change with brainstorming → writing-plans → TDD → `./scripts/verify.sh` per `AGENTS.md`.

**Plan:** `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md`

---

## Related docs

- `DESIGN.md` success criteria 2–3 (battery + exact hourly + quiet hours)  
- `TODOS.md` battery Settings row  
- `docs/superpowers/DESIGN-GAP-MATRIX.md` (synced Android rows)  
- Native: `android/app/src/main/kotlin/com/recoskyler/MainActivity.kt`, `.../TimerForegroundService.kt`  
- Dart: `lib/services/android_notification_service.dart`, `lib/helpers/hook_helper.dart`
