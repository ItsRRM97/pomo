# QA Report: Android parity A0–A5 (physical device attempt)

**Date:** 2026-08-17  
**HEAD under test:** `87e8705` (`docs(qa): android A0-A5 device report`)  
**Branch:** `main` (local; ahead of origin; not pushed this session)  
**Tester:** agent (device QA resume)  
**Mode:** Device QA **BLOCKED** (USB debugging unauthorized)

## Environment

| Item | Result |
|------|--------|
| Physical Android device | Present on USB: serial `35b359b3`, transport `usb:1-1.3` |
| `adb devices` state | **`unauthorized`** (persistent across `adb kill-server` / restart) |
| `flutter devices` | macOS, Chrome only; Flutter reports: *Device 35b359b3 is not authorized* |
| Device model / product | Unknown (cannot query props while unauthorized) |
| Build/install from HEAD | Not attempted |
| Prior report | `docs/superpowers/qa-reports/2026-08-12-android-parity-a0-a5.md` (host static/unit only) |

**Blocker (exact):** Phone is connected (MTP / File transfer) but **USB debugging authorization was not granted**. `adb` cannot open a shell, install APKs, or run Flutter. Confirmation dialog must be accepted on the device (Allow USB debugging; optionally Always allow from this computer).

```text
List of devices attached
35b359b3               unauthorized usb:1-1.3 transport_id:1

adb -s 35b359b3 get-state
error: device unauthorized.
This adb server's $ADB_VENDOR_KEYS is not set
...
Otherwise check for a confirmation dialog on your device.
```

## Checklist results (this session)

All device-dependent items remain **BLOCKED**. No new pass/fail on hardware.

| # | Item | Result |
|---|------|--------|
| 1 | A0 three tabs | BLOCKED (device) |
| 2 | SafeArea / nav clip | BLOCKED (device) |
| 3 | A2 battery tile | BLOCKED (system UI) |
| 4 | A4 tap → dialog | BLOCKED (shade / cold start) |
| 5 | A3 shade actions | BLOCKED (shade) |
| 6 | A1/A19 alarms + boot | BLOCKED (Doze / kill / reboot) |
| 7 | A5 dual notification IDs | BLOCKED (device coexistence) |
| 8 | Cancel-after-act UX | BLOCKED (device) |
| 9 | A22 RenderFlex ~390px | Not rechecked on device (prior FAIL in widget harness 2026-08-12) |
| 10 | Install HEAD APK | BLOCKED |

**Overall status:** `BLOCKED` - hardware attached but not authorized for debugging.

Host evidence from 2026-08-12 still stands (static/unit PASS for A0–A5 paths; A22 FAIL in widget test at 390px). Not re-run this session (no install possible).

---

## User action required (unblock)

1. Unlock the phone.
2. Look for **Allow USB debugging?** (RSA fingerprint of this Mac).
3. Tap **Allow** (prefer **Always allow from this computer**).
4. If no dialog: Developer options → revoke USB debugging authorizations → unplug/replug USB → set USB mode to File transfer (MTP) again → unlock and accept the new prompt.
5. Confirm on the Mac: `adb devices` shows `35b359b3 device` (not `unauthorized`).
6. Resume QA:  
   `flutter run --flavor development -d 35b359b3 --target lib/main_development.dart`  
   (install from HEAD, not `v1.2.0` tag).

## What remains after auth (carry-forward)

Same physical gate list as 2026-08-12 report:

1. Uninstall stale `v1.2.0+1` if present; install from current HEAD.
2. A0 tabs + SafeArea / gesture-nav clip.
3. A2 battery optimization system dialog.
4. A4 notification tap → HourlyLogDialog (warm + cold start).
5. A3 shade Log / Switch Tag / Open Grid.
6. A5 dual IDs 1001 + 1002; cancel-after-act only clears 1002.
7. A1/A19: `dumpsys alarm`, reboot reschedule, force-stop, **Doze overnight**.
8. A22 visual overflow on Tracker at ~390dp (fix OK if quick after reproduce).

## Session notes

- Git author email verified: `19824021+ItsRRM97@users.noreply.github.com`.
- Polled ~30s + adb server restart; state stayed `unauthorized`.
- No product code changes; no APK build; no push.
