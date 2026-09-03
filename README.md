# BusBar

A macOS **menu bar** app that shows the next arriving bus for your closest saved stop.
Click it for a list of upcoming arrivals and to configure stops. Powered by the
[Transitland](https://www.transit.land) API, so it works for transit agencies worldwide —
built with Princeton (TigerTransit + NJ Transit) as the primary use case.

The menu bar shows `route · minutes · stop`, e.g. `606 · 17m · Nassau`.

## Features

- Track one or more stops; the app shows the **closest** one (via your location).
- Per-stop **route filtering** — hide lines you don't care about.
- **Live** predictions where the agency publishes GTFS-Realtime (e.g. NJ Transit); a `sched`
  badge marks schedule-only feeds (e.g. TigerTransit, whose realtime lives in TripShot).
- Menu-bar-only (no Dock icon), refreshes every ~45s.
- Optional **launch at login** (Settings → General).

## Requirements

- macOS 13+
- A Swift toolchain (Xcode or Command Line Tools)
- A free **Transitland API key** — sign up at [transit.land](https://www.transit.land)

## Build & run

```bash
make bundle        # builds BusBar.app
open BusBar.app    # launch it (look for the text in your menu bar)
```

On first launch, click the menu bar item → **Settings…**:

1. **API Key** tab — paste your Transitland key.
2. **Stops** tab — **Find stops near me** (grant location access), or paste a stop **Onestop ID**
   (e.g. `s-dr4vw0dtyh-forrestalsb`). Use **Routes…** to hide specific lines per stop.

### Development

```bash
make run       # build the bundle and launch it (loads .env automatically)
make selftest  # headless check: prints live arrivals for two Princeton stops
```

`.env` (git-ignored) may contain `TRANSITLAND_API_KEY=…` for development only. The app always
prefers a key entered in Settings; the `.env` key is just a fallback so you don't have to type
it while iterating. **Never commit `.env`.**

## How it works

- `TransitProvider` (protocol) → `TransitlandProvider` calls `/stops/{id}/departures`, which
  merges timetable + realtime. `isRealtime` is true when the feed returns an estimate.
- `ArrivalStore` polls every configured stop, applies per-stop route filters, picks the closest
  active stop, and produces the menu-bar string.
- Realtime for a schedule-only agency (like TigerTransit) can later be added by writing a new
  `TransitProvider` (e.g. a TripShot/Swiftly adapter) — nothing else needs to change.

## Layout

```
Sources/BusBar/
  main.swift, BusBarApp.swift        app entry, scenes, AppDelegate
  Models/         TransitModels, AppConfig (persistence)
  Services/       TransitProvider, TransitlandProvider, LocationManager, Env
  ViewModel/      ArrivalStore (polling + menu label)
  Views/          DropdownView, SettingsView, StopEditorView
```

## License

[MIT](LICENSE). BusBar depends only on Apple system frameworks; transit data comes from the
Transitland API (subject to Transitland's own terms of use).
