# TODOS

## Future Architecture Scalability Backlog
- [ ] **Migrate `Prefs.pendingTimeLogs` to `sqflite`:** If offline time log accumulation in `SharedPreferences` exceeds 1,000 pending entries per month during prolonged off-grid usage, migrate the JSON list queue to an indexed local `sqflite` database table (`time_blocks`).
- [ ] **Wire battery optimization request in Settings:** `MainActivity.kt` already exposes `requestIgnoreBatteryOptimizations`; add a Settings affordance (and `permission_handler` flow) so Android users can opt in for reliable hourly reminders under Doze.
