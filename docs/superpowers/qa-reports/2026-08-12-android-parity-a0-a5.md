# QA Report: Android parity A0–A5

**Date:** 2026-08-12  
**HEAD under test:** `6639af7` (`docs(android): clarify hourly actions open dialog, not instant 1-tap`)  
**Branch:** `main` (ahead of `origin/main` by 11; not pushed)  
**Tester:** agent (qa-only; no product code fixes)  
**Mode:** Device QA **BLOCKED**; static + widget/unit evidence only

## Environment

| Item | Result |
|------|--------|
| Physical Android device | None attached (`adb devices` empty; `flutter devices` = macos, chrome only) |
| AVD / emulator | None (`flutter emulators` empty; `~/.android/avd` missing; `emulator` binary not on PATH) |
| Android SDK | Incomplete: Flutter sees platform-tools at Homebrew cask `android-platform-tools/37.0.0`; **cmdline-tools missing**; licenses unknown; no system images |
| `flutter doctor` Android | Fail (cmdline-tools + licenses) |
| Build/install APK | Not attempted (toolchain insufficient for `flutter build apk`) |

**Blocker (exact):** No Android device or AVD, and no usable Android SDK/emulator toolchain on this machine. Cannot run `flutter run --flavor development -d <android-id>`.

## Automated smoke (host)

```text
flutter pub get && flutter gen-l10n
flutter test --flavor development \
  test/app/view/home_shell_test.dart \
  test/widgets/settings_segments/android_battery_opt_tile_test.dart \
  test/services/android_notification_service_test.dart \
  test/helpers/notification_helper_test.dart \
  test/helpers/hourly_alarm_schedule_test.dart
```

**Result:** `All tests passed!` (34 tests).  
During `home_shell_test` at **390×844**, Flutter logged **RenderFlex overflow** exceptions from `hourly_tracker_view.dart` (lines **210**, **510**, **608**). Test drains exceptions and still passes (A22 evidence below).  
`./scripts/verify.sh` not re-run (no code changes this session).

---

## Checklist results

### 1. A0 Tabs (Focus Timer | Hourly Tracker | Settings)

| Status | **PASS (static + widget)** / **BLOCKED (device)** |
|--------|-----------------------------------------------------|

**Evidence:**
- `lib/app/view/app.dart`: `'/'` → `const HomeShell()` (not lone `TimerPage`).
- `lib/app/view/home_shell.dart`: narrow layout (`width < 800`) uses `NavigationBar` with destinations **Focus Timer**, **Hourly Tracker**, **Settings**.
- `test/app/view/home_shell_test.dart`: asserts three destinations + tap opens `TrackerShellPage` at 390px width. **PASS**.

**Not verified on device:** Fresh install from HEAD vs stale `v1.2.0+1` APK UI. User must uninstall old APK and install build from `6639af7` (or later).

---

### 2. SafeArea / bottom nav not clipped

| Status | **PARTIAL (static)** / **BLOCKED (device)** |
|--------|-----------------------------------------------|

**Evidence:**
- Narrow `HomeShell` sets `bottomNavigationBar: NavigationBar(...)` with **no explicit `SafeArea` wrapper**.
- Material `Scaffold` typically keeps the bar above system insets, but gesture-nav / edge-to-edge clipping was the plan’s device gate (plan task: wrap only if obscured).
- Settings body uses `SafeArea`; shell nav does not.

**Device still required:** Confirm labels/icons not under system gesture bar on API 34/36 gesture navigation.

---

### 3. A2 Battery optimization Settings tile

| Status | **PASS (static + widget)** / **BLOCKED (system dialog)** |
|--------|----------------------------------------------------------|

