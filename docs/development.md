# Development

## Tests

Python 3 and Node.js 18+ run the portable suite. Qt 6’s `qmltestrunner`, QtQuick,
QtTest and the platform plugins run service integration tests with fictional
process/notification stubs. They do not make network requests or send notifications.

```sh
./tests/run
PCS_REQUIRE_QT=1 ./tests/run
omarchy plugin validate .
```

GitHub Actions is configured for Ubuntu 24.04, Python 3.12, Node 22 and Qt 6.
Actions are pinned to full commits. CI installs its own test packages; the plugin
never installs dependencies at runtime. [Hosted CI](https://github.com/vip32/omarchy-procyclingstats/actions/workflows/test.yml)
runs on pushes to main and pull requests.

## Adapter diagnostics

```sh
python3 -I bin/pcs.py overview
python3 -I bin/pcs.py calendar --date 2026-09-27
python3 -I bin/pcs.py archive --date 2026-10-05 --direction recent
python3 -I bin/pcs.py race --race race/example/2026/result --html saved-page.html
omarchy-shell io.github.vip32.procyclingstats status
omarchy-shell io.github.vip32.procyclingstats.panel status
```

`--html` parses an explicitly supplied saved page offline and marks `savedPage` in
its output. It is never selected automatically when the network fails.

## Reproduce screenshots

Commit and install the source first. The harness captures the **installed** plugin,
so update it before capturing a changed UI:

```sh
omarchy plugin update io.github.vip32.procyclingstats --yes
omarchy restart shell
./demo/run --pin --output preview.png
./demo/run --window --verify-window --output screenshots/window.png
./demo/run --compact --race-index 1 --pin --output screenshots/compact.png
./demo/run --events --output screenshots/events.png
./demo/run --race-index 2 --pin --reveal --output screenshots/gc.png
./demo/run --race-index 2 --pin --verify-following --output screenshots/stage-navigation.png
./demo/run --settings --output screenshots/settings.png
./demo/run --settings --settings-section refresh --output screenshots/refresh-settings.png
./demo/run --warning blocked --output screenshots/warning.png
./demo/run --day 1 --compact --output screenshots/tomorrow-list.png
./demo/run --day 1 --output screenshots/tomorrow-preview.png
```

Capture dependencies: an unlocked Omarchy session, Git, `omarchy-shell`, `hyprctl`
and `grim`. Focus the unrotated monitor containing the plugin before capturing; other
connected displays can remain enabled. Use it while not interacting with the panel. It switches briefly to an unused empty workspace.

The committed fixture is visibly labelled DEMO. While active, the plugin uses
read-only default settings, stops live polling and suppresses event notifications.
Personal category filters do not affect screenshot content or get overwritten.

The harness records the installed commit, shell process IDs, current panel state,
workspace and cursor in a private, uniquely named recovery directory under
`XDG_RUNTIME_DIR` (or `/tmp`). It also backs up shell configuration without changing
it. Normal completion and exceptions restore live fetching, the workspace, cursor,
selected day/race, popup/window mode, open state and scroll position before deleting recovery files.
A stale recovery directory blocks another capture. Restoration failures retain
its exact path for inspection; do not delete it until normal operation is restored.

`--verify-window` checks one tiled instance, repeated open, activation from another
workspace, a floating/tiled geometry change, desktop close/reopen and docking.
It checks retained selection, date, tab, settings view, classification and expanded
group count. It does not assert compositor tile ordering after remapping.

Demo mode can also be controlled manually:

```sh
omarchy-shell io.github.vip32.procyclingstats demo true
omarchy-shell io.github.vip32.procyclingstats demo false
```

Do not leave demo mode enabled when normal race updates are expected.

Calendar fixture captures: `demo/run --calendar recent --compact --output screenshots/calendar.png`
and `demo/run --calendar upcoming --compact --output /tmp/pcs-upcoming.png`.

Rebuild the fictional raster-profile fixture with `python3 demo/build-profile.py`.
`python3 -I bin/pcs.py course --race race/example/2026/result` reads course metadata
and a bounded inline profile image when published.
