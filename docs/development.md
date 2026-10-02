# Development

## Rules

- **Bash 3.2.** No associative arrays, `mapfile`, `${var,,}`, `|&` or `declare -n`. Process substitution and `+=` on arrays are fine. Tests run under `/bin/bash`.
- **Modules are read-only.** They read anything and write only to `$RUN`, `$INV` and files from `tmpf`.
- **Root never runs user-writable code.** Homebrew tools run as `sudo -u "$U" -H`. Use absolute paths for anything outside `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`.
- **Root never writes where the user can.** Use `tmpf` (never `/tmp`), `rd` for reading user-writable files, `sql` for SQLite, and `deliver.sh` for anything in the report folder.
- **Never run code from scanned locations** (`git`, `npm`, `node`, editors). Parse files directly, for example `.git/config` with awk.
- **Never walk `~/Library/CloudStorage`** or VM disk images; use the prune arrays in `common.sh`.
- **Discover by structure, not by name,** so new browsers, editors and AI tools are found automatically.
- **Stable inventory lines** (no versions, PIDs or timestamps).
- **Flag prefixes are a public contract.**
- **Every slow command gets a timeout** via `tmo`.
- **All output passes through `redact`;** never print secret values.

## Workflow for a change

1. Read [architecture.md](architecture.md) and the code you will touch.
2. Change `src/`. Add or update tests.
3. `make test`.
4. Update docs and the `Unreleased` section of `CHANGELOG.md`.
5. Try it on your Mac: `make install`, then `macscan --check-fda` (re-grant Full Disk Access if the helper was rebuilt), then a targeted `macscan --only NN`.

## Adding an external tool

Prefer tools that are open source, maintained, and can run as the user. Wrap them in a module that skips cleanly when the tool is missing, and say in the module output how to install it.
