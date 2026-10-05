# Settings

Open the gear in the dashboard header, or press comma. Changes save automatically
on this widget’s shell entry. The default is **all 13 categories** and **All levels**.

## Race categories

Each checkbox is independent; All and None provide quick selection controls.

| Code | Category | Separate TT checkbox |
| --- | --- | --- |
| ME | Men elite | ME (TT) |
| WE | Women elite | WE (TT) |
| MU | Men under 23 | MU (TT) |
| WU | Women under 23 | WU (TT) |
| MJ | Men junior | MJ (TT) |
| WJ | Women junior | WJ (TT) |
| ME+WE (TT) | Mixed team time trial | Already a TT category |

Time-trial matching uses explicit source labels such as ITT, TTT, time trial,
prologue and mixed relay. The plugin does not infer a race discipline from rider names.

## Minimum race level

| Selection | Included levels |
| --- | --- |
| All | Every published class, including unclassified races |
| Class 2+ | Class 2, Class 1, ProSeries and WorldTour |
| Class 1+ | Class 1, ProSeries and WorldTour |
| ProSeries+ | ProSeries and WorldTour |
| WorldTour | Men’s and women’s WorldTour |

The level applies to both one-day (`1.*`) and stage (`2.*`) races. ProSeries+
keeps `1.Pro`, `2.Pro`, `1.UWT`, `2.UWT`, `1.WWT` and `2.WWT`, while hiding
`1.1`, `2.1`, `1.2`, `2.2` and `2U` variants. Legacy HC is treated as ProSeries.

Championship codes (`WC`, `NC`, `CC`, `JC`, `JOJ`, `JR`, `OG`) remain eligible at
every threshold, subject to category checkboxes. Nations Cups and other unranked
classes require All. This is the dashboard’s filter policy, not a ranking of championships.

Filters apply to every date, Live, bar counts and event notifications. When a
filter is restricted, races missing the metadata needed by that filter are hidden.
The list shows an active-filter count and a specific no-matches message.

## Calendar list size

“Recent & upcoming race count” defaults to **25**, adjustable from **10 to 100**
in steps of 5. It saves automatically and applies to both calendar tabs.
“Show more” increases the current list only; reopening a tab uses the saved count.
Filters apply before the count. Sparse calendars may need “Search older/later races”.

## Refresh and notifications

| Setting | Default | Range |
| --- | --- | --- |
| Live races and events | 60 seconds | 60–900 seconds |
| Race list, including visited adjacent days | 5 minutes | 5–60 minutes |
| Finished results, GC and upcoming previews | 5 minutes | 5–60 minutes |
| Event notifications | Off | On / off |
| Notification duration | 8 seconds | 5–30 seconds |

Explicit refresh respects these intervals. Up to three recently selected races
stay warm while the shell is running. There is one shared poller, with independent
navigation per panel. Local midnight clears old watches and rejects old in-flight responses.

Notifications cover new events from today’s followed races that match the filters,
including while the panel is closed. First fetches, filter changes, re-enabling
notifications and long outages establish a baseline without replaying old events.
Each update groups at most three summaries plus a count into one notification.
Omarchy’s native notification service handles expiry and Do Not Disturb.
