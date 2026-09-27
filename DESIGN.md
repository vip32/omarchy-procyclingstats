# Architecture

`io.github.vip32.procyclingstats` is one root Omarchy Quattro plugin with a
bar-widget and shared service. Version 0.7.0 is the first submission candidate.

- `BarWidget.qml` owns panel navigation, local selection and the shell-hosted
  Settings page. Configuration is saved through the host’s widget-entry API.
- `Service.qml` owns serialized polling, bounded request queues, three watched
  races, date-keyed caches, cooldowns and notification baselines across panels.
- `bin/pcs.py` is a standard-library HTML adapter. Every process receives an
  argument array. See [data access](docs/data-access.md) for actual bounds.
- `Model.js` holds testable settings normalization, filters, failure tracking,
  calendar arithmetic, next-course-point selection and event deduplication.
- Small QML components render race groups, profile, results, events and previews
  with native shell theme tokens. There is no standalone shell or daemon.

Today joins homepage live records with the date-specific UCI road table.
Adjacent days have independent caches. A request is associated with its start
calendar day; local midnight rejects old responses and clears old watches.
Calendar winner links determine whether published results can be requested.

Category/level filters operate on cached records, so changing them requires no
extra network request. Unknown metadata is preserved with default settings and
excluded only when a restricted filter requires it. Metadata and events have
independent failure warnings and last-success timestamps. Partial failures retain
known values without presenting them as freshly retrieved.

Finished stages request the selected stage’s own GC. Upcoming races read the
normal race page without fetching old event history. Rider data has no standalone
browsing surface. Profiles and race positions are displayed only from source data.

Explicit fictional demo mode pauses polling and notifications and binds the UI to
read-only defaults. Its capture harness restores normal configuration-backed
preferences and panel state. Fixtures are not fallback live data.
