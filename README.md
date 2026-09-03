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

- macOS 13+ (Ventura or later)
- A free **Transitland API key** (see below)

## Get a Transitland API key

BusBar uses [Transitland](https://www.transit.land) for transit data, which needs a free key:

1. Create a free account at [transit.land sign-up](https://www.transit.land/documentation#sign-up).
2. Once signed in, copy your **API key** from your account page.
3. Paste it into BusBar under **Settings → API Key** on first launch.

The free tier is plenty for personal use — BusBar only polls your saved stops every ~45s.

## Install

### Option A — download a release (recommended)

1. Download `BusBar-<version>-macos.zip` from the
   [**Releases** page](https://github.com/abhaybd/BusBar/releases/latest).
2. Unzip it and drag **BusBar.app** into `/Applications`.
3. The app isn't notarized by Apple, so clear the quarantine flag once (otherwise macOS refuses
   to open it):
   ```bash
   xattr -dr com.apple.quarantine /Applications/BusBar.app
   ```
   (Alternatively: right-click **BusBar.app → Open → Open**, or allow it under
   **System Settings → Privacy & Security → Open Anyway**.)
4. Launch BusBar from Spotlight/Finder — look for the bus icon in your menu bar.

### Option B — build from source

Requires a Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

```bash
make install   # builds BusBar.app and copies it to /Applications
```

Or `make run` to build and launch it in place without installing.

## First launch

Click the menu bar item → **Settings…**:

1. **API Key** tab — paste your Transitland key.
2. **Stops** tab — **Find stops near me** (grant location access), or paste a stop **Onestop ID**
   (e.g. `s-dr4vw0dtyh-forrestalsb`). Use **Routes…** to hide specific lines per stop.

Enable **Settings → General → Launch at login** to start BusBar automatically. (This registers
whichever copy is running, so install to /Applications first, then toggle it on.)

## Development

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
