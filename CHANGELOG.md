# Changelog

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
