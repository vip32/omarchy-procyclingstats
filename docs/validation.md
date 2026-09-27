# Candidate validation

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
