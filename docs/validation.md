# Validation

## 0.9.1 fixes — 2026-10-05

- Reproduced HTTP 500 at Langkawi `/gc/live`, while its stage endpoint responds.
  Updated adapter returns 108 GC rows with optional profile/events marked
  unavailable, without an HTTP 500 warning.
- `PCS_REQUIRE_QT=1 tests/run`: 117 behavioral tests (61 Python, 35 JavaScript,
  21 Qt service cases), native manifest validation and QML parsing.
- Added checks for explicit same-race stage routing, absent/foreign links,
  optional-warning titles, shared cooldown and primary-failure priority.

## 0.9.0 calendar update — 2026-10-05

- `PCS_REQUIRE_QT=1 tests/run`: 111 behavioral tests (58 Python, 32 JavaScript,
  21 Qt service cases), manifest validation and QML parsing.
- Live PCS calendar: recent and upcoming batches returned correctly dated races.
  The native Recent screen reached 25 matching races across 18 searched dates;
  selecting Coppa Agostoni opened 149 result rows. Langkawi returned 108 GC rows,
  109 stage-result rows, 188.3 km and winner time 4:05:17.
- Native Settings: changed count from 25 to 30 with the keyboard, checked the
  saved shell entry, reopened the calendar at 30, and restored the original
  setting. Existing categories, level and notifications were preserved.
- Fictional Recent, Upcoming, historical GC and Settings captures inspected.
  Historical selection survived tiled window open, resize, native close/reopen
  and docking. Demo cleanup restored live polling and desktop state.
- The marketplace approval below applies to 0.8.1; this update has not been
  submitted for a new marketplace verification.

## Previous 0.8.1 candidate evidence

Candidate: version **0.8.1**, prepared **2026-09-27**. Exact final source identity
and raw local reports are in `.git/submission-candidate/` of the preparation checkout.

| Check | Evidence / scope |
| --- | --- |
| Portable suite | 98 behavioral tests: 53 Python, 28 JavaScript, 17 QtTest service cases |
| Native manifest validation | `omarchy plugin validate .` on Omarchy 4.0.4-1 |
| QML syntax | Qt 6.11.2 `qmlformat` parses the production QML files |
| Advisory static review | No reported security findings; collected process output and process execution require human capability review |
| Process boundary review | Isolated Python; argument arrays; fixed HTTPS origin; producer-side byte/node/output limits; total deadline; serialized requests; validated race paths |
| Live race data | Today’s six races enriched with category and class; yesterday’s CRO stage GC returned 104 riders and race events; tomorrow’s preview returned start, distance and route |
| Local installation/update | Installed from the Git checkout, updated, removed and freshly reinstalled at the production-code commit; shell IPC and native panel exercised |
| Detached window | One tiled instance, repeated open, cross-workspace activation, floating/tiled resize, desktop close/reopen, docking, P shortcut, retained race/date/tab/GC/settings view and nonzero settings scroll checked with fictional data |
| Finished-race summary | CRO stage 6 returned 159.5 km, winner time 3:14:57, average 49.1 km/h and 219 profile points; fictional stage GC and one-day summaries visually checked in popup and window |
| Filters | Native settings screenshot reviewed; saved filter values checked against the matching shell entry. Automated matching, partial-failure and notification scope tests passed |
| Demo captures | Native fixture-only screenshots, with normal fetching/preferences/workspace/cursor restored after capture; a forced screenshot-write failure also restored normal operation |

## Limits and remaining gates

- Local display evidence covers one laptop monitor on Omarchy 4.0.4-1 / Qt 6.11.2.
  Multi-monitor and vertical-bar behavior are implemented but not covered by this run.
- [Hosted GitHub Actions](https://github.com/vip32/omarchy-procyclingstats/actions/workflows/test.yml)
  reports validation for each pushed commit. The Qt test job is configured to fail
  rather than silently skip when its runner is absent.
- Native removal and fresh reinstall passed. Omarchy removes the old bar entry and
  re-adds defaults; the original widget preferences and exact bar order were restored
  from the pre-test backup. No plugin-owned persistent race cache or credentials exist.
- The public source is [vip32/omarchy-procyclingstats](https://github.com/vip32/omarchy-procyclingstats).
  No tag, GitHub release or marketplace request has been created.
- Static checks are not a security audit. Marketplace compatibility, capability
  review and maintainer approval are separate steps for an exact public commit.
