# TODOS

## Future Architecture Scalability Backlog
- [ ] **Migrate `Prefs.pendingTimeLogs` to `sqflite`:** If offline time log accumulation in `SharedPreferences` exceeds 1,000 pending entries per month during prolonged off-grid usage, migrate the JSON list queue to an indexed local `sqflite` database table (`time_blocks`).

## Closed
- [x] **Wire battery optimization request in Settings:** `AndroidBatteryOptTile` + MethodChannel (`requestIgnoreBatteryOptimizations`) shipped (A2). Tracker also prompts on enable (A8). Overnight Doze / OEM remains residual device QA, not a missing Settings affordance.
