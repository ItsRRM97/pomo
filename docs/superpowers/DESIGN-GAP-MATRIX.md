# DESIGN vs shipped gap matrix

**Baseline product design:** `DESIGN.md` (approved 2026-07-13)  
**Last process update:** 2026-08-12 (Android A0-A5 parity plan shipped in code; device QA pending)  
**How to use:** Prefer OPEN / Partial rows for the next writing-plans cycle. Do not treat this file as a substitute for `DESIGN.md`.  
**Android detail:** `docs/superpowers/ANDROID-IMPROVEMENTS.md` (full prioritized backlog + what already works).  
**Active plan:** `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md` (code complete; device QA gate open)

| Item | Status | Reality / notes |
|------|--------|-----------------|
| Nav shell | **Shipped (code)** / Partial: device QA pending | `HomeShell` 3 tabs on `main` (`home_shell.dart`, `test/app/view/home_shell_test.dart`). Tagged `v1.2.0+1` APKs still `/` → `TimerPage` only. Rebuild from HEAD; confirm bottom `NavigationBar` on physical Android (A0). |
| Activity grid + missed hours | Shipped | Under `lib/pages/tracker/` |
| Quiet hours | Partial | Settings + Dart gating shipped; missed-hours scan ignores `enableQuietHours` off; no auto-`Resting` logs (see A6/A7) |
| `pendingTimeLogs` + tests | Shipped | Prefs queue; scalability note in `TODOS.md` |
| Notion activity tags / sync | Shipped | Integration present |
| Battery-opt Settings UI | **Shipped (code)** / Partial: device QA pending | `AndroidBatteryOptTile` + MethodChannel in `android_notification_service.dart`; `android_battery_opt_tile_test.dart` (A2). Verify opt-in flow on device. |
| Exact hourly alarms (Doze / killed) | **Shipped (code)** / Partial: device QA pending | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`, `BootReceiver.kt`; manifest `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` / `RECEIVE_BOOT_COMPLETED`; Dart `scheduleNextHourlyAlarm` (A1/A19). Doze/kill/reboot QA not signed off. |
| Persistent 1-tap notification actions | **Shipped (code)** / Partial: device QA pending | Timer Play/Pause/Stop unchanged. Hourly: Log / Switch Tag / Open Grid + tap payload `hourly:H:YYYY-MM-DD` → `AppNavigationController` (A3/A4). Separate channel `hourly_tracker` / ID 1002 (A20/A5). Shade/cold-start QA pending. |
| `fl_chart` analytics | Not started | Not in deps; custom UI instead |
| Superpowers path | In progress | `docs/superpowers/` (+ Android improvements list + parity plan) |
| Agent entry polish | In progress | `AGENTS.md` light pass + README pointer (Approach 1) |

## Top open product gaps (next plan)

1. **Android device QA gate** - install from HEAD (not `v1.2.0+1`); A0 tabs, A2 battery tile, A1/A19 alarms (Doze/kill/reboot), A3/A4 shade actions and tap routing, A5 dual notification coexistence.
2. **Quiet hours product gaps** - auto-`Resting` logs (A6); honor `enableQuietHours` in missed-hours scan (A7).
3. **Android polish** - bootstrap battery/notification prompts (A8), background chime reliability (A9), FGS fallback actions (A10).
4. **Analytics presentation** - confirm DESIGN intent vs custom charts; only then consider `fl_chart` or keep custom.

## Explicitly deferred by Approach 1

Process/docs work does **not** implement the product rows above. Feature work needs brainstorming → writing-plans → TDD → `./scripts/verify.sh`.
