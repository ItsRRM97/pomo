# QA Report: Android parity A0–A5 (physical device)

**Date:** 2026-08-17  
**HEAD under test:** `66ad723` (+ local uncommitted `coreLibraryDesugaring` in `android/app/build.gradle` required to assemble)  
**Branch:** `main` (local; ahead of origin; report commit only this session)  
**Tester:** agent (device QA)  
**Mode:** Physical device QA on authorized USB device

## Environment

| Item | Result |
|------|--------|
| Device | **OPPO CPH2573** (`product:CPH2573IN`, `device:OP595DL1`) |
| Serial | `35b359b3` |
| OS | Android **16** (API 36) |
| Display | 1440×3168 physical; density override **560** (~411 dp width) |
| `adb` / `flutter devices` | `device` authorized; Flutter sees `CPH2573 (mobile)` |
| Package installed | `com.recoskyler.pomo.dev` **1.3.9** (fresh install from HEAD APK after uninstalling prior **1.3.6**) |
| Build | `flutter build apk --debug --flavor development -t lib/main_development.dart` |
| Screenshots | `docs/superpowers/qa-reports/2026-08-17-android-screenshots/` |

### Build blocker fixed locally (not committed)

First `flutter run` / APK assemble failed:

`Dependency ':flutter_local_notifications' requires core library desugaring`

Local fix in `android/app/build.gradle` (left **uncommitted** per “report only” commit scope):

- `compileOptions.coreLibraryDesugaringEnabled true`
- `coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"`

Parent should land this as a separate product commit.

## Checklist results

### 1. A0 Tabs (Focus Timer | Hourly Tracker | Settings)

| Status | **PASS (device)** |

**Evidence:** Bottom `NavigationBar` shows three destinations; taps switch Focus / Hourly Tracker / Settings. Screenshots: `01-launch.png`, `02-hourly-tracker.png`, `03-settings-battery-tile.png`.

---

### 2. SafeArea / bottom nav not clipped

| Status | **PASS (device)** |

**Evidence:** On gesture navigation (system pill visible), tab labels/icons sit above the gesture bar with no clipping on Focus, Tracker, or Settings. Screenshots: `01-launch.png`, `02-hourly-tracker.png`.

---

### 3. A2 Battery optimization Settings tile

| Status | **PASS (device)** |

**Evidence:**

- Tile **Unrestricted battery** visible under Settings (status initially `Optimized (may delay reminders)`).
- Tap opens system dialog **Let app always run in background?** with **Allow** / **Denied** (`RequestIgnoreBatteryOptimizations`).
- After Allow + process restart, tile shows **Allowed (unrestricted)**; `cmd deviceidle whitelist` includes `com.recoskyler.pomo.dev`.
- Screenshot: `05-battery-after-allow.png` (Allowed state). Dialog confirmed via `uiautomator` dump (title + Allow button).

---

### 4. A4 Hourly notification tap → HourlyLogDialog (warm + cold)

| Status | **PASS (device)** |

**Evidence:**

- With quiet hours off, hourly shade notification posts (channel `hourly_tracker`, ID **1002**, 3 actions).
- Warm content intent (`ACTION_OPEN_HOURLY` + `pomo_notification_payload=hourly:0:2026-08-17`) opens **Log Hour: 00:00 - 01:00** dialog on Tracker tab. Screenshot: `10-a4-content-tap-dialog.png`.
- Cold start: `am force-stop` then same intent opens the same dialog. Screenshot: `13-a4-cold-start.png`.

**Note:** Direct `adb` broadcast to `HourlyAlarmReceiver` is denied while `exported=false` (expected). Firing for QA used a temporary `exported=true` rebuild, then reverted. Production path is AlarmManager PendingIntent (same UID), which was already scheduled at next hour boundary.

---

### 5. A3 Shade actions: Log / Switch Tag / Open Grid

| Status | **PASS (device)** |

**Evidence:**

- Notification `actions=3` on ID 1002 (`Log 60m Work`, `Switch Tag`, `Open Grid`).
- Shade grouped tile showed Work Session + hourly body text (`07-shade-dual-notifs.png`).
- Simulated action intents:
  - `open_grid` → Tracker grid (**Hourly Time Tracker** / Activity Grid). Screenshot: `11-a3-open-grid.png`.
  - `log_work` → **HourlyLogDialog** (not silent Notion write). Screenshot: `12-a3-log-work-dialog.png`.
