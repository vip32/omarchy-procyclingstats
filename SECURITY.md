# Security

Only the current candidate version is maintained. PCS markup and the Omarchy
plugin contract can change; update the plugin before reporting a fixed issue again.

For a sensitive vulnerability, use the hosting repository’s **Security → Report a
vulnerability** option if private vulnerability reporting is enabled. If it is not,
open a minimal issue asking the maintainer for a private reporting channel without
posting exploit details, tokens or personal configuration. No private reporting
endpoint has been configured while this repository remains local.

Include the affected version or commit, reproduction steps, expected impact and
relevant redacted logs. Do not attach a complete shell configuration or environment.

The process, network, file-write and notification boundaries are documented in
[docs/data-access.md](docs/data-access.md). Local validators and marketplace static
checks are limited evidence, not a security audit or certification.