**Evidence:**
- `SettingsPage` includes `AndroidBatteryOptTile()`; tile returns `SizedBox.shrink()` when not Android.
- Channel methods in `MainActivity.kt`: `isIgnoringBatteryOptimizations`, `requestIgnoreBatteryOptimizations` → `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with `package:` URI.
- Manifest: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- `android_battery_opt_tile_test.dart`: shows “battery” / “Optimized”, tap invokes `requestIgnoreBatteryOptimizations`, status → “Allowed”. **PASS**.

**Device still required:** Real system battery-opt dialog / OEM settings screen.

---

### 4. A4 Hourly notification tap → HourlyLogDialog (incl. cold start)

| Status | **PASS (static + unit)** / **BLOCKED (shade + cold start)** |
|--------|---------------------------------------------------------------|

**Evidence:**
- Payload format `hourly:H:YYYY-MM-DD` via `NotificationHelper` / `AndroidNotificationService.actionFromNotificationTap` → `HourlyLogAction`.
- Cold-start path: `MainActivity` captures `pomo_notification_payload`, Dart `getPendingNotificationPayload` / `actionFromPendingPull` (unit-tested: routes then clears).
- `AppNavigationController`: sets Tracker tab (index 1), delays 250ms, opens `HourlyLogDialog`.
- `d3652e1`: hourly content `PendingIntent` uses request code **13** + unique action/URI so it does not collide with timer FGS intent (request code 0).

**Device still required:** Background tap, locked shade, force-stop then tap, and tap while a work lap FGS is active.

---

### 5. A3 Shade actions: Log / Switch Tag / Open Grid

| Status | **PASS (static + unit)** / **BLOCKED (shade UI)** |
|--------|-----------------------------------------------------|

**Evidence:**
- `TimerForegroundService.postHourlyNotification` actions: **Log 60m Work**, **Switch Tag**, **Open Grid** with suffixes `log_work` / `switch_tag` / `open_grid`.
- Dart routing (`notification_helper_test` / `android_notification_service_test`):
  - `log_work` / `switch_tag` → `HourlyLogAction` (opens dialog; **not** instant Notion write).
  - `open_grid` → `OpenTrackerAction` (Tracker tab only).
- Docs (`6639af7`, ANDROID-IMPROVEMENTS): YAGNI vs DESIGN 1-tap write; true write deferred **A21**.

**Device still required:** Shade buttons on lock screen / notification drawer.

---

### 6. A1 / A19 Exact hourly alarms + BootReceiver

| Status | **PASS (static smoke)** / **BLOCKED (Doze / force-stop / reboot)** |
|--------|--------------------------------------------------------------------|

**Evidence (code/smoke):**
- Manifest permissions: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`.
- Receivers registered: `HourlyAlarmReceiver` (exported=false), `BootReceiver` (exported=true; `BOOT_COMPLETED` + `QUICKBOOT_POWERON`).
- `HourlyAlarmScheduler`: schedules when tracker enabled; `cancel` when off; soft-fail if exact alarm permission revoked (`e90683b`).
- Default tracker pref absent → **false** (safe; BootReceiver will not schedule before Dart sync) (`d3652e1`).
- Dart: `SettingsCubit` / `HookHelper` call `scheduleNextHourlyAlarm` / `cancelHourlyAlarms`; `hourly_alarm_schedule_test` locks next-hour boundary math. **PASS**.

**Device still required:**
- Enable tracker → `adb shell dumpsys alarm` shows pending exact alarm.
- Disable tracker → alarms cancelled.
- Reboot with tracker on → BootReceiver reschedules.
- Force-stop app / Doze: alarm still fires (emulator/physical). **Cannot validate here.**

---

### 7. A5 Timer FGS vs hourly notification IDs/channels

| Status | **PASS (static)** / **BLOCKED (coexistence on device)** |
|--------|---------------------------------------------------------|

**Evidence:**
- Timer: channel `pomo_timer_channel_v2`, ID **1001**, `startForeground`.
- Hourly: channel `hourly_tracker`, ID **1002**, `NotificationManager.notify`.
- `MainActivity.startForeground`: hourly path posts ID 1002 and “never replaces timer FGS”.
- Comments in `TimerForegroundService` document isolation (`9dac060`).

**Device still required:** Start Focus timer (ongoing 1001), trigger hourly path, confirm both tiles remain and timer tap does not open hourly dialog.

---

### 8. Cancel-after-act / check-in UX (`d3652e1`)

