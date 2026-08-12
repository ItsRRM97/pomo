# DESIGN vs shipped gap matrix

**Baseline product design:** `DESIGN.md` (approved 2026-07-13)  
**Last process update:** 2026-08-12 (Android A0 three-tab ship gate + parity plan)  
**How to use:** Prefer OPEN / Partial rows for the next writing-plans cycle. Do not treat this file as a substitute for `DESIGN.md`.  
**Android detail:** `docs/superpowers/ANDROID-IMPROVEMENTS.md` (full prioritized backlog + what already works).  
**Active plan:** `docs/superpowers/plans/2026-08-12-android-parity-tabs-and-background.md`

| Item | Status | Reality / notes |
|------|--------|-----------------|
| Nav shell | Shipped in HEAD / Partial for released APKs | `HomeShell` 3 tabs in current `main` (`home_shell.dart`); tagged `v1.2.0+1` still `/` → `TimerPage` only. User-missing-tabs reports → rebuild from HEAD (A0). |
| Activity grid + missed hours | Shipped | Under `lib/pages/tracker/` |
| Quiet hours | Partial | Settings + Dart gating shipped; missed-hours scan ignores `enableQuietHours` off; no auto-`Resting` logs (see A6/A7) |
| `pendingTimeLogs` + tests | Shipped | Prefs queue; scalability note in `TODOS.md` |
| Notion activity tags / sync | Shipped | Integration present |
| Battery-opt Settings UI | OPEN | Native channel in `MainActivity.kt`; Settings/Dart not wired (`TODOS.md`, A2) |
| Exact hourly alarms (Doze / killed) | OPEN | Dart `Timer.periodic` only; no `SCHEDULE_EXACT_ALARM` / AlarmManager (A1) |
| Persistent 1-tap notification actions | Partial | Timer Play/Pause/Stop shipped; hourly lacks Log/Switch/Open Grid; tap does not open log dialog (A3/A4) |
| `fl_chart` analytics | Not started | Not in deps; custom UI instead |
| Superpowers path | In progress | `docs/superpowers/` (+ Android improvements list + parity plan) |
| Agent entry polish | In progress | `AGENTS.md` light pass + README pointer (Approach 1) |

## Top open product gaps (next plan)

1. **A0 three-tab Android ship gate** - verify/install HEAD `HomeShell`; widget regression; do not start background work until tabs are confirmed on device.
2. **Battery-opt Settings UI** - wire existing Android channel + permission flow in Settings (A2).
3. **Exact hourly alarms** - survive Doze / process death (A1); pair with boot reschedule (A19).
4. **Persistent hourly 1-tap actions + tap routing** - close Partial vs DESIGN success #2 (A3/A4).
5. **Analytics presentation** - confirm DESIGN intent vs custom charts; only then consider `fl_chart` or keep custom.

## Explicitly deferred by Approach 1

Process/docs work does **not** implement the product rows above. Feature work needs brainstorming → writing-plans → TDD → `./scripts/verify.sh`.
