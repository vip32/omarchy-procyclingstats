# Validation

## 0.11.0 spoiler protection and detail tabs — 2026-10-06

- `PCS_REQUIRE_QT=1 tests/run`: 171 behavioral tests (85 Python, 44 JavaScript,
  42 Qt cases), plus the two profile cases at 150% scaling. Manifest validation,
  QML parsing and the advisory scan passed without reported findings.
- Actual RaceSummary Qt checks ensure concealed winner time/average are absent
  from rendered text while distance and the course remain. Service tests cover
  finished status from both live data and race lists suppressing notifications,
  and normal notification behavior when protection is off.
- Native checks: remembered tabs across navigation/races; no collapse when a tab
  saves; finished GC and one-day races hidden initially; explicit reveal; hide
  again after switching races or closing; live data unaffected. The setting saved
  both on and off. Real results were never exposed during off-mode verification.
- Race events preference and protection setting survived a shell restart.
  Fictional hidden/revealed result and Settings captures were visually inspected.
  Earlier view/preferences restored with the new default-on protection retained.

## 0.10.3 calendar tab retention — 2026-10-05

- `PCS_REQUIRE_QT=1 tests/run`: 165 behavioral tests (85 Python, 42 JavaScript,
  38 Qt cases), plus the two profile cases at 150% scaling. Manifest validation
  and QML parsing passed.
- Native Recent and Upcoming selections survived navigation to Races and calendar
  reopening, plus closing/reopening the dashboard. Upcoming survived a shell
  restart. Fictional demo tab changes left the saved settings file unchanged.
- Previous view and unrelated preferences restored; the calendar choice is stored
  in the existing widget entry without an extra settings control.

## 0.10.2 persistent profiles — 2026-10-05

- `PCS_REQUIRE_QT=1 tests/run`: 164 behavioral tests (85 Python, 41 JavaScript,
  38 Qt cases), plus the two profile cases repeated at 150% scaling. Manifest
  validation and QML parsing passed.
- Disk tests cover cross-process restoration, seven-day expiry without renewal
  on reads, pruning and byte/count limits, corrupt/oversized/unrelated data,
  image validation, atomic-write failure, symlinks and unavailable storage.
  Production CLI tests verify network-free reads and offline-fixture isolation.
- Service tests cover immediate restoration, normal refresh of older profiles,
  network cooldown/warning retention, concurrent live updates, memory eviction,
  list closure, malformed output and discarded completions after midnight.
- Native shell restart restored Langkawi Stage 8 (188.3 km) and the European
  Championships (196.3 km) from disk. The service reported two disk hits; both
  cache files retained their pre-restart fetch timestamps, proving no profile
  refetch was needed. Settings and the previous dashboard view were restored.
- Portable advisory scan reported no findings; process and collected-output
  boundaries were reviewed. Cache reads/writes stay in the bounded Python helper.

## 0.10.1 inline image profiles — 2026-10-05

- `PCS_REQUIRE_QT=1 tests/run`: 142 behavioral tests (72 Python, 41 JavaScript,
  29 Qt cases), plus the two profile cases repeated at 150% scaling. Manifest
  validation and QML parsing passed.
- Native Langkawi Stage 8 image rendered as a compact theme-coloured curve,
  retaining 188.3 km, winner time, average speed and 108 GC rows. The check
  exposed and fixed physical-pixel reads on fractionally scaled Wayland windows.
- Fictional daily/calendar lists and finished-race profile screenshots captured
  and inspected. Capture supports the focused, unrotated plugin monitor while
  preserving other monitors and restoring the original workspace and view.
- Native PCS coordinates take precedence. Image-only profiles use a bounded
  visual outline approximation, falling back to the source image when tracing
  is unreliable. No actual elevation measurements are inferred from pixels.

## 0.10.0 elevation profiles — 2026-10-05

- `PCS_REQUIRE_QT=1 tests/run`: 134 behavioral tests (71 Python, 37 JavaScript,
  26 Qt service cases), manifest validation and QML parsing.
- PNG/JPEG fixtures cover origin/path restrictions, image signatures and size,
  pixel bounds, parent-page Referer, offline mode, rejection, vector preference
  and transition from live to finished image coverage. Service checks cover
  visible-only queueing, cancellation, bounded caching, recovery and cooldowns.
- Native yesterday list loaded both real profiles: Langkawi Stage 8 (188.3 km)
  and the European Championships (196.3 km). Langkawi details retained 108 GC rows
  alongside its full image and stage label. Upcoming men’s/women’s Tre Valli
  Varesine loaded profiles and distances of 196.1/133.9 km.
- Fictional daily/calendar thumbnails and full image fallback captured and
  visually inspected. Calendar search-summary/count shortcut removed. Saved
  count, filters, notifications and previous dashboard view restored.

## 0.9.1 fixes — 2026-10-05

- Reproduced HTTP 500 at Langkawi `/gc/live`, while its stage endpoint responds.
  Updated adapter returns 108 GC rows with optional profile/events marked
  unavailable, without an HTTP 500 warning.
- `PCS_REQUIRE_QT=1 tests/run`: 117 behavioral tests (61 Python, 35 JavaScript,
  21 Qt service cases), native manifest validation and QML parsing.
- Native panel verified Langkawi with 108 GC rows and no connection warning;
  compact daily/calendar rows and the shared-cooldown banner were captured and
  visually checked. Existing settings (including the saved count of 10) and
  the prior dashboard view were restored.
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
