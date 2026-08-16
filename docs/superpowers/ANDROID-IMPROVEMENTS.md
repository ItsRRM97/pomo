# Android improvements backlog

**Date:** 2026-08-17 (Must/Should A22, A6-A10, A12, A21 shipped in code)  
**Scope:** Full platform scan vs macOS / Web PWA, prioritized for Android parity and reliability.  
**Baseline:** `DESIGN.md` (2026-07-13), `TODOS.md`, `docs/superpowers/DESIGN-GAP-MATRIX.md`, `ARCHITECTURE.md`.

**Status key:** **Shipped (code)** = on this branch / `main` with unit/widget tests where noted. **Residual device QA** = overnight Doze, reboot, force-stop, or OEM battery savers not signed off. Do not claim those gates from host tests.

---

## What Android already has (working baseline)

| Area | Evidence |
|------|----------|
| API 36 target + flavors | `android/app/build.gradle` (`compileSdk`/`targetSdk` 36; production/staging/development) |
| Foreground service (timer) | `TimerForegroundService.kt`, manifest `FOREGROUND_SERVICE` + `SPECIAL_USE` |
| D5 FGS start crash guard | `startForegroundService` try/catch → fallback `NotificationManager.notify` with Play/Pause/Stop (A10) |
| Ongoing timer notification + Play/Pause/Stop | `TimerForegroundService.buildNotification` (timer mode); Dart bridge in `android_notification_service.dart` |
| POST_NOTIFICATIONS prompt | `MainActivity.checkAndRequestNotificationPermission`; tracker soft prompt (A8) |
| Battery-opt **native** channel + Settings tile | `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations`; `AndroidBatteryOptTile` (A2) |
| Hourly reminder when Dart loop is alive | `HookHelper.startHourlyTrackerLoop` → `AndroidNotificationService.showHourlyReminderNotification` |
| Quiet hours suppress hourly beep/notify | `HookHelper._checkAndTriggerHourlyReminder` + `SoundHelper.isQuietHours`; native mirror at alarm fire |
| Auto-`Resting` quiet-hour logs (A6) | `QuietHoursHelper` + `HourlyLogWriter.reconcileResting` |
| Tracker UI (grid + missed hours) | `lib/pages/tracker/`; 390 dp reflow (A22) |
| Notion sync + activity tags + pending queues | `NotionSyncService`, `Prefs.pendingTimeLogs` / hourly pending |
| Pomodoro tick while process alive | `DesktopShell` starts `TimerTickService` on IO (including Android) |
| Three-tab `HomeShell` | `lib/app/view/home_shell.dart` via `App` routes; Android uses bottom `NavigationBar` when width < 800. Widget test: `test/app/view/home_shell_test.dart`. Tagged `v1.2.0+1` APKs still lack tabs; rebuild from HEAD. |
| Hourly notification actions + tap routing (A3/A4/A21) | `Log 60m Work` instant write; `Switch Tag` dialog; `Open Grid` tab switch; native queue when Dart is dead |
| Exact hourly alarms + boot reschedule (A1/A19) | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`, `BootReceiver.kt`; Dart `scheduleNextHourlyAlarm` |
| Separate hourly channel + ID (A20/A5/A9) | `HOURLY_NOTIFICATION_ID = 1002`, channel `hourly_tracker_v2` (sound `digital_beep`); timer stays `1001` / `pomo_timer_channel_v2` |
| Android background architecture doc (A13) | `ARCHITECTURE.md` section 5 (FGS, alarms, notifications, battery) |
| Dart/native MethodChannel host contract (A12) | `test/services/android_native_contract_test.dart` |
| Release keep rules for native classes | `android/app/proguard-rules.pro` |

**Desktop-only (N/A for Android, not gaps):** floating overlay, macOS menu bar, launch at login, always-on-top, Document PiP (Web). Do not prioritize Android ports of these.

**Web PWA vs Android:** PWA has service-worker notifications + Document PiP (`web/pwa_service_worker.js`, `web_pwa_service_web.dart`). Android uses a native FGS instead. Neither replaces exact alarms when the process is dead.

---

## Shipped (code) - Android parity 2026-08-12 + Must/Should 2026-08-17

| ID | Title | Status | Evidence | Device QA |
|----|-------|--------|----------|-----------|
| A0 | Three-tab shell (Focus / Tracker / Settings) | **Shipped (code)** | `HomeShell` routes in `app.dart`; `NavigationBar` when width < 800; `test/app/view/home_shell_test.dart` | Interactive tabs confirmed 2026-08-17 device report; rebuild from HEAD (not `v1.2.0+1`) |
| A1 | Exact hourly alarms (Doze / killed) | **Shipped (code)** | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`; manifest permissions; `AndroidNotificationService.scheduleNextHourlyAlarm` | **Residual:** overnight Doze, force-stop, OEM battery savers |
| A2 | Battery-optimization Settings UI | **Shipped (code)** | `AndroidBatteryOptTile`; MethodChannel bridge; `android_battery_opt_tile_test.dart` | Settings tap flow exercised on device 2026-08-17 |
| A3 | Hourly notification actions | **Shipped (code)** | `Log 60m Work` / `Switch Tag` / `Open Grid` in `TimerForegroundService.kt` | Shade actions on locked screen still residual |
| A4 | Notification tap opens hourly log dialog | **Shipped (code)** | `hourly:H:YYYY-MM-DD` payload; `MainActivity` → `AppNavigationController` | Cold launch vs warm resume residual |
| A5 | Reliable hourly / tracker FGS strategy | **Shipped (code)** | IDs/channels 1001 vs 1002; hourly never `startForeground` | Dual-tile coexistence confirmed on device 2026-08-17 |
| A6 | Auto-mark quiet hours as `Resting` | **Shipped (code)** | `QuietHoursHelper.missingRestingLogs` + `HourlyLogWriter.reconcileResting`; `tag_sleep` / Sleep & Rest | Overnight reconcile residual |
| A7 | Honor `enableQuietHours` in missed-hours scan | **Shipped (code)** | `QuietHoursHelper.isQuietHourIndex` gated on `Prefs.enableQuietHours` | N/A (Dart) |
| A8 | Prompt battery-opt / notification status | **Shipped (code)** | `AndroidBackgroundPrompt` + `AndroidTrackerStatusPrompt` on tracker enable / Tracker shell | Host tests are not Android; dialog on-device residual |
| A9 | Background audio for hourly chime | **Shipped (code)** | Channel `hourly_tracker_v2` + `R.raw.digital_beep`; `HourlyAlarmReceiver` WakeLock + audio focus | Chime under OEM restriction residual |
| A10 | FGS fallback notification actions | **Shipped (code)** | `postTimerFallbackNotification` mirrors Play/Pause/Stop; `android_fgs_fallback_contract_test.dart` | D5 path on Android 16 residual |
| A12 | Host tests of Dart/native notify contract | **Shipped (code)** | `android_native_contract_test.dart` locks channel, methods, 1001/1002, arg keys | On-device instrumentation still Nice (not in this plan) |
| A13 | Document Android background architecture | **Shipped (code)** | `ARCHITECTURE.md` section 5 | N/A (docs) |
| A19 | Boot-complete reschedule | **Shipped (code)** | `BootReceiver.kt` → `HourlyAlarmScheduler.scheduleNextHour` | **Residual:** reboot + tracker enabled |
| A20 | Separate notification channels | **Shipped (code)** | Channel `hourly_tracker_v2` (IMPORTANCE_HIGH, `digital_beep`) vs `pomo_timer_channel_v2` | Per-channel silence in system Settings residual |
| A21 | True one-tap hourly Work log from shade | **Shipped (code)** | `HourlyInstantWriteAction` + `HourlyLogActionReceiver`; snackbar undo when UI is up | Cold-start queue when Dart is dead residual |
| A22 | Tracker phone-width RenderFlex overflow | **Shipped (code)** | `HourlyTrackerView` / `MissedTrackingView` reflow at 390 dp; `hourly_tracker_view_overflow_test.dart` | Visual check on ≤390 dp residual |

