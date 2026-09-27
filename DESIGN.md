# Design and verification

- ID: `io.github.vip32.procyclingstats`, version 0.1.0.
- Hosted kinds: `bar-widget` (`BarWidget.qml`) and `service` (`Service.qml`).
- UI: native Omarchy `Panel`, `KeyboardPanel`, `BarIconButton`, `CursorSurface`;
  custom Canvas road bike and profile. Stochi informs the visual layout.
- Per-panel state: Today/Live filter, selected row, expanded state, scroll.
- Shared state: today's races, timestamped race snapshots, serialized fetch queue,
  request timestamps, cooldown and three most recently requested race pages.
- Settings: inline `refreshIntervalSec` in `shell.json`; no other durable state.
- Commands: `/usr/bin/python3 -I` with argument arrays, `/usr/bin/xdg-open` after URL
  validation. Python uses only its standard library. No shell interpolation.
- Network: HTTPS to `www.procyclingstats.com` only, same-origin redirects only.
  No credentials, privilege, remote code execution or challenge bypass.
- Limits: 2 MB per response while receiving, 18-second wall deadline, 60 races,
  12 groups, 220 profile points, 40 keypoints and 180 KB JSON output.
- Rendering: all external text uses plain text. CSS profiles become bounded
  numeric coordinates; embedded JSON is parsed, never evaluated as JavaScript.
- Failure states: loading, ready, empty, blocked, rate-limited, offline,
  unavailable, unsupported, error. Failed data fetches retain timestamped prior
  snapshots. Demo is explicit and clears live state on entry and exit.
- IPC service: `status`, `refresh`, `open`, `close`, `demo(bool)`.
- IPC panel: `.panel` target with `open`, `close`, `expand`, `compact`, `status`.
- Portable tests: homepage deduplication, nested yesterday exclusion, all key
  race metrics, zero vs missing values, no rider records, uncertainty, timezone,
  HTML challenge recognition, invalid URLs, redirect restriction, response cap,
  network failure distinctions, deadline and CLI injection handling.
- Observed on Omarchy 4.0.4-1: discovery, center placement, singleton lookup,
  live homepage and World Championships data, compact and expanded panels,
  course rendering, disable/enable and shell restart. The installed Qt parser
  accepts every QML file. Hot reload retained old QML once; restart resolved it.
- A cropped fictional preview was captured with `demo/run`; live fetching and
  the original workspace were restored. The demo preflight only recognizes the
  Bash wrapper as fixture-only; actual capture lives in `demo/capture.py`.
- Not yet verified: real vertical bar and multiple physical monitors. Icon
  geometry uses native orientation-aware BarIconButton; both share one service.
- Deferred: official API integration, all-day calendars beyond PCS's homepage,
  historical race browsing, team/rider pages, push notifications.
