# Architecture

## Installed layout (`/usr/local/mac-triage`, root:wheel)

The repository's `src/` folder mirrors this layout. `scripts/build.sh` turns it into `dist/install-mac-triage.sh`.

| Path | Role |
|---|---|
| `macscan` | CLI front end, linked from `/usr/local/bin/macscan`. Re-executes itself with sudo and a clean environment, validates options, writes a request file, kickstarts the runner LaunchDaemon and follows the live log. `--foreground` runs the engine in the terminal instead. |
| `bin/macscan-helper` (from `helper/macscan-helper.c`) | Tiny C program started by launchd. Refuses to run unless root, then spawns `/bin/bash core/run.sh` in its own process group, so macOS attributes file access to the helper, which holds Full Disk Access. Forwards signals to the group. |
| `core/run.sh` | Scan engine (orchestration only): option parsing, auto-scan decision, lock, log, rule updates, module loop, inventory diff, summary, delivery, history, notification. |
| `core/lib/*.sh` | Engine libraries: `options`, `modules` (metadata and selection), `auto`, `lock`, `rules`, `report` (flags, summary, `report.json`, delivery), `severity` (rubric and acknowledgements), `integrity` (install manifest checks), `execmon` (eslogger capture), `power` (keep awake, sleep detection), `notify`, `text` (sanitizing). |
| `core/common.sh` | Helpers for modules: `section`, `sub`, `flag`, `inv`, `asuser`, `tmo`, `tmpf`, `sql`, `rd`, `sha`, `sig`, `sigf`, `redact`, path classifiers (`is_system_path`, `canon_path`, `user_path`, `is_dev_path`), `root_safe_bin`, download origin checks, `gitleaks_findings`, prune arrays, structure-based discovery. |
| `core/fda.sh` | Full Disk Access detection (tries several protected folders). |
| `core/deliver.sh` | Runs **as the user**: receives the finished report as a tar stream, writes it into the report folder, zips it, applies retention. |
| `modules/NN-name.sh` | One area each, run in order. Output passes through `redact` into the report. |
| `rules/custom.yar`, `rules/all.yarc`, `rules/sets.txt` | Custom YARA rules; compiled bundle (custom + YARA Forge core + Elastic macOS/multi), compiled as the user. |
| `VERSION`, `config` | Version string; `KEY="VALUE"` settings changed with `macscan --set`. |
| `manifest.sha256` | Written by the installer; checked by `core/lib/integrity.sh` at the start of every scan and by `macscan --verify`. |
| `state/` (root only, 700) | `acknowledged.tsv` (`macscan --ignore`), `lock/`, `running.pid`, `request`, `current.log`, `service.log`, `history.log`, `last-full-scan`, `apps.list`, `rules-updated`, `clam-updated`, `fda-status`, `inv/last/*.txt`, `work/` (report staging), `tmp/` (per-scan temp), `progress` (running module, for `--status`), `undelivered/`. |

## LaunchDaemons

- `com.mactriage.runner`: on demand, `macscan-helper --from-request`.
- `com.mactriage.auto`: `StartInterval` 3600 plus `WatchPaths` on `/Applications` and `~/Applications`, runs `macscan-helper --scheduled`. The engine decides: scan if a new app appeared (after a 120 s settle) or if `AUTO_INTERVAL_DAYS` passed since the last full scan; postpone below `AUTO_MIN_BATTERY` percent.

## Scan flow

1. `macscan` writes its arguments NUL-separated to `state/request` and kickstarts the runner.
2. `run.sh` reads the request as data, parses and re-validates options, takes the atomic lock, creates `state/tmp` and `state/work/<name>`.
3. The install is verified against `manifest.sha256`; rule and signature updates run as the user (see below); with `EXEC_MONITOR=yes`, `eslogger` starts recording program launches.
4. Each selected module runs as `/bin/bash modules/NN-name.sh` under a timeout; its output is redacted into `state/work/<name>/modules/NN-name.txt`. Flags go to `.flags.raw`, inventory lines to `state/inv/new_<stamp>/`.
5. Inventories are diffed against `state/inv/last/`; additions become `[new since last scan]` flags.
6. Flags are redacted, classified by severity, split into counted and acknowledged, and written as the summary (most severe first), `report.json` and the full report in the staging folder, then streamed (`tar`) to `deliver.sh` running as the user. On failure the report moves to `state/undelivered/`.
7. Retention runs as the user; history and notification are written with sanitized text.

## Module metadata

The first lines of each module declare:

```
# @title  One line shown by macscan --modules
# @quick  skip               left out of --quick
# @toggle YARA|CLAMAV|LOGS|SUPPLY_CHAIN|EXEC_MONITOR
#                            left out when that feature is off (--no-yara, --no-clamav,
#                            --no-logs, or the setting is not yes)
```

## Data contracts (other parts depend on these; change carefully)

- **Flag line:** `[<module>] <message>`. New-since-last-scan flags: `[new since last scan] [<category>] <item>`. Message prefixes stay stable because users match known flags by substring.
- **Inventory:** `inv <category> "<stable line>"` appends to `$INV/<category>.txt`. No volatile data (PIDs, versions, timestamps).
- **Report folder:** `scan_<stamp>_<mode>/` with `00-SUMMARY_<stamp>.txt`, `FULL-REPORT_<stamp>.txt`, `report.json` (schema_version 1), `modules/*.txt`, plus `<folder>.zip` beside it.
- **Summary flag line:** `[SEVERITY] [<module>] <message>`; the part after the severity tag is the flag line unchanged.

## Security design

- Tool files are root-owned and the installer refuses a path any non-root process could modify, so user-level malware cannot change what root runs.
- Root never writes into user-writable locations: reports are staged in `state/work` and delivered by `deliver.sh` as the user; temp files live in `state/tmp`; rule updates feed inputs through stdin and read outputs with `cat` as the user.
- Root never executes user-writable code: Homebrew tools (`yara`, `yarac`, `clamscan`, `freshclam`) and downloads run with `sudo -u "$U" -H`. The engine's `PATH` is system-only and `HOME` is `/var/root`.
- Files in user-writable places are read as the user (`rd`), SQLite runs in safe, read-only mode (`sql`), and finds that feed content readers use `-type f`.
- Text from the scanned system passes through `sanitize` (control characters and direction overrides made visible) and `redact` (secrets masked).
- Never walked: `~/Library/CloudStorage` (can trigger downloads), `~/.orbstack` and VM disks, caches, `node_modules` (except targeted checks), the report folder.
