# Android improvements backlog

**Date:** 2026-08-12 (updated after A0-A5 parity plan landed on `main`)  
**Scope:** Full platform scan vs macOS / Web PWA, prioritized for Android parity and reliability.  
**Baseline:** `DESIGN.md` (2026-07-13), `TODOS.md`, `docs/superpowers/DESIGN-GAP-MATRIX.md`, `ARCHITECTURE.md`.

**Status key:** **Shipped (code)** = merged on `main` with unit/widget tests where noted. **Partial: device QA pending** = physical Android verification (API 34/36, Doze, OEM) not yet signed off. Do not claim "verified on device" until QA completes.

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
| Three-tab `HomeShell` | `lib/app/view/home_shell.dart` via `App` routes; Android uses bottom `NavigationBar` when width < 800. Widget test: `test/app/view/home_shell_test.dart`. Tagged `v1.2.0+1` APKs still lack tabs; rebuild from HEAD. |
| Battery-opt Settings tile (A2) | `AndroidBatteryOptTile` in `settings_page.dart`; MethodChannel bridge in `android_notification_service.dart` |
| Hourly notification actions + tap routing (A3/A4) | `TimerForegroundService.postHourlyNotification`: Log / Switch Tag / Open Grid; payload `hourly:H:YYYY-MM-DD` via `NotificationHelper` / `AppNavigationController` (opens dialog / switches tab; not instant one-tap write) |
| Exact hourly alarms + boot reschedule (A1/A19) | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`, `BootReceiver.kt`; manifest `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` / `RECEIVE_BOOT_COMPLETED`; Dart `scheduleNextHourlyAlarm` |
| Separate hourly channel + ID (A20/A5) | `HOURLY_NOTIFICATION_ID = 1002`, channel `hourly_tracker`; timer stays `1001` / `pomo_timer_channel_v2`; hourly is shade-only (no FGS replace) |
| Android background architecture doc (A13) | `ARCHITECTURE.md` section 5 (FGS, alarms, notifications, battery) |
| Release keep rules for native classes | `android/app/proguard-rules.pro` |

**Desktop-only (N/A for Android, not gaps):** floating overlay, macOS menu bar, launch at login, always-on-top, Document PiP (Web). Do not prioritize Android ports of these.

**Web PWA vs Android:** PWA has service-worker notifications + Document PiP (`web/pwa_service_worker.js`, `web_pwa_service_web.dart`). Android uses a native FGS instead. Neither replaces exact alarms when the process is dead.

---

## Shipped (code) - Android parity plan 2026-08-12

| ID | Title | Status | Evidence | Device QA |
|----|-------|--------|----------|-----------|
| A0 | Three-tab shell (Focus / Tracker / Settings) | **Shipped (code)** | `HomeShell` routes in `app.dart`; `NavigationBar` when width < 800; `test/app/view/home_shell_test.dart` locks three destinations | **Pending:** install from HEAD (not `v1.2.0+1`); confirm bottom bar above gesture nav |
| A1 | Exact hourly alarms (Doze / killed) | **Shipped (code)** | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`; manifest permissions; `AndroidNotificationService.scheduleNextHourlyAlarm` | **Pending:** kill app + Doze on API 34/36; OEM battery savers |
| A2 | Battery-optimization Settings UI | **Shipped (code)** | `AndroidBatteryOptTile`; `requestIgnoreBatteryOptimizations` / `isIgnoringBatteryOptimizations` bridge; `android_battery_opt_tile_test.dart` | **Pending:** Settings tap flow on physical device |
| A3 | Hourly notification actions (open dialog) | **Shipped (code)** | `postHourlyNotification` actions: `Log 60m Work`, `Switch Tag`, `Open Grid` in `TimerForegroundService.kt`; payload suffixes in `notification_helper_test.dart`. Opens app prefilled / `HourlyLogDialog` (not DESIGN instant 1-tap write; see A21) | **Pending:** shade actions on locked screen / cold start |
| A4 | Notification tap opens hourly log dialog | **Shipped (code)** | `hourly:H:YYYY-MM-DD` payload; content PendingIntent request code 13 + `pomo://hourly/...` URI; `MainActivity` → `AppNavigationController`; `android_notification_service_test.dart` | **Pending:** cold launch from tap vs warm resume; tap while work lap running |
| A5 | Reliable hourly / tracker FGS strategy | **Shipped (code)** | Separate IDs/channels (1001 timer FGS vs 1002 hourly shade); hourly never `startForeground`; `START_NOT_STICKY` timer policy documented in `ARCHITECTURE.md` | **Pending:** timer + hourly both active; FGS fallback (D5) path |
| A13 | Document Android background architecture | **Shipped (code)** | `ARCHITECTURE.md` section 5 | N/A (docs) |
| A19 | Boot-complete reschedule | **Shipped (code)** | `BootReceiver.kt` → `HourlyAlarmScheduler.scheduleNextHour` | **Pending:** reboot + tracker enabled |
| A20 | Separate notification channels | **Shipped (code)** | Channel `hourly_tracker` (IMPORTANCE_HIGH) vs `pomo_timer_channel_v2` | **Pending:** per-channel silence in system Settings |

