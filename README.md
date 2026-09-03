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

### Install to /Applications

```bash
make install   # builds BusBar.app and copies it to /Applications
```

Then launch it from Spotlight/Finder. Enable **Settings → General → Launch at login** to have
it start automatically. (Launch-at-login registers whatever copy is running, so install to
/Applications first, then toggle it on.)

### Development

```bash
make run       # build the bundle and launch it (loads .env automatically)
make selftest  # headless check: prints live arrivals for two Princeton stops
```

## Distributing via GitHub Releases

```bash
make release   # -> BusBar.app (universal arm64+x86_64, signed) + BusBar-<version>-macos.zip
gh release create v0.1 BusBar-0.1-macos.zip --title "BusBar 0.1" --notes "First release"
```

`make release` builds a **universal** binary (Apple Silicon + Intel), ad-hoc signs it, and zips
it with `ditto` (preserving the signature) as the release asset.

**Gatekeeper caveat.** An ad-hoc-signed app isn't notarized by Apple, so anyone who *downloads*
the zip must clear the quarantine flag before first launch:

```bash
xattr -dr com.apple.quarantine /Applications/BusBar.app
```

(or right-click the app → **Open** → **Open**, then use *Open Anyway* in System Settings →
Privacy & Security). Document this in your release notes. This only affects downloaded copies —
the app you build locally runs without it.

**Notarized (no Gatekeeper prompt).** Needs a paid Apple Developer account. With a Developer ID:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make release
xcrun notarytool submit BusBar-0.1-macos.zip \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-pw> --wait
# after it succeeds, staple the ticket into the app and re-zip:
xcrun stapler staple BusBar.app
ditto -c -k --sequesterRsrc --keepParent BusBar.app BusBar-0.1-macos.zip
```

Stapled builds run with no quarantine prompt on any Mac.

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
