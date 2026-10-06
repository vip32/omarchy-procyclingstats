# Changelog

## 0.12.0 — follow races and stages

- Pin race editions with a compact star; keep matching races first in lists and
  retain pins across reboots in the widget's existing settings.
- Navigate previous/next published stages without leaving details. Resolve each
  stage to results, live coverage or preview and retain spoiler protection.
- Show gaining/losing gap arrows only for fresh, comparable live groups against
  the same front group; omit uncertain, incomplete or stale comparisons.

## 0.11.3 — readable empty states

- Conceal only populated results and event lists. Keep loading, unavailable and
  unpublished messages readable, and show missing metrics as dashes.

## 0.11.2 — inline reveal control

- Place the eye button at the right of the Overview/Race events tabs. The tabs
  reclaim the full row when spoiler protection is off or the race is live.

## 0.11.1 — compact reveal control

- Replace the Reveal/Hide label with eye icons for hidden and visible results,
  retaining descriptive tooltips, accessible labels and the S shortcut.

## 0.11.0 — spoiler protection and remembered detail tabs

- Remember Overview/Race events across races and shell restarts.
- Add default-on spoiler protection for every finished race: obscure results,
  winner metrics and events until revealed, and suppress finished-race event
  notifications. Disable it in Settings to remove the reveal control entirely.
- Keep profiles and distances visible; hide results again on race changes and
  dashboard close. Use anonymous blurred rows to avoid leaking rider names.
- Shorten per-race link tooltips to “Open on PCS”.

## 0.10.3 — remember the calendar tab

- Remember Recent or Upcoming across navigation and shell restarts. The calendar
  button reopens the last selected tab; fictional demos do not change it.

## 0.10.2 — persistent course profiles

- Save successful course profiles and distances in an XDG disk cache for seven
  days, capped at 100 entries and 32 MiB. Restore locally before refreshing PCS.
- Preserve normal live polling and hourly course refreshes. Cached reads do not
  clear connection warnings or replace newer network data.
- Prune expired entries during cache access; reject damaged cache files and
  fall back to normal fetching if storage is unavailable.

## 0.10.1 — consistent inline profiles

- Draw the same theme-coloured line and fill for image-only courses by tracing
  the published green elevation silhouette. Use native PCS coordinates first;
  keep the original image when no reliable outline can be found.
- Reuse a bounded trace cache and keep profile rendering compact in lists,
  finished-race details and upcoming previews. Traced outlines are visual
  approximations, not GPS or elevation measurements.
- Fill missing live total distance from published kilometres covered/remaining,
  and retain known course distance across partial live updates.

## 0.10.0 — profiles and distances across race lists

- Show published course thumbnails and kilometres for visible past, current and
  upcoming races, with full elevation images in the details view. GC entries
  identify the stage represented by the profile and distance.
- Reuse live vector profiles; accept bounded PCS PNG/JPEG images as a fallback.
  Fetch only visible rows through the shared worker and keep a bounded cache.
- Remove the calendar search-summary line and count-to-settings shortcut.
  The saved count remains in Settings.

## 0.9.1 — compact lists and precise warnings

- Reduce race-row height and padding; reclaim unused mini-profile space for names.
- Load GC course profiles and events from the published stage link, avoiding
  invalid aggregate-GC LiveStats endpoints.
- Identify optional-data failures separately from a live connection failure,
  show the underlying error, and retain visible shared cooldowns.

## 0.9.0 — race calendar

- Browse recent and upcoming races beyond yesterday/tomorrow, with existing
  category and level filters, dated rows and links to results or previews.
- Save the default calendar count in Settings: 25 races, adjustable from 10–100.
  Show more temporarily expands the list; bounded searches display date coverage.
- Share serialized requests and failure warnings with the live dashboard.
- Read current PCS flattened race links, race information and GC/results tabs.

## 0.8.1 — submission candidate

- Show finished-race distance, winner time, average speed and available course
  profile above results and GC, in both popup and detached window.
- Prefer published result metrics over the live clock; retrieve missing profile
  geometry from LiveStats and preserve cached profiles with visible failure warnings.

## 0.8.0 — window support

- Pop the dashboard out into a normal tiled desktop window and dock it back with
  the header button or `P`, retaining the existing view and rider expansion state.
- Reuse one detached window and one polling service; clicking the bike focuses
  the window across workspaces, or reopens it after a desktop close.
- Add native window lifecycle checks and a reproducible window screenshot.

## 0.7.0 — initial candidate

First prepared marketplace candidate; not yet published or tagged.

- Center-bar race-bike widget with a compact live race overview, rider groups,
  time gaps, race events and course profile.
- Yesterday/today/tomorrow navigation, selected-stage GC and upcoming race previews.
- A direct PCS link on every race row, alongside the header’s current-view link.
- Thirteen category checkboxes and a minimum race level, all included by default.
- Configurable refresh intervals and optional expiring event notifications.
- Visible connection warnings, bounded requests, cached snapshots and retry backoff.
- Deterministic fictional screenshots, read-only demo settings and reversible capture.

Tested on Omarchy 4.0.4-1 with Qt 6.11.2. See the local candidate record and
[submission notes](docs/submission.md) for validation scope and remaining publication steps.
