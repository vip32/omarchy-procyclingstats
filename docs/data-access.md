# Data access and permissions

The adapter reads public HTTPS HTML from `www.procyclingstats.com`: the homepage,
date-specific UCI road calendar, normal race/result pages, `/live` and
`/live/race-events`. It does not authenticate, use a paid API, open hidden browser
sessions or attempt challenge bypass. The provider can block access or change its markup.

| Capability | Purpose and boundary |
| --- | --- |
| Python process | `/usr/bin/python3 -I` runs the committed `bin/pcs.py` with an argument array; no shell command interpolation |
| HTTPS | Only the fixed PCS origin; redirects outside that HTTPS origin are rejected |
| Browser launch | `/usr/bin/xdg-open` receives a validated PCS URL after a user action |
| Notifications | `/usr/bin/omarchy notification send`, only when enabled; bounded, escaped remote text |
| Settings write | The shell updates this widget’s entry in `~/.config/omarchy/shell.json` when the user changes settings |
| Window focus | Wayland toplevel metadata locates the dashboard by title and activates it when the user opens it; Qt activation is the fallback |
| Runtime state | Race snapshots, day lists and notification baselines live in memory and clear on restart |

Runs with your normal user permissions. No separate daemon, service installation,
credentials, analytics or automatic package installation is used.

Requests are serialized. HTML is limited to 2 MB, the parser to 60,000 nodes,
output to 180 KB, and each helper invocation to an 18-second total deadline.
Finished results read distance and winner average from race information and the
winner time from that race or stage’s result table. If the results page lacks
profile geometry, one bounded `/live` request retrieves it without using its clock.
Image-only profiles still require opening PCS. A rejected profile request retains
results and triggers the same shared cooldown and warning as other update failures.

The calendar searches on demand in batches of three dates, using the same worker
and cooldown. Each user action scans at most 30 dates and stops once enough
matching races are found. “Search older/later races” continues from the next date.
Each tab retains at most 366 searched dates and 1,000 race records per session.
Closing the dashboard or opening details stops further batches; an in-flight batch
may finish and populate the cache. There is no separate archive polling loop.
A failed batch retains completed pages and retries at the first unread date.
Calendar refresh restarts the search, at most once per minute.

Race paths are validated, fields are bounded, and Python isolated mode avoids
loading user-site modules. Remote HTML is parsed into plain text, never executed.

A rejected or rate-limited request produces a visible warning and a shared
15-minute cooldown. Failed primary requests retain the previous snapshot.
Event and metadata failures retain their own last-success timestamps and warnings;
an unrelated successful request cannot clear them. Optional missing coverage is
shown in the relevant view. These controls are not a guarantee of uninterrupted data.

The fixture demo is explicit and labelled. It pauses real polling and notifications,
uses fictional committed data and read-only default settings, then returns to the
user’s saved preferences. The screenshot harness writes its requested PNG and a
private temporary recovery directory; successful restoration removes the latter.

Race data belongs to its respective providers. The repository distributes synthetic
HTML fixtures and fictional race data, not captured PCS pages. See [asset provenance](assets.md).
