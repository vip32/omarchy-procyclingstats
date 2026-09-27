# ProCyclingStats for Omarchy

A road-bike icon in the center of the Omarchy Quattro bar. Click it for today's
professional road cycling races, then select a race for its LiveStats overview.

- Today and Live filters, including women's and men's races.
- Distance remaining and covered, elapsed race time, average speed and start time.
- Course profile with the current race position.
- Race situation: front group, chasing groups and peloton, with rider names, bibs
  and each group’s time gap to the front.
- Finished stages open on GC, with a separate stage-results tab. Finished one-day
  races show final results. Winner/leader time and gaps are included; show the
  top 10 or expand the full classification (up to 200 rows).
- Race-events tab for attacks, dropped riders, abandonments, sprints and finish
  updates, newest first with distance-to-go markers. Shows the latest 15 with
  an option to expand to 60; also available after the race finishes.
- Upcoming climbs and sprints.
- Stochi-inspired bordered rows, compact/expanded panels and native theme colors.
- One shared poller across monitors. Per-panel navigation and selection.
- Settings screen for refresh intervals and optional, auto-closing race-event notifications.
- Persistent connection warning and bar badge when updates fail or PCS rejects requests.

![Fictional demo of the race overview](preview.png)

[Settings preview](screenshots/settings.png) · [Connection warning preview](screenshots/warning.png)

An independent, unofficial integration. Race data belongs to
[ProCyclingStats](https://www.procyclingstats.com/). Riders appear within race situations and classifications; there is no separate
team or rider browsing.

## Requirements and data access

Omarchy 4 Quattro, Python 3 (standard library only), and `xdg-open` to open PCS.
No API key, paid service, browser automation or extra Python packages.
The adapter reads the public PCS homepage, `/race/.../live`, stage results and
`/race/.../live/race-events` HTML.
PCS's [official API](https://www.procyclingstats.com/info/api) is available by
request; its public page does not advertise a free tier. This plugin uses HTML,
not that API.

Network verification on 2026-09-27 succeeded for today's six races and the live
World Championships. An earlier plain curl request returned Cloudflare HTTP 403;
access may vary. Blocked access and rate limits are displayed explicitly, with a
15-minute cooldown. This plugin does not solve or bypass challenges. Open PCS
in the browser when automatic access is unavailable.

Live race pages refresh every 60 seconds by default. The homepage refreshes every
5 minutes. The Settings screen (gear button or comma key) controls live updates
(60–900 seconds), the race list (5–60 minutes), finished results (5–60 minutes),
and notification duration (5–30 seconds). Changes save automatically to this
widget’s entry in `shell.json`. Explicit refresh respects these intervals. Up to three
recently selected races stay warm; requests are serialized, capped at 2 MB, and
have an 18-second total deadline. Finished results refresh every 5 minutes.
GC is read from the selected stage’s own GC tab, not a guessed final standings
page. If PCS has not published GC or group members, the panel says so. Missing metrics show an em dash. Race events refresh with the race snapshot. A failed events request keeps the
previous events with their own timestamp and error, while race metrics and GC
remain usable. Previous data
remains visible with an error and its timestamp after a failed refresh. Source
snapshot timestamps are used where available; the position is never extrapolated.

Failed updates show a warning badge on the bike and a banner pinned above the
scrolling content. It identifies the affected source, last successful fetch and
retry countdown. A failure stays visible during retries and clears only when that
source recovers; an unrelated successful request cannot hide it. Missing optional
coverage is shown in the relevant tab without claiming a connection failure.

Race-event notifications are off by default. Enable them in Settings for up to
three recently opened races, including while the panel is closed. The initial
fetch after enabling or restarting establishes a baseline without replaying the
backlog. Only new events notify; each poll groups them into one notification per
race (three event summaries plus a count). After a long outage, the baseline
resets. Notifications use Omarchy’s native service with an explicit expiry and
respect Do Not Disturb. The Settings screen includes a fictional test notification.

## Install this checkout

```sh
omarchy plugin add /absolute/path/to/omarchy-procyclingstats --yes --enable
omarchy bar move io.github.vip32.procyclingstats --section center
```

The local installation clones this repository. After committing changes here:

```sh
omarchy plugin update io.github.vip32.procyclingstats --yes
```

Omarchy normally hot-reloads changes. If QML remains cached, `omarchy restart shell`
loads the updated code. No separate Quickshell instance or background daemon.

To disable or remove:

```sh
omarchy plugin disable io.github.vip32.procyclingstats
omarchy plugin remove io.github.vip32.procyclingstats --yes
```

The plugin creates no persistent runtime cache or credentials. Removing the
installed clone leaves the development checkout untouched.

## Controls

| Input | Action |
| --- | --- |
| Left click bike | Open or close today's races |
| Right click bike | Open PCS in browser |
| Middle click bike / R | Refresh, subject to cooldown |
| Click race / Enter | Expand race overview |
| J/K or arrows | Select race |
| E | Toggle compact/expanded view |
| T | Switch between Overview and Race events |
| O | Open the current race view on PCS |
| Gear / comma | Open Settings |
| H/L in Settings | Decrease/increase selected setting |
| Esc | Back to list, then close |

Set `refreshIntervalSec` directly on the bar entry (60–900 seconds):

```json
{ "id": "io.github.vip32.procyclingstats", "refreshIntervalSec": 60 }
```

## Development

Portable tests require Python 3 and Node.js (18+). QtTest, when installed, also
exercises the service with stubbed processes and notifications.

```sh
./tests/run
python3 -I bin/pcs.py overview
python3 -I bin/pcs.py race --race race/world-championship/2026/result
python3 -I bin/pcs.py race --race race/tour-of-croatia/2026/stage-6 --finished
python3 -I bin/pcs.py race --race race/example/2026/result --html saved-page.html
omarchy-shell io.github.vip32.procyclingstats status
omarchy-shell io.github.vip32.procyclingstats.panel status
omarchy-shell io.github.vip32.procyclingstats.panel events
```

`--html` is an explicit offline parser diagnostic. Its output is marked
`savedPage: true`; it is never loaded automatically into the live widget.

The deterministic demo is opt-in through `omarchy-shell io.github.vip32.procyclingstats
demo true` and is visibly labeled fictional. `demo false` clears all fixtures and
returns to normal fetching. `demo/run` captures a cropped preview and restores
normal operation; see its `--help`.

Parser selectors were checked against the public saved HTML in
[victorsmits/pcs](https://github.com/victorsmits/pcs/tree/main/tests/fixtures/pcs)
and against live PCS responses. Third-party archived pages are not distributed
with this project. Tests use small synthetic pages and fictional races.