- Switch Tag shares the same dialog-open path as Log (payload suffix); exercised via log_work dialog path + static action wiring.

---

### 6. A1 / A19 Exact hourly alarms + BootReceiver

| Status | **PASS (schedule/cancel)** / **BLOCKED (Doze overnight, reboot, force-stop survival)** |

**Evidence:**

- With **Enable Time Tracker** on: `dumpsys alarm` shows `RTC_WAKEUP` `com.recoskyler.pomo.ACTION_HOURLY_ALARM` → `HourlyAlarmReceiver`, `origWhen` next hour (`02:00:00`), `exactAllowReason=policy_permission`.
- Toggle tracker off: pending alarm **cancelled** (`pi_cancelled` history).
- Toggle on again: alarm rescheduled.
- Quiet hours (23:00–07:00) correctly **suppresses** notify while still allowing schedule chain; disabled for notify tests.

**Still required on device (overnight / manual):**

1. Leave tracker enabled overnight through Doze / battery saver.
2. Force-stop app and confirm next hour still fires.
3. Reboot and confirm `BootReceiver` reschedules.

---

### 7. A5 Timer FGS vs hourly notification IDs/channels

| Status | **PASS (device)** |

**Evidence:** Concurrent records:

- ID **1001**, channel `pomo_timer_channel_v2` (FGS / Focus Timer)
- ID **1002**, channel `hourly_tracker` (reminder, 3 actions)

Shade showed both under a group with badge **2** (`07-shade-dual-notifs.png`). Timer tap path does not replace hourly ID.

---

### 8. Cancel-after-act / check-in UX

| Status | **PASS (device, with OEM lag note)** |

**Evidence:** After A4 content / A3 log intents, `NotificationRecord` for ID **1002** drops while ID **1001** remains. ColorOS may briefly retain a stale `StatusBarNotification` line for 1002; active `NotificationRecord` list is the reliable signal.

---

### 9. A22 Tracker RenderFlex at ~390px

| Status | **PASS on this device (~411 dp)** / prior harness **FAIL at 390** still open |

**Evidence:** Tracker UI on CPH2573 shows no yellow/black overflow stripes (`02-hourly-tracker.png`, `14-tracker-a22-check.png`). Logical width ≈ 411 dp (wider than the 390 harness case from 2026-08-12). Do not close A22 until fixed or rechecked at ≤390 dp.

---

### 10. Install from HEAD (not v1.2.0)

| Status | **PASS** |

Uninstalled `com.recoskyler.pomo.dev` 1.3.6; installed development debug APK **1.3.9** from current tree.

---

## Summary table

| # | Item | Result |
|---|------|--------|
| 1 | A0 three tabs | **PASS** |
| 2 | SafeArea / nav clip | **PASS** |
| 3 | A2 battery tile | **PASS** |
| 4 | A4 tap → dialog (warm + cold) | **PASS** |
| 5 | A3 shade actions | **PASS** |
| 6 | A1/A19 alarms + boot | **PASS** schedule/cancel; **OPEN** Doze/reboot/force-stop |
| 7 | A5 dual notification IDs | **PASS** |
| 8 | Cancel-after-act UX | **PASS** |
| 9 | A22 RenderFlex ~390px | **PASS** on ~411 dp device; harness FAIL remains |
| 10 | Install HEAD APK | **PASS** |

**Overall status:** `DONE_WITH_CONCERNS` - device gates for A0–A5 interactive paths passed; overnight Doze / reboot / force-stop and narrow-width A22 remain.

## Remaining physical items

1. **Doze overnight** with tracker enabled (confirm 1002 still posts at hour boundaries).
2. **Force-stop** then wait for next exact hour (or advance time with care).
3. **Reboot** reschedule via `BootReceiver`.
4. Optional: recheck A22 on a ≤390 dp width (or emulator) and fix layout if still overflowing.
5. Commit the **desugar** `build.gradle` fix so CI/device builds do not fail.

## Session notes

- Git author email verified: `19824021+ItsRRM97@users.noreply.github.com`.
- Temporary `HourlyAlarmReceiver exported=true` used only to adb-trigger notify; **reverted** before finish.
- Device clock briefly advanced via `cmd alarm set-time` then restored (`auto_time` re-enabled).
- No push. Product code change left uncommitted: desugar only.