---

## Must-fix for Android

_No P0 Android parity items remain open in code. Next work is device QA for the rows above, then Should improve (A6-A10)._

**Host QA (2026-08-12):** `docs/superpowers/qa-reports/2026-08-12-android-parity-a0-a5.md` - no device/AVD on CI Mac; static/unit PASS for A0–A5 paths; **A22** RenderFlex FAIL reproduced at 390px; Doze/force-stop/reboot still open.

---

## Should improve

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A6 | Auto-mark quiet hours as `Resting` | P1 | Product | DESIGN sleep criterion; `MissedTrackingView` skips sleep hours but does not write Resting logs; no auto Resting elsewhere | Missed list omits sleep hours, but analytics/Notion may still lack explicit Resting blocks vs DESIGN. | On quiet-hour boundary (or daily reconcile), write Resting hourly logs (local + optional Notion sync). |
| A7 | Honor `enableQuietHours` in missed-hours scan | P1 | Reliability | `MissedTrackingView._isSleepHour` always applies window; never reads `Prefs.enableQuietHours` | Turning quiet hours off still hides those hours from “missed,” which is wrong. | Gate `_isSleepHour` on `Prefs.enableQuietHours`. |
| A8 | Prompt battery-opt / notification status at bootstrap (Android) | P1 | Android parity | DESIGN success #2: prompt if denied; today only POST_NOTIFICATIONS on `onCreate`; battery opt-in is Settings-only (A2 shipped) | Users who deny once may miss the Settings tile. Soft prompt on first tracker enable reduces silent failure. | After `enableTimeTracker` or first launch on Android, check channel + show rationale dialog linking to Settings. |
| A9 | Background audio for hourly chime | P1 | Reliability | `HookHelper` plays `digital_beep.wav` via `AudioPlayer` in Dart; DESIGN mentions `pop.aac`; no audio focus / short WakeLock around chime | When process is restricted, chime may be silent even if a notification posts. | Play via notification sound / channel attributes, or brief audio focus + WakeLock in the alarm callback. Align asset with DESIGN (`pop.aac`) if desired. |
| A10 | FGS fallback notification lacks actions | P1 | Reliability | `postTimerFallbackNotification` in `TimerForegroundService.kt` (D5 path): ongoing notify, no action buttons | On Android 16 background-start denial, user gets a mute tile without 1-tap actions. | Mirror timer/hourly actions on the fallback builder; document when fallback is expected. |
| A11 | Custom small icon for notifications | P2 | DX | Uses `android.R.drawable.ic_lock_idle_alarm` | System icon looks generic; Play / OEM policies often expect a monochrome app icon. | Add white silhouette drawable and set `setSmallIcon`. |
| A12 | Instrument / integration tests for Android notify path | P1 | DX | Unit tests cover `NotificationHelper`, `AndroidNotificationService`, battery tile, `HomeShell`; **no** on-device integration suite | Regression risk on the highest-value Android surface. | Add MethodChannel fake unit tests + a short device QA checklist (API 34/36) in `docs/superpowers/`. |

---

## Nice-to-have / backlog

