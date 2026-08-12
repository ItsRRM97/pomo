# AGENTS.md - Pomo

Operating rules for AI agents in `pomo` (`github.com/recoskyler/pomo`).

**Sources of truth:** this file = agent operating rules; `CLAUDE.md` = topology & build; `ARCHITECTURE.md` = system design; `DESIGN.md` = approved product design (2026-07-13). Cursor always-on: `.cursor/rules/agent-guidance.mdc`.

## Product / purpose

Cross-platform Flutter Pomodoro + time tracker: work/break laps, sounds, RGB webhooks (HomeAssistant), Notion activity tags/sync, multi-window desktop / macOS menu bar, Android background ticks.

## Layout

| Path | Role |
|------|------|
| `lib/main_*.dart` | Flavor entry points (`development` / `staging` / `production`); `main.dart` is a stub |
| `lib/app/` | Root `App` / `AppView`, `MultiBlocProvider` |
| `lib/pages/` | Features: `timer`, `tracker`, `settings`, `tasks`, `about`, … |
| `lib/helpers/` | Pure logic (`DurationHelper`, `LapHelper`, `HookHelper`, …) |
| `lib/services/` | Platform / background (`TimerTickService`, notifications, …) |
| `lib/desktop/` | Multi-window shell, overlay, macOS menu bar |
| `lib/singletons/` | `Prefs` and shared singletons |
| `scripts/` | `setup.sh`, `verify.sh`, `build-web.sh`, … |
| `docs/superpowers/` | Process rails: specs, DESIGN gap matrix |
| `DESIGN.md` / `TODOS.md` | Product design SoT / backlog |

## Commands

```bash
./scripts/setup.sh
# or: flutter pub get && flutter gen-l10n

flutter run --flavor development -d macos --target lib/main_development.dart
./scripts/verify.sh
# inspect with rtk: rtk git status | rtk git diff | rtk grep "TimerCubit"
```

## Hard constraints

1. Always `--flavor` + `--target`; never treat `lib/main.dart` as the real entry.
2. Run `flutter pub get` + `flutter gen-l10n` (or `./scripts/setup.sh`) before analyze/test/build.
3. Prefix inspection shells with `rtk` where applicable.
4. No em dash (`U+2014`) in docs, comments, commits, or UI strings; use `-`, `:`, or `;`.
5. Keep helpers in `lib/helpers/` free of `BuildContext`; immutable Cubit states via `copyWith`.
6. Do not invent remotes, force-push, or commit unless the user asks.

## Agent workflow

1. Read this file + `README.md`; for architecture/product changes also `CLAUDE.md`, `ARCHITECTURE.md`, `DESIGN.md`.
2. Check `docs/superpowers/DESIGN-GAP-MATRIX.md` before scoping product work.
3. Process path: brainstorming → writing-plans → TDD → implement → `./scripts/verify.sh` → review/ship skills as needed.
4. Specs live under `docs/superpowers/specs/`; see `docs/superpowers/specs/2026-08-12-agentic-process-rails-design.md`.

## Secrets / local-only

- Never commit `.env`, `.env.*` (see `.gitignore`). Template: tracked `sample.env` (not `.env.example`).
- Do not commit credentials, personal Notion tokens, or local session dumps.

## Docs

- `README.md` - human product/install
- `CLAUDE.md` - detailed topology
- `ARCHITECTURE.md` - system design
- `DESIGN.md` - approved product design (2026-07-13)
- `TODOS.md` - open backlog
- `docs/superpowers/` - agent process rails + gap matrix
