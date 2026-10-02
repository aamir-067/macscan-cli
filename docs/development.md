# Development rules

## Non-negotiable
- Bash 3.2: no associative arrays, `mapfile`, `${var,,}`, `|&`, or `declare -n`. Process substitution and `+=` on arrays are fine.
- Modules are read-only. They may read anything, write only to `$RUN`, `$INV` and temp files they delete.
- Root never executes user-writable code. Run Homebrew tools with `sudo -u "$U" -H`. Use absolute paths for anything not in `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`.
- Never run git, npm, bun, node, or editors inside scanned repositories; read files directly (for example parse `.git/config` with awk).
- Never walk `~/Library/CloudStorage` (it can trigger cloud downloads) or VM disk images; use the prune arrays in `common.sh`.
- Discover things by structure, not by name, so new browsers, editors and AI tools are found automatically.
- Inventory lines must be stable across scans (no versions, PIDs or timestamps).
- Flag message prefixes are a public contract; changing one requires updating `known-flags.md` matching.
- Every slow command gets a timeout via `tmo`.
- All output passes through `redact`; never add code that prints secret values.

## Workflow for any change
1. Read `architecture.md` and the code you will touch.
2. Make the change in the source (after P0-2, the `src/` tree; until then, `install-mac-triage.sh`).
3. Run `/test`. Add or update tests for the change.
4. Update `architecture.md`, `known-flags.md`, `roadmap.md` and CLAUDE.md "Current state" if affected.
5. The user installs: `sudo bash install-mac-triage.sh`, then `macscan --check-fda` (re-grant FDA if the helper was rebuilt), then a targeted `macscan --only NN`.

## Adding a tool
Prefer tools that are open source, maintained, and can run as the user. Install with Homebrew (Tier 1). Wrap them in a module that skips cleanly when the tool is missing. Candidates are listed in `roadmap.md`.
