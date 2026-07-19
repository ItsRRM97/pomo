# ARCHITECTURE.md - Pomo System Architecture & Design Specification

This document explains the technical design, architectural patterns, and subsystem workflows of `pomo`, a cross-platform Pomodoro timer application built with Flutter (`github.com/recoskyler/pomo`).

---

## 1. High-Level Architectural Overview

`pomo` follows a clean, modular architecture separating presentation (`lib/pages/`, `lib/widgets/`), state management (`flutter_bloc` / `Cubit`), pure domain logic (`lib/helpers/`), persistence (`lib/singletons/prefs.dart`), and platform-specific shell integration (`lib/desktop/`). Hourly time tracking lives under `lib/pages/tracker/` (Activity Grid, Missed Hours, Notion Hourly Timeline sync via `Prefs` + `NotionSyncService`). Custom Activity Tags use registry rows in the same Notion database (`Source = pomo-activity-tag`); deletion tombstones propagate removals across PWA and desktop clients.

```
+-----------------------------------------------------------------------------------+
|                                  Presentation Layer                               |
|   +-------------------+       +-----------------------+     +-----------------+   |
|   |   TimerPage /     |       |     SettingsPage /    |     |   Desktop &     |   |
|   |   TimerView       |       |     SettingsView      |     |   OverlayApp    |   |
+---+---------+---------+-------+-----------+-----------+-----+--------+--------+---+
              |                             |                          |
              v                             v                          v
+-----------------------------------------------------------------------------------+
|                            State Management Layer (BLoC)                          |
|   +------------------------------------+  +-----------------------------------+   |
|   |             TimerCubit             |  |           SettingsCubit           |   |
|   |   (Status, Duration, Lap, Count)   |  |   (Theme, WebHooks, Audio, Laps)  |   |
+---+-----------------+------------------+--+-----------------+-----------------+---+
                      |                                       |
                      v                                       v
+-----------------------------------------------------------------------------------+
|                            Domain Mixins & Helpers Layer                          |
|   +-------------------+  +-----------------+  +---------------+  +------------+   |
|   |  DurationHelper   |  |    LapHelper    |  |  SoundHelper  |  | HookHelper |   |
+---+---------+---------+--+--------+--------+--+-------+-------+--+-----+------+---+
              |                     |                   |                |
              v                     v                   v                v
+-----------------------------------------------------------------------------------+
|                         Persistence & Platform Infrastructure                     |
|   +------------------------------------+  +-----------------------------------+   |
|   |       Shared Preferences (Prefs)   |  |   Window/Tray/Multi-Window Shell  |   |
+----------------------------------------+--+-----------------------------------+---+
```

---

## 2. Core State Management & Flow (`TimerCubit` & `SettingsCubit`)

The application state revolves around two primary `Cubit` instances provided globally via `MultiBlocProvider` in `lib/app/view/app.dart`:

### A. `TimerCubit` (`lib/pages/timer/cubit/timer_cubit.dart`)
- **State Object (`TimerState`)**: Tracks four fundamental properties:
  - `status`: `TimerStatus.running` or `TimerStatus.stopped`.
  - `duration`: The accumulated `Duration` elapsed in the current lap.
  - `lap`: The active lap type (`TimerLap.work`, `TimerLap.shortBreak`, `TimerLap.longBreak`).
  - `lapNumber`: The zero-indexed integer counter (`0` to `(lapCount * 2) - 1`) tracking overall session progress.
- **Tick Lifecycle (`tick`)**:
  1. Called periodically (typically once per second via `TimerTickService` / internal `Timer`).
  2. Adds the delta duration (`1 second`) to `state.duration`.
  3. Evaluates lap completion via `DurationHelper.isLapComplete(duration: newDuration, lap: state.lap, settingsState: settingsState)`.
  4. If complete: either automatically transitions to the next lap (`SettingsState.autoAdvance == true`) or stops the timer (`TimerStatus.stopped`) and prepares the next lap.
  5. Updates global persistent storage (`Prefs.duration = newDuration`) on each tick to guarantee resilience against unexpected restarts.

### B. `SettingsCubit` (`lib/pages/settings/cubit/settings_cubit.dart`)
- **State Object (`SettingsState`)**: Manages 30+ configuration properties including session durations (`workMinutes`, `shortBreakMinutes`, `longBreakMinutes`), lap counts (`lapCount`), theme preferences (`ThemeMode`, `colorSeed`), font selections (`TimerFont`, `timerCustomFont`), audio toggles (`enableSound`), and webhook URLs.
- **Persistence Synchronization**: All state mutations in `SettingsCubit` immediately write to local disk via `Prefs` (`lib/singletons/prefs.dart`), which wraps `SharedPreferences`. When `loadSettings()` is invoked during startup, `SettingsState` is reconstructed directly from disk.

---

## 3. Pure Logic Mixins (`lib/helpers/`)

To ensure maximum testability and clean separation from UI context, business logic is encapsulated in stateless helper mixins:

