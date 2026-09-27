# ProCyclingStats

Professional road cycling races and live race situation.

Kinds: bar-widget, service

## Requirements

- Omarchy 4 with Quattro shell-plugin support.
- No additional package, authentication, or privileged setup is required by the
  generated baseline. Document every dependency before release.

## Installation

```bash
omarchy plugin add https://github.com/vip32/omarchy-procyclingstats.git --enable
```

For a local checkout:

```bash
omarchy plugin add "$(pwd)" --enable
```

## Validation and tests

```bash
./tests/run
omarchy plugin validate .
```

## Update

```bash
omarchy plugin update io.github.vip32.procyclingstats
```

## Removal

```bash
omarchy plugin remove io.github.vip32.procyclingstats
```

The generated baseline stores no data outside normal Omarchy shell
configuration. Update this section when the plugin gains durable state or an
external dependency.

## Security

Omarchy plugins run as unsandboxed code inside `omarchy-shell`. Review this
repository and its dependencies before enabling it.

## License

MIT © 2026 vip32
