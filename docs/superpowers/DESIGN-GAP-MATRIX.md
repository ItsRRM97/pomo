# DESIGN vs shipped gap matrix

**Baseline product design:** `DESIGN.md` (approved 2026-07-13)  
**Last process update:** 2026-08-17 (Android Must/Should A22, A6-A10, A12, A21 shipped in code; A1/A19 overnight device QA still residual)  
**How to use:** Prefer OPEN / Partial rows for the next writing-plans cycle. Do not treat this file as a substitute for `DESIGN.md`.  
**Android detail:** `docs/superpowers/ANDROID-IMPROVEMENTS.md` (full prioritized backlog + what already works).  
**Active plan:** `docs/superpowers/plans/2026-08-17-android-must-should.md` (code complete; overnight Doze/reboot/force-stop still residual)  
**QA reports:** `docs/superpowers/qa-reports/2026-08-12-android-parity-a0-a5.md` (host) · `docs/superpowers/qa-reports/2026-08-17-android-parity-device.md` (interactive device; overnight gates open)

| Item | Status | Reality / notes |
|------|--------|-----------------|
| Nav shell | **Shipped (code)** / Partial: device QA pending | `HomeShell` 3 tabs (`home_shell.dart`, `test/app/view/home_shell_test.dart`). Tagged `v1.2.0+1` APKs still `/` → `TimerPage` only. Rebuild from HEAD (A0). |
| Activity grid + missed hours | Shipped | Under `lib/pages/tracker/`; 390 dp overflow fixed (A22) |
| Quiet hours | **Shipped (code)** | Settings + Dart gating; `QuietHoursHelper` honors `enableQuietHours` (A7); auto-`Resting` after `pullHourlyLogs` (A6); user Work wins vs auto-Resting |
| `pendingTimeLogs` + tests | Shipped | Prefs queue; scalability note in `TODOS.md` (A16 Nice) |
| Notion activity tags / sync | Shipped | Integration present |
| Battery-opt Settings UI | **Shipped (code)** | `AndroidBatteryOptTile` (A2) plus tracker soft prompt (A8). Overnight OEM still residual. |
| Exact hourly alarms (Doze / killed) | **Shipped (code)** / Partial: residual device QA | `HourlyAlarmScheduler.kt`, `HourlyAlarmReceiver.kt`, `BootReceiver.kt` (A1/A19). Overnight Doze / reboot / force-stop not signed off. |
| Persistent 1-tap notification actions | **Shipped (code)** / Partial: residual device QA | Timer Play/Pause/Stop including D5 fallback (A10). Hourly: `Log 60m Work` instant write (A21); `Switch Tag` still dialog; `Open Grid` switches tab. Channel `hourly_tracker_v2` / ID 1002 (A20/A5/A9). |
| `fl_chart` analytics | Not started | Not in deps; custom UI instead (A15 Nice) |
| Superpowers path | In progress | `docs/superpowers/` (+ Android improvements list + parity plans) |
| Agent entry polish | In progress | `AGENTS.md` light pass + README pointer (Approach 1) |

## Top open product gaps (next plan)

1. **Residual Android device QA** - overnight Doze, reboot, and force-stop for A1/A19. Do not close from host tests. Interactive A0-A5: `qa-reports/2026-08-17-android-parity-device.md`.
2. **Nice Android / product backlog** - custom notification icon (A11); package rename (A14); `fl_chart` (A15); `pendingTimeLogs` → sqflite (A16); `permission_handler` cleanup (A17); App Links (A18).
3. **Analytics presentation** - confirm DESIGN intent vs custom charts; only then consider `fl_chart` or keep custom.

## Explicitly deferred by Approach 1

Process/docs work does **not** implement the product rows above. Feature work needs brainstorming → writing-plans → TDD → `./scripts/verify.sh`.