- `DurationHelper` (`duration_helper.dart`): Formats `Duration` into standard `MM:SS` or `-MM:SS` (`negativeFormat`) countdown strings. Computes fractional lap completion progress (`getProgress`) from `0.0` to `1.0`.
- `LapHelper` (`lap_helper.dart`): Implements `getNextLap(...)` to determine whether the upcoming lap after `lapNumber` should be `shortBreak`, `longBreak`, or `work` based on `SettingsState.lapCount`.
- `LapColorHelper` (`lap_color_helper.dart`): Maps `TimerLap` enum values to color representations used by UI themes and RGB webhook payloads.

---

## 4. Desktop Multi-Window Overlay & macOS Shell Architecture

When built for desktop (`macos`, `windows`, `linux`), `pomo` integrates with native OS windowing services (`window_manager`, `desktop_multi_window`, and custom Swift plugins):

### A. Main Window vs. Overlay Window
- **Main Window (`App`)**: The standard windowed interface containing the full Pomodoro timer and settings pages.
- **Floating Overlay (`OverlayApp` in `lib/desktop/overlay_app.dart`)**: Spawns when launched with `args.firstOrNull == 'multi_window'` in `main_development.dart` or `main_production.dart`. Displays a minimal, always-on-top countdown pill floating over fullscreen applications.
- **IPC Communication**: The main window and floating overlay synchronize state across process boundaries using `desktop_multi_window` message channels (`FloatingOverlayController` / `DesktopWindowService`). When the main timer ticks or pauses, updates are broadcast instantly to the overlay window.

### B. macOS Menu Bar (`MacosMenuBarService` in `lib/desktop/macos_menu_bar_service.dart`)
- On macOS, `Pomo.app` runs in background mode when the main window is closed.
- A custom native `NSStatusItem` (`macos/Runner/MenuBarPlugin.swift`) renders the status bar icon with quick actions (`Start/Pause`, `Reset`, `Settings`, `Show Main Window`, `Quit`).

### C. Desktop Notifications & Launch at Login
- **Notifications**: `LocalNotificationService` (`flutter_local_notifications`) shows hourly check-in and lap-complete alerts. Gating lives in `NotificationHelper`; taps route through `AppNavigationController`.
- **Launch at login**: `LaunchAtLoginService` (`package:launch_at_startup`) talks to a `launch_at_startup` MethodChannel in `MainFlutterWindow.swift`, which uses `SMAppService.mainApp` (macOS 13+). Login launches start as `.accessory` (menu bar only); opening the window restores `.regular` activation.
- **DMG**: `./build_macos_dmg.sh` builds the production flavor and packages an unsigned `Pomo.dmg`.

---

## 5. Audio & Sound System (`SoundHelper` & `generate-sounds.py`)

Audio feedback is handled through `SoundHelper` (`lib/helpers/sound_helper.dart`) using the `audioplayers` package (`^6.0.0`):

### Built-in Alert Assets
- The repository bundles custom audio assets in `assets/sounds/`:
  - `click.aac`, `pop.aac`, `ding_dong.aac`
  - `chime.wav`, `bell.wav`, `digital_beep.wav`
- **Asset Generation Script**: `scripts/generate-sounds.py` is a Python utility that mathematically generates clean, royalty-free WAV tones (`chime`, `bell`, `digital_beep`) using sine wave synthesis (`44100Hz`, 16-bit PCM).

### Playback Rules
When a lap starts or ends, `SoundHelper.play(...)` checks `SettingsState.enableSound`. If enabled, it resolves whether to play the built-in sound for the active `TimerLap` or a user-specified custom audio path (`customWorkStartSound`, `customShortBreakEndSound`, etc.).

---

## 6. Webhook Automation Engine (`HookHelper`)

A key capability of `pomo` is its ability to trigger external HTTP endpoints when timer events occur (`lib/helpers/hook_helper.dart`):

### Trigger Lifecycle
Whenever `TimerCubit` starts, stops, resets, or ticks, `HookHelper` inspects `SettingsState.enableWebHooks`. If active, it fires asynchronous HTTP requests (`dio`) to configured endpoints (`workStartWebHook`, `tickWebHook`, etc.). Multiple comma-separated URLs can be executed in parallel.

### JSON Payload Specification
On every webhook invocation, `HookHelper` transmits a JSON payload containing the RGB color array corresponding to the current lap's circular progress indicator:

```json
{
  "rgb": [
    255,
    0,
    156
  ]
}
```

### HomeAssistant Integration Example
This payload is specifically structured for smart-home home automation systems like HomeAssistant (`automation.yaml`):
```yaml
trigger:
  - platform: webhook
    webhook_id: "pomo-timer-tick"
action:
  - service: light.turn_on
    data:
      rgb_color: "{{ trigger.json['rgb'] }}"
      transition: 1
    target:
      entity_id: light.office_desk_bulb
```

---

## 7. Build Flavors & Entry Points

To maintain strict separation between local development, staging, and live production environments, `pomo` defines three flavors:

| Flavor | Target Entry Point | Purpose |
| :--- | :--- | :--- |
| `development` | `lib/main_development.dart` | Local debugging, verbose logging (`AppBlocObserver`), uncompressed assets. |
| `staging` | `lib/main_staging.dart` | Pre-release QA testing and staging API configurations. |
| `production` | `lib/main_production.dart` | Release builds (`build-web.sh`, `macOS .app`, `.apk`, `.deb`). |

Always ensure `--flavor` matches the target file prefix when running `flutter run` or `flutter build`.
