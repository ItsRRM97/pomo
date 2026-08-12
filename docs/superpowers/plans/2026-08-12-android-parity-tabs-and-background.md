# Android parity (tabs + background) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee Android shows the same three-tab shell as macOS (Focus Timer | Hourly Tracker | Settings), then close the Android-only DESIGN gaps for battery opt-in, hourly notification tap/actions, and exact hourly alarms under Doze.

**Architecture:** Keep the shared Dart `HomeShell` as the single nav shell for all non-overlay entry points. Extend the existing Android MethodChannel (`com.recoskyler.pomo/timer_notification`) and `TimerForegroundService` for tap payloads and hourly actions. Add exact alarms via AlarmManager (or `android_alarm_manager_plus`) with quiet-hours gating reused from `NotificationHelper` / `SoundHelper`, and surface battery-optimization opt-in as an Android-only Settings segment that calls the already-shipped `MainActivity` channel methods.

**Tech Stack:** Flutter (flavors + `lib/main_*.dart`), `flutter_bloc`, MethodChannel, Kotlin `TimerForegroundService` / `MainActivity`, AlarmManager (or `android_alarm_manager_plus`), `flutter_test`, `./scripts/verify.sh`

## Global Constraints

- Always run with `--flavor` + `--target` (never treat `lib/main.dart` as the real entry).
- Run `./scripts/setup.sh` (or `flutter pub get` + `flutter gen-l10n`) before analyze/test/build.
- Prefix inspection shells with `rtk` where applicable.
- No em dash (`U+2014`) in docs, comments, commits, or UI strings; use `-`, `:`, or `;`.
- Helpers in `lib/helpers/` stay free of `BuildContext`; Cubit states stay immutable via `copyWith`.
- Do not invent remotes, force-push, or commit unless the user asks (this plan still lists commit steps for when the user approves).
- YAGNI: no overlay/menu-bar ports, no package rename, no `fl_chart`, no sqflite migration in this plan.
- Sequence: **A0 tabs first**, then A2 → A4 → A3 → A1/A19 → A5. Defer A6+.

## File map (create / modify)

| File | Responsibility |
|------|----------------|
| `test/app/view/home_shell_test.dart` | Widget regression for 3-tab shell (narrow + wide) |
| `lib/app/view/home_shell.dart` | Only touch if device QA proves insets/nav broken |
| `lib/widgets/settings_segments/android_battery_opt_tile.dart` | Android-only Settings affordance for battery opt |
| `lib/widgets/settings_segments/settings_segments.dart` | Export new tile |
| `lib/pages/settings/view/settings_page.dart` | Insert tile after Time Tracker section |
| `lib/services/android_notification_service.dart` | Battery channel helpers; hourly payload; action handlers |
| `lib/services/app_navigation_controller.dart` | Already routes `HourlyLogAction`; reuse |
| `lib/helpers/notification_helper.dart` | Existing `hourlyPayload` / `parsePayload`; extend only if action payloads needed |
| `android/.../MainActivity.kt` | Intent extras → MethodChannel; battery methods already exist |
| `android/.../TimerForegroundService.kt` | Hourly actions + payload content Intent; separate notify IDs later |
| `android/app/src/main/AndroidManifest.xml` | Exact alarm + boot permissions when A1 lands |
| `lib/helpers/hook_helper.dart` | Schedule/cancel exact alarms alongside Dart loop (or replace loop on Android) |
| `docs/superpowers/ANDROID-IMPROVEMENTS.md` | Mark IDs done as tasks land |
| `docs/superpowers/DESIGN-GAP-MATRIX.md` | Status flips when shipped |

---

### Task 1: A0 HomeShell three-tab regression test

**Files:**
- Create: `test/app/view/home_shell_test.dart`
- Modify: none unless test reveals a real bug in `lib/app/view/home_shell.dart`
- Test: `test/app/view/home_shell_test.dart`

