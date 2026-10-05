# Data access and permissions

The adapter reads public HTTPS HTML from `www.procyclingstats.com`: the homepage,
date-specific UCI road calendar, normal race/result pages, `/live` and
`/live/race-events`, and race-linked PNG/JPEG files under `images/profiles/`. It does not authenticate, use a paid API, open hidden browser
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
| Course cache write | Successful public profiles and distances only, under the XDG cache directory; seven-day retention, 100 entries / 32 MiB maximum |

Runs with your normal user permissions. No separate daemon, service installation,
credentials, analytics or automatic package installation is used.

Network requests are serialized. A separate local-only helper reads cached
profiles without waiting for network responses or cooldowns. HTML is limited to 2 MB, the parser to 60,000 nodes,
output to 512 KB, and each helper invocation to an 18-second total deadline.
Finished results read distance and winner average from race information and the
winner time from that race or stage’s result table. If the results page lacks
profile geometry, one bounded `/live` request retrieves it without using its clock.
For an aggregate GC page, optional profile/events requests follow its explicit
Stage tab within the same race/year; no `/gc/live` endpoint is guessed.
Images are fetched by the same Python adapter, with the actual race page as the
HTTP Referer, then passed as inline data to QML. There are no direct QML network
requests. Images are capped at 256 KB, 4096 × 2048 and 4 million pixels; SVG and
other formats are rejected. Native PCS coordinates take precedence. The UI can trace the green silhouette
of a profile image at a bounded 480 × 240 resolution to draw an inline graph.
This is a visual approximation, not recovered GPS/elevation measurements.
Ambiguous images retain their original image view; up to 40 outlines are cached. A rejected profile request retains
results and triggers the same shared cooldown and warning as other update failures.

Only visible rows request course data (up to 40); requests remain serialized.
The in-memory course cache holds at most 40 entries and refreshes hourly while
visible, or after five minutes for failures, subject to the shared cooldown.
Closing the view cancels queued course work; an in-flight request may finish.
Successful course data also lives under
`${XDG_CACHE_HOME:-~/.cache}/omarchy-procyclingstats/courses-v1` for seven days
from its last successful fetch. Access removes expired entries and evicts the
oldest beyond 100 entries or 32 MiB; reading a cache entry does not extend its
retention. Each file is capped at 384 KB. No maintenance daemon is needed.
Profiles restore before network refreshes, including during a provider cooldown.
Cached reads preserve the original fetch timestamp and cannot clear warnings or
replace newer profiles. Profiles older than one hour refresh normally while
visible; race results, gaps, events and live timings are never stored on disk.

Cache entries contain validated native coordinates or the original bounded
PNG/JPEG, distance and stage label. Image outlines are retraced once after restart
and then reused from memory. Entries are schema/path/image-validated on read;
corrupt, expired or unreadable data falls back to normal fetching. The helper uses
private directories and files, a nonblocking local lock, descriptor-relative
entry IO, no-follow opens and atomic replacement. Failed writes preserve existing
entries and do not turn a successful PCS response into a connection failure.
Fictional demos and offline `--html` parsing never populate this cache. Removing
the plugin leaves this disposable cache; it can be deleted independently.

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
Optional profile/event failures name the affected data instead of claiming all
live updates are unavailable. Missing optional coverage is not a connection error.
Event and metadata failures retain their own last-success timestamps and warnings;
an unrelated successful request cannot clear them. Optional missing coverage is
shown in the relevant view. These controls are not a guarantee of uninterrupted data.

The fixture demo is explicit and labelled. It pauses real polling and notifications,
uses fictional committed data and read-only default settings, then returns to the
user’s saved preferences. The screenshot harness writes its requested PNG and a
private temporary recovery directory; successful restoration removes the latter.

Race data belongs to its respective providers. The repository distributes synthetic
HTML fixtures and fictional race data, not captured PCS pages. See [asset provenance](assets.md).