---

## Must-fix for Android

_No P0 Android parity items remain open in code._

**Residual device QA (do not fake):** A1/A19 overnight Doze, reboot, and force-stop. A9 chime under OEM restriction. A8 dialog on a real Android process.

**Host QA (2026-08-12):** `docs/superpowers/qa-reports/2026-08-12-android-parity-a0-a5.md`  
**Device QA (2026-08-17):** `docs/superpowers/qa-reports/2026-08-17-android-parity-device.md` (interactive A0-A5 passed; overnight gates open)

---

## Should improve

_P1 Should items A6-A10, A12, A21, A22 are shipped (code). See table above._

---

## Nice-to-have / backlog

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A11 | Custom small icon for notifications | P2 | DX | Uses `android.R.drawable.ic_lock_idle_alarm` | System icon looks generic; Play / OEM policies often expect a monochrome app icon. | Add white silhouette drawable and set `setSmallIcon`. |
| A14 | Package / launcher rename to Time Tracker | P2 | Product | DESIGN: `com.recoskyler.timetracker`; still `com.recoskyler.pomo`, label `Pomo` | Branding consistency; migration cost if Play listing exists. | Decide keep `pomo` id vs migrate; update `manifestPlaceholders` labels only if rename deferred. |
| A15 | `fl_chart` analytics | P2 | Product | Gap matrix Not started; custom Activity Grid instead | Nice visualization; not Android-specific. | Confirm DESIGN vs custom UI before adding dependency. |
| A16 | `pendingTimeLogs` → sqflite | P2 | Product | `TODOS.md` scalability note | Only if offline queue grows large. | Monitor queue size; migrate when threshold hit. |
| A17 | Unused `permission_handler` cleanup or real use | P2 | DX | In `pubspec.yaml`, no `lib/` imports; A2/A8 use MethodChannel | Dead weight. | Remove or use for POST_NOTIFICATIONS. |
| A18 | Android deep links / App Links | P2 | Product | Manifest has MAIN/LAUNCHER only; PWA has `/focus` routes | Optional share-to-log / Notion deep links. | Spec only if a concrete mobile deep-link use case appears. |