**Interfaces:**
- Consumes: `HomeShell` from `lib/app/view/home_shell.dart` (pages: `TimerPage`, `TrackerShellPage`, `SettingsPage`)
- Produces: Locked assertion that narrow layout exposes destinations `Focus Timer`, `Hourly Tracker`, `Settings`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/app/view/home_shell.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  Widget wrap(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TimerCubit()),
        BlocProvider(create: (_) => SettingsCubit()..loadSettings()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('narrow layout shows three NavigationBar destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const HomeShell()));
    await tester.pumpAndSettle();

    expect(find.text('Focus Timer'), findsWidgets);
    expect(find.text('Hourly Tracker'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Hourly Tracker'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerShellPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes against HEAD**

Run: `flutter test --flavor development test/app/view/home_shell_test.dart`

Expected on **current main:** PASS (tabs already exist). If FAIL, treat as a real A0 product bug and fix in Step 3.

- [ ] **Step 3: Fix only if failing**

If the test fails because destinations are missing, restore/route `HomeShell` from `lib/app/view/app.dart` (`'/'` → `const HomeShell()`). Do **not** invent a separate Android shell.

If the test fails due to missing Bloc/Prefs setup, adjust the test harness only.

- [ ] **Step 4: Re-run test**

Run: `flutter test --flavor development test/app/view/home_shell_test.dart`  
Expected: PASS

- [ ] **Step 5: Device QA checklist (manual)**

Install from **HEAD**, not tag `v1.2.0+1`:

```bash
flutter run --flavor development -d <android-device> --target lib/main_development.dart
```

Confirm:

1. Bottom bar shows Focus Timer | Hourly Tracker | Settings.
2. Tapping each tab swaps content and preserves state via `IndexedStack`.
3. System gesture nav does not fully obscure the bar (if obscured, wrap `NavigationBar` with `SafeArea` in `home_shell.dart`).

Root-cause note for agents: tagged `v1.2.0+1` routes `/` → `TimerPage` only. Missing tabs on a device almost always means a stale APK.

- [ ] **Step 6: Commit (only if user asked to commit)**

```bash
git add test/app/view/home_shell_test.dart lib/app/view/home_shell.dart
git commit -m "$(cat <<'EOF'
test(android): lock HomeShell three-tab destinations for narrow layouts

EOF
)"
```

---

### Task 2: A2 Battery-optimization Settings UI

**Files:**
- Create: `lib/widgets/settings_segments/android_battery_opt_tile.dart`
- Modify: `lib/widgets/settings_segments/settings_segments.dart`
- Modify: `lib/pages/settings/view/settings_page.dart` (insert after `TimeTrackerExpansion`)
- Modify: `lib/services/android_notification_service.dart` (add battery helpers)
- Test: `test/widgets/settings_segments/android_battery_opt_tile_test.dart`

**Interfaces:**
- Consumes: MethodChannel `com.recoskyler.pomo/timer_notification` methods `isIgnoringBatteryOptimizations` → `bool`, `requestIgnoreBatteryOptimizations` → `bool` (already in `MainActivity.kt`)
- Produces: `AndroidNotificationService.isIgnoringBatteryOptimizations()` and `requestIgnoreBatteryOptimizations()`; Settings tile visible only on Android

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/widgets/settings_segments/android_battery_opt_tile.dart';

void main() {
  const channel = MethodChannel('com.recoskyler.pomo/timer_notification');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isIgnoringBatteryOptimizations') return false;
      if (call.method == 'requestIgnoreBatteryOptimizations') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows status and requests ignore on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AndroidBatteryOptTile())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Battery'), findsOneWidget);
    expect(find.textContaining('Not optimized'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
  });
}
```

Note: On non-Android test hosts, the tile should still pump if it accepts an `isAndroidOverride: true` constructor flag for tests:

```dart
class AndroidBatteryOptTile extends StatefulWidget {
  const AndroidBatteryOptTile({super.key, this.isAndroidOverride});
  final bool? isAndroidOverride;
  // ...
}
```

- [ ] **Step 2: Run test - expect FAIL**

Run: `flutter test --flavor development test/widgets/settings_segments/android_battery_opt_tile_test.dart`  
Expected: FAIL (library/widget missing)

- [ ] **Step 3: Implement service helpers**

In `lib/services/android_notification_service.dart` add:

```dart
Future<bool> isIgnoringBatteryOptimizations() async {
  if (kIsWeb || !Platform.isAndroid) return true;
  try {
    final result =
        await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> requestIgnoreBatteryOptimizations() async {
  if (kIsWeb || !Platform.isAndroid) return true;
  try {
    final result =
        await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    return result ?? false;
  } catch (_) {
    return false;
  }
}
```

- [ ] **Step 4: Implement `AndroidBatteryOptTile`**

Show a `ListTile` titled `Unrestricted battery` with subtitle `Optimized` / `Not optimized` / `Allowed`. On tap call `requestIgnoreBatteryOptimizations` then refresh status. Hide when `(isAndroidOverride ?? (!kIsWeb && Platform.isAndroid))` is false (return `SizedBox.shrink()`).

- [ ] **Step 5: Wire into Settings**

Export from `settings_segments.dart`. In `settings_page.dart` after `TimeTrackerExpansion()`:

```dart
AndroidBatteryOptTile(),
```

- [ ] **Step 6: Run tests + verify**

```bash
flutter test --flavor development test/widgets/settings_segments/android_battery_opt_tile_test.dart
./scripts/verify.sh
```

Expected: PASS

- [ ] **Step 7: Commit (only if user asked)**

```bash
git add lib/widgets/settings_segments/android_battery_opt_tile.dart \
  lib/widgets/settings_segments/settings_segments.dart \
  lib/pages/settings/view/settings_page.dart \
  lib/services/android_notification_service.dart \
  test/widgets/settings_segments/android_battery_opt_tile_test.dart
git commit -m "$(cat <<'EOF'
feat(android): add Settings tile for battery optimization opt-in

EOF
)"
```

---

### Task 3: A4 Notification tap opens HourlyLogDialog

**Files:**
- Modify: `android/.../TimerForegroundService.kt` (content Intent extras)
- Modify: `android/.../MainActivity.kt` (read extras → invoke Dart)
- Modify: `lib/services/android_notification_service.dart` (handle `onNotificationTap`)
- Test: `test/helpers/notification_helper_test.dart` (payload already covered; add Android bridge unit test if needed)
- Test: `test/services/android_notification_service_test.dart` (MethodChannel fake)

**Interfaces:**
- Consumes: `NotificationHelper.hourlyPayload(hour:, date:)` → `hourly:H:YYYY-MM-DD`; `AppNavigationController.handleNotificationAction`
- Produces: Intent extra `pomo_notification_payload` (String); Dart handler `onNotificationTap` with same string

- [ ] **Step 1: Write failing channel-handler test**

```dart
test('onNotificationTap routes hourly payload via parsePayload', () async {
  final action = NotificationHelper.parsePayload('hourly:14:2026-08-12');
  expect(action, isA<HourlyLogAction>());
  final hourly = action! as HourlyLogAction;
  expect(hourly.hour, 14);
  expect(hourly.date, DateTime(2026, 8, 12));
});
```

Add to `test/helpers/notification_helper_test.dart` if not already present; then add service test that invokes the mock handler and expects `parsePayload` to be called (keep pure: assert parse result).

- [ ] **Step 2: Run - confirm payload contract**

Run: `flutter test --flavor development test/helpers/notification_helper_test.dart`  
Expected: PASS for parse; proceed to native wiring.

- [ ] **Step 3: Kotlin content Intent with payload**

In `TimerForegroundService.buildNotification` / `postFallbackNotification`:

```kotlin
val openAppIntent = Intent(this, MainActivity::class.java).apply {
    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    if (isHourly) {
        putExtra("pomo_notification_payload", hourlyPayload) // set field when starting hourly
    }
}
```

Store `hourlyPayload: String?` on the service when `isHourly` starts; pass hour/date from Dart in `startForeground` map:

```dart
await _channel.invokeMethod<bool>('startForeground', {
  'title': ...,
  'text': ...,
  'isRunning': false,
  'isHourly': true,
  'payload': NotificationHelper.hourlyPayload(hour: hour, date: DateTime.now()),
});
```

Use `NotificationHelper.completedHourBlock` date/hour at the call site in `HookHelper` so payload matches the completed block.

- [ ] **Step 4: MainActivity forwards payload**

On `onCreate` / `onNewIntent`:

```kotlin
private fun forwardNotificationPayload(intent: Intent?) {
    val payload = intent?.getStringExtra("pomo_notification_payload") ?: return
    methodChannel?.invokeMethod("onNotificationTap", payload)
}
```

Call after `configureFlutterEngine` and whenever a new Intent arrives.

- [ ] **Step 5: Dart handler**

In `AndroidNotificationService.init` MethodCallHandler:

```dart
case 'onNotificationTap':
  final payload = call.arguments as String?;
  final action = NotificationHelper.parsePayload(payload);
  await AppNavigationController.instance.handleNotificationAction(action);
```

- [ ] **Step 6: Manual QA**

With app backgrounded, trigger hourly notification (or `adb` intent with extra), tap notification, expect Tracker tab + `HourlyLogDialog`.

- [ ] **Step 7: Commit (only if user asked)**

```bash
git commit -m "$(cat <<'EOF'
feat(android): open HourlyLogDialog from hourly notification tap

EOF
)"
```

---

### Task 4: A3 Hourly notification 1-tap actions

**Files:**
- Modify: `android/.../TimerForegroundService.kt`
- Modify: `lib/services/android_notification_service.dart`
- Modify: `lib/helpers/notification_helper.dart` (optional action payload helpers)
- Test: extend notification helper + channel handler tests

**Interfaces:**
- Consumes: DESIGN actions `Log 60m Work`, `Switch Tag`, `Open Grid`
- Produces: Notification action Intents → Dart methods `onHourlyLogWork`, `onHourlySwitchTag`, `onHourlyOpenGrid`

- [ ] **Step 1: Write failing tests for new payloads**

```dart
test('parsePayload accepts hourly action suffixes', () {
  expect(
    NotificationHelper.parsePayload('hourly:14:2026-08-12:log_work'),
    isA<HourlyLogAction>(),
  );
});
```

Decide YAGNI: either reuse `HourlyLogAction` and open the dialog (Log / Switch Tag both open dialog; Open Grid only switches to tab 1), or add sealed variants. Prefer:

- `log_work` / `switch_tag` → `HourlyLogAction` (dialog)
- `open_grid` → set `tabIndex = 1` only (`FocusMainWindowAction` is wrong; add `OpenTrackerAction` or call `tabIndex.value = 1` directly)

Minimal sealed addition:

```dart
final class OpenTrackerAction extends NotificationAction {
  const OpenTrackerAction();
}
```

Update `parsePayload` and `AppNavigationController`.

- [ ] **Step 2: Run tests - expect FAIL**

- [ ] **Step 3: Implement parse + controller branches**

- [ ] **Step 4: Add Kotlin actions when `isHourly`**

```kotlin
if (isHourly) {
    builder.addAction(0, "Log 60m Work", pendingFor("log_work"))
    builder.addAction(0, "Switch Tag", pendingFor("switch_tag"))
    builder.addAction(0, "Open Grid", pendingFor("open_grid"))
}
```

Broadcast/service actions should land in `MainActivity` or service → `methodChannel.invokeMethod("onNotificationTap", payload)`.

- [ ] **Step 5: Device QA shade actions**

- [ ] **Step 6: `./scripts/verify.sh`**

- [ ] **Step 7: Commit (only if user asked)**

```bash
git commit -m "$(cat <<'EOF'
feat(android): add hourly notification Log / Switch / Open Grid actions

EOF
)"
```

---

### Task 5: A1 Exact hourly alarms + A19 boot reschedule

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`)
- Create: `android/.../HourlyAlarmReceiver.kt` (and optional `BootReceiver.kt`)
- Modify: `lib/helpers/hook_helper.dart` / `lib/services/android_notification_service.dart` to schedule next alarm
- Test: pure Dart scheduling math in `test/helpers/hourly_alarm_schedule_test.dart`

**Interfaces:**
- Consumes: `Prefs.enableTimeTracker`, quiet hours via `SoundHelper.isQuietHours` / `NotificationHelper.shouldShowDesktopHourlyNotification` (reuse gating fields)
- Produces: `scheduleNextHourlyAlarm()` / `cancelHourlyAlarms()` on the Android channel; receiver posts notification or starts FGS with payload

- [ ] **Step 1: Write failing schedule helper test**

```dart
// lib/helpers/hourly_alarm_schedule.dart
DateTime nextHourBoundary(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour)
      .add(const Duration(hours: 1));
}

test('nextHourBoundary snaps to upcoming hour', () {
  expect(
    nextHourBoundary(DateTime(2026, 8, 12, 14, 37)),
    DateTime(2026, 8, 12, 15),
  );
});
```

- [ ] **Step 2: Run - FAIL until file exists**

- [ ] **Step 3: Implement schedule helper + channel schedule/cancel**

- [ ] **Step 4: Manifest permissions + receivers**

- [ ] **Step 5: Receiver posts hourly notification with payload (reuse A4 path)**

Quiet hours: if in quiet hours, skip beep/notification (and optionally leave Resting auto-log to deferred A6).

- [ ] **Step 6: On boot, if `enableTimeTracker`, reschedule**

- [ ] **Step 7: Keep Dart `Timer.periodic` as in-process backup while process alive; exact alarm is source of truth when killed**

- [ ] **Step 8: Device QA with app force-stopped + Doze**

- [ ] **Step 9: Commit (only if user asked)**

```bash
git commit -m "$(cat <<'EOF'
feat(android): schedule exact hourly alarms with boot reschedule

EOF
)"
```

---

### Task 6: A5 FGS lifecycle hygiene (after alarms work)

**Files:**
- Modify: `android/.../TimerForegroundService.kt`
- Modify: `lib/services/android_notification_service.dart`

**Interfaces:**
- Produces: Distinct notification IDs (`TIMER_NOTIFICATION_ID = 1001`, `HOURLY_NOTIFICATION_ID = 1002`); separate channel `hourly_tracker` (IMPORTANCE_HIGH); sticky policy documented

- [ ] **Step 1: Write a short architecture note in `ARCHITECTURE.md` (Android FGS section)** - fold docs into this task's deliverable

- [ ] **Step 2: Split IDs/channels in Kotlin**

- [ ] **Step 3: Ensure hourly alarm path does not require an already-running Dart isolate to show the shade notification**

- [ ] **Step 4: Manual QA: start timer, fire hourly, confirm both notifications (or intentional replace policy documented)**

- [ ] **Step 5: `./scripts/verify.sh`**

- [ ] **Step 6: Commit (only if user asked)**

```bash
git commit -m "$(cat <<'EOF'
fix(android): separate timer and hourly notification IDs and channels

EOF
)"
```

---

### Task 7: Docs sync when phases complete

**Files:**
- Modify: `docs/superpowers/ANDROID-IMPROVEMENTS.md` (mark A0-A5 statuses)
- Modify: `docs/superpowers/DESIGN-GAP-MATRIX.md` (flip OPEN/Partial → Shipped)

- [ ] **Step 1: Update matrix rows for Nav shell, Battery-opt, Exact alarms, Persistent 1-tap**

- [ ] **Step 2: Commit docs only if user asked**

---

## Deferred (out of this plan)

- A6 auto-`Resting` quiet hours logs  
- A7 `enableQuietHours` in missed-hours scan  
- A8 bootstrap soft prompts  
- A9 background chime audio focus  
- A10 fallback notification actions (partially overlaps A3; only if still missing after Task 4)  
- A11-A20 P2 backlog  

## Self-review checklist (author)

1. **Spec coverage:** A0 tabs, A2 battery UI, A4 tap, A3 actions, A1+A19 alarms, A5 FGS each have tasks. Deferred list matches ANDROID-IMPROVEMENTS should-improve/nice-to-have.
2. **Placeholders:** No TBD/TODO steps; concrete files and code snippets included.
3. **Types:** Payload string `hourly:H:YYYY-MM-DD` (+ optional `:action`) consistent across Tasks 3-5; channel name `com.recoskyler.pomo/timer_notification` unchanged.
4. **Ship gate:** Task 1 must pass device QA before Tasks 2-6 product work is considered done for Android users.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** - Fresh subagent per task, review between tasks, fast iteration (`superpowers:subagent-driven-development`)
2. **Inline Execution** - Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints

**Which approach?**

Also confirm: should docs (`ANDROID-IMPROVEMENTS.md`, `DESIGN-GAP-MATRIX.md`, this plan) be committed now, or wait until Task 1 lands?
