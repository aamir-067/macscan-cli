# Architecture

## Components (installed under /usr/local/mac-triage, root:wheel)
- `macscan`: CLI front end (symlinked to `/usr/local/bin/macscan`). Re-execs itself with sudo. Validates flags, writes a request file, kickstarts the runner LaunchDaemon, and follows the live log. `--foreground` runs the engine directly in the terminal instead.
- `bin/macscan-helper`: tiny C program. launchd starts it; it spawns `/bin/bash core/run.sh` as a child in its own process group, so macOS attributes file access to the helper, which holds Full Disk Access. Signals are forwarded to the group.
- `core/run.sh`: scan engine. Parses options, decides whether an automatic run should scan, takes the lock, tees output to `state/current.log`, updates rules, runs modules, diffs inventories, writes the summary, full report and zip, applies retention, logs history, notifies.
- `core/common.sh`: shared helpers (`section`, `sub`, `flag`, `inv`, `asuser`, `tmo`, `sha`, `sig`, `sigf`, `redact`, prune arrays, structure-based discovery functions).
- `core/fda.sh`: Full Disk Access detection (hot patch, see CLAUDE.md).
- `modules/NN-name.sh`: one area each, run in order, output redacted into `modules/NN-name.txt`.
- `rules/custom.yar`, `rules/all.yarc`, `rules/sets.txt`: YARA rules (custom + YARA Forge core + Elastic macOS/multi), compiled as the user.
- `config`: KEY="VALUE" settings, changed with `macscan --set`.
- `state/` (root only, 700): `running.pid`, `request`, `current.log`, `service.log`, `history.log`, `last-full-scan`, `apps.list`, `rules-updated`, `clam-updated`, `fda-status`, `inv/last/*.txt`.

## LaunchDaemons
- `com.mactriage.runner`: on demand, `macscan-helper --from-request`.
- `com.mactriage.auto`: `StartInterval` 3600 plus `WatchPaths` on `/Applications` and `~/Applications`, runs `macscan-helper --scheduled`. The engine decides: scan if a new app appeared (after a 120 s settle) or if `AUTO_INTERVAL_DAYS` passed since the last full scan; postpone below `AUTO_MIN_BATTERY` percent.

## Modules
01 system posture, 02 accounts, 03 remote access, 04 profiles/MDM, 05 launchd and BTM, 06 other persistence, 07 shell and command hijacking, 08 processes, 09 network, 10 privacy (TCC), 11 keychain and certificates, 12 applications, 13 downloads history, 14 filesystem sweep, 15 browsers, 16 developer environment and AI tools, 17 code repositories, 18 unified logs, 19 YARA, 20 ClamAV.
`--quick` skips 14, 18, 19, 20.

## Data contracts (other parts depend on these; change carefully)
- Flag line: `[<module>] <message>`, collected in `$RUN/.flags.raw`. New-since-last-scan flags use `[new since last scan] [<category>] <item>`. Message prefixes must stay stable, because known-flag matching depends on them.
- Inventory: `inv <category> "<stable line>"` appends to `$INV/<category>.txt`. Lines must not contain volatile data (PIDs, versions, timestamps), or every scan produces false "new" items.
- Report folder: `00-SUMMARY_<stamp>.txt`, `FULL-REPORT_<stamp>.txt`, `modules/*.txt`, plus `<folder>.zip` beside it.

## Security design
- Tool files are root-owned so user-level malware cannot modify what root runs on schedule.
- PATH inside the engine is system-only; Homebrew tools (yara, yarac, clamscan, freshclam) always run as the user.
- Never walked: `~/Library/CloudStorage`, `~/.orbstack`, caches, `node_modules` (except targeted scans), the report folder.
- The engine refuses to write reports if the report folder is a symlink.
