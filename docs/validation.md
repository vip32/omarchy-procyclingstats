# Candidate validation

Candidate: version **0.7.0**, prepared **2026-09-27**. Exact final source identity
and raw local reports are in `.git/submission-candidate/` of the preparation checkout.

| Check | Evidence / scope |
| --- | --- |
| Portable suite | 85 behavioral tests: 46 Python, 26 JavaScript, 13 QtTest service cases |
| Native manifest validation | `omarchy plugin validate .` on Omarchy 4.0.4-1 |
| QML syntax | Qt 6.11.2 `qmlformat` parses the production QML files |
| Advisory static review | No reported security findings; collected process output and process execution require human capability review |
| Process boundary review | Isolated Python; argument arrays; fixed HTTPS origin; producer-side byte/node/output limits; total deadline; serialized requests; validated race paths |
| Live race data | Today’s six races enriched with category and class; yesterday’s CRO stage GC returned 104 riders and race events; tomorrow’s preview returned start, distance and route |
| Local installation/update | Installed from the Git checkout and updated through `omarchy plugin update`; shell IPC and native panel exercised |
| Filters | Native settings screenshot reviewed; saved filter values checked against the matching shell entry. Automated matching, partial-failure and notification scope tests passed |
| Demo captures | Native fixture-only screenshots, with normal fetching/preferences/workspace/cursor restored after capture |

## Limits and remaining gates

- Local display evidence covers one laptop monitor on Omarchy 4.0.4-1 / Qt 6.11.2.
  Multi-monitor and vertical-bar behavior are implemented but not covered by this run.
- Hosted GitHub Actions has not run because the repository is local. The Qt test
  job is configured to fail rather than silently skip when its runner is absent.
- A full native removal and fresh reinstall of the active plugin remains unrun.
  The removal command was inspected; it unloads the plugin and deletes its installed
  Git clone. The source checkout is separate. No plugin-owned persistent race cache
  or credentials exist.
- Public-origin release preflight remains blocked until the owner publishes a
  GitHub repository. No remote, tag, GitHub release or marketplace request exists.
- Static checks are not a security audit. Marketplace compatibility, capability
  review and maintainer approval are separate steps for an exact public commit.
