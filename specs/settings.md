# Settings

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/pages/settings/`, `lib/widgets/settings_segments/`

---

## Purpose

Tab 2 configures timer, appearance, Notion, webhooks, hourly tracker, and platform extras. `SettingsCubit.loadSettings()` hydrates from Prefs; every mutation writes Prefs immediately.

## Sections (order on `SettingsView`)

| Widget | What it controls |
|--------|------------------|
| `ThemeDropdown` | light / dark / system |
| `ColorPicker` | `colorSeed` (Material 3) |
| `TimerFontDropdown` | mono / fancy / bold / custom font name |
| `AlwaysOnTopToggle` | desktop window (no-op on web/mobile) |
| `ShowFloatingTimerToggle` | macOS overlay |
| `OverlayCornerDropdown` | overlay corner |
| `DesktopNotificationsToggle` | macOS banners |
| `LaunchAtLoginToggle` | macOS login item |
| `AutoAdvanceToggle` | auto next lap |
| Work / short / long duration sliders | minutes |
| `LapCountSlider` | work+break cycles |
| `CustomSoundExpansion` | enable sound + per-event custom files |
| `NotionToggle` + `NotionExpansion` | sync, token, proxy, all database IDs |
| `WebHooksToggle` + `WebHooksExpansion` | enable, method, per-event URLs |
| `TimeTrackerToggle` + `TimeTrackerExpansion` | tracker master switch, quiet hours range, Android notification permission request |
| `AndroidBatteryOptTile` | ignore battery optimizations (Android) |

About: app bar info → `/about`.

## Defaults (selected)

- Work 25 / short 5 / long 15 / 4 laps
- Sound on; webhooks off; Notion off
- Time tracker on; quiet hours on `23:00`–`07:00`
- Desktop notifications on; launch at login off

Changing lap-related sliders can `TimerCubit.reset()`.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped settings spec |