---

## Platform feature matrix (quick)

| Feature | macOS | Web PWA | Android today | Notes |
|---------|-------|---------|---------------|-------|
| Hourly reminder (in-process) | Yes (`LocalNotificationService`) | Yes (SW notify) | Yes (FGS notify) | All need process or SW alive |
| Hourly when killed / Doze | Soft (menu bar / wake) | Weak (tab/SW limits) | **Shipped (code)**; overnight device QA residual | A1/A19 |
| Quiet hours gating + Resting logs | Yes | Yes (Dart loop) | Yes (Dart + native + A6/A7) | |
| Battery opt request UI | N/A | N/A | **Shipped (code)** Settings tile + A8 prompt | A2/A8 |
| Persistent timer notify + actions | Menu bar | Document PiP | Yes (Play/Pause/Stop, including D5 fallback) | A10 |
| Persistent hourly 1-tap log actions | Tap opens dialog | Tap depends on SW | **Shipped (code)** `Log 60m Work` writes; Switch Tag still dialog | A3/A4/A21 |
| Notion / tags / missed hours | Yes | Yes | Yes | Shared Dart |
| Overlay / menu bar / login item | Yes | PiP analog | N/A | Not gaps |

---

## Recommended implementation order

1. **Residual device QA** for A1/A19 (overnight Doze, reboot, force-stop). Do not close from host tests.  
2. P2 backlog (A11, A14-A18) if needed.

Pair each product change with brainstorming → writing-plans → TDD → `./scripts/verify.sh` per `AGENTS.md`.

**Plans:** `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md` (A0-A5) · `docs/superpowers/plans/2026-08-17-android-must-should.md` (A22, A6-A10, A12, A21)

---

## Related docs

- `DESIGN.md` success criteria 2–3 (battery + exact hourly + quiet hours)  
- `TODOS.md` (`pendingTimeLogs` → sqflite only; A2 Settings tile is shipped)  
- `docs/superpowers/DESIGN-GAP-MATRIX.md` (synced Android rows)  
- Native: `android/app/src/main/kotlin/com/recoskyler/MainActivity.kt`, `.../TimerForegroundService.kt`  
- Dart: `lib/services/android_notification_service.dart`, `lib/helpers/hook_helper.dart`
