# Android Must / Should (2026-08-17)

**Goal:** Ship remaining Must (A22) and Should (A6-A10, A12, A21) items. A1/A19 overnight Doze / reboot / force-stop stays residual device QA.

**Status (2026-08-17):** Code complete on `feat/android-must-should`. Nice items (A11, A14-A18) out of scope. Overnight device QA not claimed.

**Order:** A22 → A7 → A6 → A21 → A8 → A10 → A9 → A12 → docs.

## Tasks

1. **A22** Tracker layout at ≤390 dp. Widget test at 390×844 must fail on overflow first, then pass. Do not drain exceptions.
2. **A7** Gate missed-hours sleep window on `Prefs.enableQuietHours`. Extract hour-index helper (no `BuildContext`).
3. **A6** Auto-write `Sleep & Rest` (`tag_sleep`, DESIGN Resting) hourly logs for quiet-hour blocks. Reconcile in Dart (hourly skip + tracker load); native alarm can enqueue for next Dart start.
4. **A21** `Log 60m Work` writes immediately (no dialog). `Switch Tag` still opens dialog. Snackbar undo when UI is up. Native BroadcastReceiver queues the write if Dart is dead.
5. **A8** Soft prompt for battery-opt / notification status when enabling tracker and when opening Tracker (not Settings-only).
6. **A10** Mirror Play/Pause/Stop on D5 FGS fallback notification.
7. **A9** Hourly channel sound + short WakeLock / audio focus in `HourlyAlarmReceiver`. Use bundled `digital_beep.wav` (DESIGN `pop.aac` is not in the tree).
8. **A12** Host tests of Dart/native MethodChannel contract (method names + args vs `MainActivity.kt`).
9. **Docs** Sync `ANDROID-IMPROVEMENTS.md`, `DESIGN-GAP-MATRIX.md`, `TODOS.md`. Note A1/A19 residual device QA.

## Out of scope

A11, A14-A18 (Nice). Do not fake overnight Doze/reboot QA.

## Verify

`./scripts/verify.sh` before finishing. Flavor `development` / target `lib/main_development.dart`. No em dashes. Commit per item. No push.
