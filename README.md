# ProCyclingStats for Omarchy

A compact road-cycling dashboard for the Omarchy Quattro bar. Follow the race
situation, time gaps and latest events without keeping a browser window open.

**Unofficial integration.** Not affiliated with or endorsed by ProCyclingStats.
Race coverage depends on the public data PCS makes available.

![Live race overview with fictional demo data](preview.png)

## Features

- **Yesterday, today and tomorrow:** results, current races and upcoming stages.
- **One race overview:** distance remaining, race time, average speed, groups and
  rider splits, latest events, course profile and the next published climb or sprint.
- **Finished races:** final results and the selected stage’s GC, with time gaps.
- **Race events:** attacks, sprints, dropped riders, abandonments and finish updates.
- **Your races:** 13 independent category checkboxes and a minimum race level.
  Choose ProSeries+ to hide Class 1 and Class 2 races. All categories and levels
  are included by default.
- **Optional notifications:** new events from followed races, with automatic expiry.
- **Honest connection status:** visible warnings, last-success timestamps and
  backoff when updates fail or PCS rejects access.

The bike icon sits in the center of the bar by default. Colors and typography
follow your Omarchy theme. Rider and team information appears only in race context.

## Screenshots

All screenshots show the actual plugin using committed fictional fixtures.

| Races | Categories and level |
| --- | --- |
| ![Date navigation and race list](screenshots/compact.png) | ![Race filters in Settings](screenshots/settings.png) |

| Finished-stage GC | Tomorrow’s preview |
| --- | --- |
| ![General classification](screenshots/gc.png) | ![Upcoming race information](screenshots/tomorrow-preview.png) |

[Race events](screenshots/events.png) · [Refresh and notifications](screenshots/refresh-settings.png)
· [Connection warning](screenshots/warning.png) · [Tomorrow’s list](screenshots/tomorrow-list.png)

## Requirements

- **Omarchy 4 Quattro.** Tested locally with Omarchy **4.0.4-1** and Qt **6.11.2**,
  on one Wayland laptop display. Other versions and multiple monitors are unverified.
- **Python 3**, standard library only, available as `/usr/bin/python3`.
- **xdg-utils** for `/usr/bin/xdg-open`, used only when opening PCS in your browser.
- Network access to `https://www.procyclingstats.com`.

No account or API key is required. The plugin reads public HTML; it does not use
PCS’s API or bypass browser challenges. See [data access and permissions](docs/data-access.md).

## Install

Until a public repository is published, install from this Git checkout:

```sh
omarchy plugin add /absolute/path/to/omarchy-procyclingstats --yes --enable
omarchy bar move io.github.vip32.procyclingstats --section center
```

After publication, the first argument can be the public GitHub repository URL.
The plugin ID is `io.github.vip32.procyclingstats`.

Update using the repository from which it was installed:

```sh
omarchy plugin update io.github.vip32.procyclingstats --yes
```

Omarchy normally reloads changes automatically. If QML remains cached, run
`omarchy restart shell`.

Disable or remove:

```sh
omarchy plugin disable io.github.vip32.procyclingstats
omarchy plugin remove io.github.vip32.procyclingstats --yes
```

Removal deletes the installed clone and its bar entry. Reinstalling uses default
settings and placement; preserve your widget entry first if you want to reuse it.
A separate source checkout and screenshots
exported by the developer demo remain yours. The plugin keeps no persistent race
cache, credentials or background service outside the shell.

## Use

Click the bike, choose a date, then select a race. Click a group to expand its
riders and bib numbers. Finished stages open on GC; switch to stage results when
needed. The header’s flag always returns to the race list; Live returns to today.

| Control | Action |
| --- | --- |
| Bike: left / right / middle click | Toggle dashboard / open PCS / refresh |
| Flag / `1` | Return to the full list for the selected date |
| Live indicator / `2` | Today’s live races |
| `←` / `→` in the list | Yesterday / today / tomorrow |
| Click the date | Return to today |
| `J` / `K` or `↓` / `↑` | Select a race or setting |
| Enter / click a race | Open its details |
| `T` in race details | Overview / race events |
| Header ↗ / `O` | Open the selected view on PCS |
| Gear / comma | Settings |
| `H` / `L` in Settings | Decrease / increase, uncheck / check |
| Enter in Settings | Toggle a category or adjust the selected setting |
| `R` | Refresh, respecting configured intervals and cooldowns |
| Esc | Back, then close |

Settings save automatically to the widget’s entry in `~/.config/omarchy/shell.json`.
See [filters, refresh intervals and notifications](docs/settings.md).

## Data limitations

PCS coverage varies by race. Missing metrics show an em dash; unavailable riders,
GC, events or profiles are labelled explicitly. Image-only profiles may require
opening PCS. Start-time text is shown as published, including its timezone; ETA
means expected finish. Race position is never extrapolated.

Blocked or rate-limited access triggers a 15-minute cooldown. Previous data stays
visible with its timestamp and warning. Changing HTML can require an adapter update.

## Development and support

Run `./tests/run` for portable validation and parser/model tests. QtTest adds
service tests when available. [Development and reproducible screenshots](docs/development.md)
describes the fictional demo and its restoration behavior.

Report reproducible issues through the Issues tab of the repository hosting this
checkout. Include the plugin version, Omarchy version, race URL and error shown;
omit private shell configuration. See [SECURITY.md](SECURITY.md) for sensitive reports.

[MIT license](LICENSE) · [Release notes](CHANGELOG.md) · [Submission preparation](docs/submission.md)
