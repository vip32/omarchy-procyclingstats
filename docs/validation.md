# Candidate validation

Candidate: version **0.8.0**, prepared **2026-09-27**. Exact final source identity
and raw local reports are in `.git/submission-candidate/` of the preparation checkout.

| Check | Evidence / scope |
| --- | --- |
| Portable suite | 88 behavioral tests: 46 Python, 26 JavaScript, 16 QtTest service cases |
| Native manifest validation | `omarchy plugin validate .` on Omarchy 4.0.4-1 |
| QML syntax | Qt 6.11.2 `qmlformat` parses the production QML files |
| Advisory static review | No reported security findings; collected process output and process execution require human capability review |
| Process boundary review | Isolated Python; argument arrays; fixed HTTPS origin; producer-side byte/node/output limits; total deadline; serialized requests; validated race paths |
| Live race data | Today’s six races enriched with category and class; yesterday’s CRO stage GC returned 104 riders and race events; tomorrow’s preview returned start, distance and route |
| Local installation/update | Installed from the Git checkout, updated, removed and freshly reinstalled at the production-code commit; shell IPC and native panel exercised |
| Detached window | One tiled instance, repeated open, cross-workspace activation, floating/tiled resize, desktop close/reopen, docking, P shortcut, retained race/date/tab/GC/settings view and nonzero settings scroll checked with fictional data |
| Filters | Native settings screenshot reviewed; saved filter values checked against the matching shell entry. Automated matching, partial-failure and notification scope tests passed |
| Demo captures | Native fixture-only screenshots, with normal fetching/preferences/workspace/cursor restored after capture; a forced screenshot-write failure also restored normal operation |

## Limits and remaining gates

- Local display evidence covers one laptop monitor on Omarchy 4.0.4-1 / Qt 6.11.2.
  Multi-monitor and vertical-bar behavior are implemented but not covered by this run.
- Hosted GitHub Actions has not run because the repository is local. The Qt test
  job is configured to fail rather than silently skip when its runner is absent.
- Native removal and fresh reinstall passed. Omarchy removes the old bar entry and
  re-adds defaults; the original widget preferences and exact bar order were restored
  from the pre-test backup. No plugin-owned persistent race cache or credentials exist.
- Public-origin release preflight remains blocked until the owner publishes a
  GitHub repository. No remote, tag, GitHub release or marketplace request exists.
- Static checks are not a security audit. Marketplace compatibility, capability
  review and maintainer approval are separate steps for an exact public commit.
