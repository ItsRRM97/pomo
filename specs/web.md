# Web PWA

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/services/web_pwa_service*.dart`, `deploy/`, `scripts/build-web.sh`

---

## Purpose

Same Flutter tabs in Chrome / installed PWA. No macOS menu bar, no Android FGS, no exact `AlarmManager`.

## Run and build

```bash
flutter run --flavor development -d chrome --target lib/main_development.dart
./scripts/build-web.sh
```

Release output is the static/PWA tree used for Vercel (or similar). Flavor + target still required.

## Notifications and PiP

`WebPwaService` (web impl vs stub):

- Notification permission + `showNotification` for lap / hourly copy when the page can show them.
- Optional Document Picture-in-Picture for a mini timer (`openPip` / `updatePip`).
- Service worker notification helper for installed PWA.

Hourly reminders only fire while the tab/worker is allowed to run; there is no OS exact-alarm equivalent.

## Notion from the browser

Direct Notion API is typically blocked by CORS. Settings `notionProxyUrl` (e.g. `/api/notion/`) points at the deploy proxy. Access code / token still stored in Prefs (local only).

## Shared data with desktop/Android

Hourly logs and activity tags sync through the Hourly Timeline database when Notion sync is configured. Open or reload each client after an update so tag registry + pull can converge.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped web spec |
