# Design and verification

- ID: `io.github.vip32.procyclingstats`, version 0.4.5.
- Hosted kinds: `bar-widget` (`BarWidget.qml`) and `service` (`Service.qml`).
- UI: native Omarchy `Panel`, `KeyboardPanel`, `BarIconButton`, `CursorSurface`;
  custom Canvas road bike and profile. Stochi informs the visual layout.
- Per-panel state: Races/Live filter, selected row, expanded state, scroll.
- Shared state: today's races, timestamped race snapshots, serialized fetch queue,
  request timestamps, cooldown and three most recently requested race pages.
- Settings: live/list/results intervals, notification toggle and expiry saved inline
  in `shell.json` through the scoped host API; no parallel settings store.
- Commands: `/usr/bin/python3 -I` with argument arrays, `/usr/bin/xdg-open` after URL
  validation. Native notifications use `/usr/bin/omarchy notification send` with
  bounded, prefixed positional data, escaped body markup and explicit expiry.
  Python uses only its standard library. No shell interpolation.
- Network: HTTPS to `www.procyclingstats.com` only, same-origin redirects only.
  No credentials, privilege, remote code execution or challenge bypass.
- Limits: 2 MB per response while receiving, 18-second wall deadline, 60 races,
  12 groups with up to 30 named riders each, two classifications of up to
  200 rows, 60 events with 900-character text, 220 profile points, 40 keypoints
  and 180 KB JSON output. All requests share the 18-second operation deadline.
- Rendering: all external text uses plain text. CSS profiles become bounded
  numeric coordinates; embedded JSON is parsed, never evaluated as JavaScript.
- Failure states: loading, ready, empty, blocked, rate-limited, offline,
  unavailable, unsupported, error. Failed data fetches retain timestamped prior
  snapshots. Demo is explicit and clears live state on entry and exit.
- IPC service: `status`, `refresh`, `open`, `close`, `demo(bool)`.
- IPC panel: `.panel` target with `open`, `close`, `expand`, `compact`, `status`.
- Portable tests: homepage deduplication, nested yesterday exclusion, all key
  race metrics, zero vs missing values, group riders and bibs, uncertainty, timezone,
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
- Rider names are scoped to live race groups; splits are group gaps to the front,
  never the unrelated per-rider GC deficits in the source HTML.
- Finished stage views default to the stage page’s explicitly labeled GC tab.
  Stage and one-day results are labeled separately; missing GC stays explicit.
- 30 tests pass, including live-to-finished transitions, partial results failure,
  correct tab selection, same-time markers and rider limits. Checked real CRO Race
  GC and Paris-Chauny final results, plus saved live groups with named riders.
  Observed the live CRO Race GC panel with 103 rows, and captured both fictional
  rider-group and GC views. Demo exit restored live mode and the previous view.
- Race events come from the dedicated `/live/race-events` endpoint. Parse only
  the event body and marker, excluding timers, page navigation and scripts.
  Keep source order, deduplicate exact marker/body matches, and bound the feed.
- Events failures preserve successful race data and timestamped prior events;
  source blocks/rate limits still trigger the shared cooldown.
- 37 tests pass, including event ordering, finish markers, long rider lists,
  deduplication, size limits, script stripping and partial events failure.
- Live-shell verification: the World Championships event tab displayed 60
  source events, newest first, with distance markers and wrapped plain text.
  Captured a fictional event preview and restored live mode and prior view.
- Deferred: official API integration, all-day calendars beyond PCS's homepage,
  historical race browsing, team/rider pages.

- Connection issues are tracked separately for the homepage, each race, events
  and results. Unrelated success cannot clear an issue. A persistent banner and
  urgent bar badge show stale-data risk, last successful fetch and retry timing.
- One 15-second scheduler tick applies independent bounded intervals; requests
  remain serialized and respect the shared block/rate-limit cooldown.
- Notifications are opt-in, deduplicated by marker and text, and baseline on first
  fetch, re-enable, restart or long outage. At most one bounded notification per
  race per poll. Memory is bounded to recent watched races and 180 event keys.
- Current tests: 37 Python parser tests, 14 JavaScript model tests, and 6 QtTest
  service scenarios (plus setup/cleanup) pass. QtTest stubs processes and native
  notification execution; it does not claim real shell integration.
- Observed live: keyboard edits persisted all five settings through the host API;
  a native fictional notification requested 7000 ms, appeared on screen and moved
  to Omarchy history after 7.1 seconds without manual dismissal.
- Settings survived a shell restart. Verification restored default intervals
  (60/300/300 seconds), notification duration (8 seconds), and notifications off.
  Fictional settings and warning previews were captured; normal data fetching resumed.
