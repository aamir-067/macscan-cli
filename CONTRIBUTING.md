# Contributing

Thanks for helping. A few rules keep a root-level scanner trustworthy.

## Ground rules

1. **Modules only observe.** They may read anything, and write only to the scan's run folder, inventory folder and temp folder (`tmpf`). No `rm`, `mv`, `chmod`, `chown`, `kill`, `launchctl load/bootout`, `defaults write` or similar. A test enforces this.
2. **Root never runs user-writable code.** Homebrew tools and anything under the user's home run with `sudo -u "$U" -H`. Use absolute paths for anything not in `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`.
3. **Root never writes where the user can.** Use the helpers: `tmpf` for temp files, `rd` to read files in user-writable places, `sql` for SQLite.
4. **Bash 3.2.** No associative arrays, `mapfile`, `${var,,}`, `|&` or namerefs. Run everything with `/bin/bash`.
5. **Never run code from scanned locations.** No `git`, `npm`, `node` or editors inside repositories; parse files directly.
6. **Never print secrets.** All module output goes through `redact`. Report paths, counts and names, not contents, for credential files.
7. **Stable inventory lines.** `inv` lines must not contain versions, PIDs or timestamps, or every scan reports false "new" items.
8. **Flag prefixes are a public contract.** Users match known flags by substring. Changing the wording of an existing flag is a breaking change; note it in the CHANGELOG.

## Workflow

```bash
brew install shellcheck bats-core shfmt
make test          # must pass
make build         # builds dist/
```

1. Read [docs/architecture.md](docs/architecture.md) and the code you will touch.
2. Make the change in `src/`. Add or update tests in `tests/` (unit for helpers, smoke for a new module, detection fixtures for a new check).
3. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
4. Open a pull request. CI runs the same `make test` on macOS.

## Adding a module

Create `src/modules/NN-name.sh`:

```bash
#!/bin/bash
# @title  What this module checks (shown by macscan --modules)
# @quick  skip            (optional: leave out of --quick scans)
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"

section "Heading"
# ... read things, print them, and call:
#   flag "Message prefix: details"     for something the user should verify
#   inv category "stable line"          to track it between scans
```

If it wraps an external tool, skip cleanly when the tool is missing, and run the tool as the user.

## Test fixtures

Never commit real malware. Build fixtures at test time, and split strings that look like malware traits (`"glo""bal"`), so that mac-triage scanning a checkout does not flag its own tests.

## Releases (maintainers)

```bash
scripts/bump-version.sh minor     # or patch / major / X.Y.Z; moves Unreleased notes under the new version
make release                      # tests, build, then tag vX.Y.Z
git push origin main --tags       # the release workflow publishes the installer and checksums
```
