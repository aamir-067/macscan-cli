# Testing

## Tools

```bash
brew install shellcheck bats-core shfmt
```

YARA and ClamAV are optional: detection tests that need them are skipped when they are missing.

## Layers (`make test` runs all of them)

| Target | Folder | What it checks |
|---|---|---|
| `make lint` | `tests/static` | `bash -n` under `/bin/bash` 3.2, shellcheck with zero findings (exceptions are documented in `.shellcheckrc`), no Bash 4+ features, the C helper compiles with `-Wall -Wextra -Werror`, custom YARA rules compile, security invariants (no root writes into the report folder or `/tmp`, no `eval` of requests, `sql` wrapper only), and test hygiene. |
| `make test-unit` | `tests/unit` | `common.sh` helpers (`redact`, `sanitize`, `sig`, path classifiers, `rd`, `sql`, `tmpf`), engine libraries (options, module selection, lock, rules collection, inventory diff, summary), `deliver.sh`, `macscan` validation. |
| `make test-smoke` | `tests/smoke` | Modules run as the current user against a fixture home with `sudo` and `launchctl` stubbed. Each must exit 0 within a time limit and leave the home folder unchanged. |
| `make test-detection` | `tests/detection` | Synthetic fixtures must produce the expected flags: shell download-and-run, sudo alias, `folderOpen` tasks, the injected loader marker, long config lines, repo and global git configs that run commands, SSH `ProxyCommand`, non-default registries, sideloaded browser extensions, custom YARA rules, ClamAV EICAR. |
| `make test-build` | `tests/build` | Semantic `VERSION`, CHANGELOG entry, the installer payload equals `src/`, checksums, tarball contents, reproducible build, installer safety checks, version bump script. |

## Writing tests

- Tests run under `/bin/bash` 3.2. There, a failing `[[ ]]` does **not** stop a test and a bare `! cmd` never does. Use `[[ ... ]] || return 1` and the `not` helper. A static test enforces this.
- Never commit real malware or secret-shaped strings. Build fixtures at test time and split trait strings (`"cu""rl"`, `"gh""p_"`), so mac-triage scanning a checkout does not flag its own tests and secret scanners do not block pushes.

## Manual tests on a real Mac

- **Canary:** install a harmless LaunchAgent with label `test.canary.macscan` that runs `/usr/bin/true`, run `macscan --only 05`, confirm it is reported and appears under "new since last scan", then remove it. Do not use the `com.mactriage.` prefix; the scanner ignores its own labels.
- **Installer, upgrade, uninstall and schedules:** use a macOS virtual machine (for example UTM) so testing never risks your real system.

### Upgrade checklist (run in the VM for every release)

1. Install the previous release, grant Full Disk Access to `macscan-helper`, run `macscan --quick` once (creates a baseline and history).
2. `macscan --set KEEP_REPORTS=3` and `macscan --ignore "<some flag text>" --reason test` so there is user state to preserve.
3. Install the new release over it with `sudo bash install-mac-triage.sh`.
4. Check: `macscan --version` shows the new version; `macscan --config` still has `KEEP_REPORTS="3"` and any new keys work with `macscan --set`; `macscan --ignored` still lists the entry; `macscan --verify` is ok; `macscan --check-fda` (re-grant if the helper changed); `ls /usr/local/mac-triage/modules` has no leftover files.
5. `macscan --quick`: the summary shows "new since last scan" against the old baseline, not a fresh baseline.
6. `launchctl print system/com.mactriage.auto` shows the job; touch an app into `/Applications` and confirm an automatic scan starts within a few minutes.
7. `macscan --uninstall`: the folder, both LaunchDaemons and `/usr/local/bin/macscan` are gone; reports remain.
- **Performance:** compare per-module durations in the scan log between versions; investigate any module that grows by more than half.