| Status | **PASS (static)** / **BLOCKED (device UX)** |
|--------|-----------------------------------------------|

**Evidence:**
- `MainActivity.cancelHourlyNotificationIfNeeded`: on hourly payload (content tap or action), cancels notification ID **1002**.
- Hourly notify: `setAutoCancel(true)`, `setOnlyAlertOnce(true)`.
- Same-hour re-post dedupe via `last_posted_hourly_block` ledger.
- PendingIntent isolation (request code 13) so A4 payload is not wiped while timer FGS runs.

**Device still required:** After tapping Log/Switch/content, shade tile 1002 dismisses; timer 1001 stays if lap running.

---

### 9. A22 Tracker RenderFlex at ~390px

| Status | **FAIL (reproduced in widget test harness)** |
|--------|-----------------------------------------------|

**Evidence:** Running `home_shell_test` at 390×844 produced overflow assertions:

| Site | Overflow |
|------|----------|
| `hourly_tracker_view.dart:210` | ~14px right (prior notes; also seen in suite logs) |
| `hourly_tracker_view.dart:510` | **121px** right |
| `hourly_tracker_view.dart:608` | **18px** right |

Test intentionally drains exceptions (`settleIgnoringChildOverflow`), so CI stays green while phone-width Tracker UI overflows. Tracked as **A22** (P1 UI); not fixed in this QA session (not a P0 QA-runner blocker).

---

### 10. verify.sh / focused tests

| Status | **PASS (focused suite)** / verify.sh **not re-run** |
|--------|-----------------------------------------------------|

Focused Android-related tests: **34/34 PASS**. Full `./scripts/verify.sh` claimed green earlier; skipped here (no code edits).

---

## Summary table

| # | Item | Result |
|---|------|--------|
| 1 | A0 three tabs | PASS (widget/static) / BLOCKED (device install) |
| 2 | SafeArea / nav clip | PARTIAL / BLOCKED (device) |
| 3 | A2 battery tile | PASS (widget/static) / BLOCKED (system UI) |
| 4 | A4 tap → dialog | PASS (unit/static) / BLOCKED (shade/cold start) |
| 5 | A3 shade actions | PASS (unit/static) / BLOCKED (shade) |
| 6 | A1/A19 alarms + boot | PASS (manifest/code) / BLOCKED (Doze/kill/reboot) |
| 7 | A5 dual notification IDs | PASS (static) / BLOCKED (device coexistence) |
| 8 | Cancel-after-act UX | PASS (static) / BLOCKED (device) |
| 9 | A22 RenderFlex ~390px | **FAIL** (reproduced) |
| 10 | Focused tests | **PASS** (34) |

**Overall status:** `DONE_WITH_CONCERNS` - host evidence supports A0–A5 code paths; **device/Doze gate remains open**. Only hard product FAIL observed in this session: **A22** overflow.

---

## What must still be verified on a physical phone

1. Uninstall any `v1.2.0+1` build; install APK/app from HEAD (`6639af7`+).
2. Confirm bottom nav: Focus Timer | Hourly Tracker | Settings; not clipped by gesture nav.
3. Settings → Unrestricted battery → system dialog / OEM battery page.
4. Enable Hourly Tracker; wait for (or trigger) hourly notification; tap body → Tracker + `HourlyLogDialog` (cold start + warm).
5. Shade actions Log / Switch Tag / Open Grid (dialog / grid; no silent Notion write).
6. Start Focus timer + fire hourly path: IDs 1001 and 1002 both visible; cancel-after-act removes only 1002.
7. `adb shell dumpsys alarm` with tracker on/off; reboot reschedule; **force-stop** and **Doze** (Developer options) while tracker enabled.
8. Visually confirm A22 yellow/black stripes on Tracker at phone width (~390dp).

## Prerequisites to unblock device QA on this Mac

1. Install Android Studio or cmdline-tools + accept licenses (`flutter doctor --android-licenses`).
2. Create an AVD (API 34 or 36) **or** connect a physical device with USB debugging.
3. Then: `flutter run --flavor development -d <id> --target lib/main_development.dart`.