| ID | Title | Priority | Category | Evidence | Why it matters | Suggested next step |
|----|-------|----------|----------|----------|----------------|---------------------|
| A14 | Package / launcher rename to Time Tracker | P2 | Product | DESIGN: `com.recoskyler.timetracker`; still `com.recoskyler.pomo`, label `Pomo` | Branding consistency; migration cost if Play listing exists. | Decide keep `pomo` id vs migrate; update `manifestPlaceholders` labels only if rename deferred. |
| A15 | `fl_chart` analytics | P2 | Product | Gap matrix Not started; custom Activity Grid instead | Nice visualization; not Android-specific. | Confirm DESIGN vs custom UI before adding dependency. |
| A16 | `pendingTimeLogs` → sqflite | P2 | Product | `TODOS.md` scalability note | Only if offline queue grows large. | Monitor queue size; migrate when threshold hit. |
| A17 | Unused `permission_handler` cleanup or real use | P2 | DX | In `pubspec.yaml`, no `lib/` imports; A2 uses MethodChannel only | Dead weight unless used for A8. | Use in bootstrap (A8) or remove. |
| A18 | Android deep links / App Links | P2 | Product | Manifest has MAIN/LAUNCHER only; PWA has `/focus` routes | Optional share-to-log / Notion deep links. | Spec only if a concrete mobile deep-link use case appears. |
| A21 | True one-tap hourly log from notification | P1 | Product | DESIGN criterion 1 / persistent ongoing tile; A3 ships dialog-open YAGNI | Shade actions still require app UI to confirm the log. | BroadcastReceiver / direct Prefs write path with undo; optional ongoing hourly tile. |
| A22 | Tracker phone-width RenderFlex overflow | P1 | UI | `HourlyTrackerView` overflows at 390px (`:210`, `:510`, `:608`); HomeShell test drains overflows | Tracker tab broken on typical phone widths; contradicts three-tab parity claim visually. | Reflow / Flexible / scroll the grid and summary rows; add a sized widget test that fails on overflow. |

---

## Platform feature matrix (quick)

| Feature | macOS | Web PWA | Android today | Notes |
|---------|-------|---------|---------------|-------|
| Hourly reminder (in-process) | Yes (`LocalNotificationService`) | Yes (SW notify) | Yes (FGS notify) | All need process or SW alive |
| Hourly when killed / Doze | Soft (menu bar / wake) | Weak (tab/SW limits) | **Shipped (code)**; device QA pending | A1/A19 |
| Quiet hours gating | Yes | Yes (Dart loop) | Yes (Dart + native mirror at alarm fire) | |
| Battery opt request UI | N/A | N/A | **Shipped (code)** Settings tile; device QA pending | A2 |
| Persistent timer notify + actions | Menu bar | Document PiP | Yes (Play/Pause/Stop) | |
| Persistent hourly 1-tap log actions | Tap opens dialog | Tap depends on SW | **Shipped (code)** actions open dialog / switch tab; device QA pending. Instant one-tap write deferred (A21) | A3/A4 |
| Notion / tags / missed hours | Yes | Yes | Yes | Shared Dart |
| Overlay / menu bar / login item | Yes | PiP analog | N/A | Not gaps |

---

## Recommended implementation order

1. **Device QA** for A0-A5 (install from HEAD; API 34/36; Doze; reboot; notification actions)  
2. **A6/A7** (auto-`Resting`, `enableQuietHours` in missed-hours scan)  
3. **A8/A9/A10** (bootstrap prompts, background chime, fallback notification actions)  
4. P2 backlog (A11, A14-A18)

Pair each product change with brainstorming → writing-plans → TDD → `./scripts/verify.sh` per `AGENTS.md`.

**Plan (completed):** `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md`

---

## Related docs

- `DESIGN.md` success criteria 2–3 (battery + exact hourly + quiet hours)  
- `TODOS.md` (battery row may still need closing after device QA)
- `docs/superpowers/DESIGN-GAP-MATRIX.md` (synced Android rows)  
- Native: `android/app/src/main/kotlin/com/recoskyler/MainActivity.kt`, `.../TimerForegroundService.kt`  
- Dart: `lib/services/android_notification_service.dart`, `lib/helpers/hook_helper.dart`
