# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/). For mac-triage, a flag wording change counts as breaking, because users match known flags by substring.

## [Unreleased]

### Added
- Git hook persistence used by the SANDWORM_MODE npm worm (2026): hooks in a global `init.templateDir` (copied into every new clone) or `~/.git-templates/hooks` are high (`Git template adds a hook to every new repository (verify):`), hooks in a global `core.hooksPath` are high (`Global git hook runs in every repository (verify):`), and any of those or a repository hook that pipes a download into a shell, decodes base64, calls `osascript` or starts a script from a hidden home folder or `/tmp` is high (`Git hook downloads or runs hidden code:`). `templateDir` is also listed with the other git settings that can run commands. Every repository hook is now checked; only the listing stops at 150.

### Fixed
- Module 16 dropped every global git setting line that contained the word `osxkeychain`, so a credential helper such as `!f(){ osxkeychain; curl ...; }` was never reported. Only the exact default `helper = osxkeychain` line is skipped now.

## [2.5.0] - 2026-10-04

### Added
- `macscan doctor` checks the whole setup (install integrity, helper signature, command link, Full Disk Access, services, YARA and ClamAV freshness, report folder and free space, undelivered reports, last full scan, available updates) and prints the exact command that fixes each problem. It exits non-zero when something needs fixing.
- Help pages: `macscan help` shows a short overview with examples; `macscan help <topic>` explains scan, reports, flags, auto, update, settings, privacy and troubleshooting; `macscan help options` lists every option. A test keeps the option list in sync with the engine.
- Plain-word commands: `macscan status`, `macscan doctor`, `macscan update`, `macscan last` and so on work like their `--` forms; unknown words are refused instead of starting a scan.

## [2.4.1] - 2026-10-04

### Added
- Homebrew install: `brew install aamir-067/tap/macscan`, then `macscan-setup`. The formula installs the verified release installer and a `macscan-setup` command; the scanner itself still installs root-owned under `/usr/local/mac-triage`. `scripts/update-tap.sh` renders the formula for each release.

## [2.4.0] - 2026-10-03

### Added
- `macscan --update` downloads the newest release installer and its checksums from GitHub as root into a root-only folder, verifies the SHA-256 and the version, then upgrades. `macscan --update --check` only reports whether an update exists; `--yes` skips the confirmation.
- Upgrade-aware installer: it reports whether it installs, upgrades, repairs or downgrades; refuses to downgrade without `--allow-downgrade`; refuses to run during a scan; adds new settings to an existing config without changing existing values; and prints what was kept. New `--help` and `--uninstall` options.

### Changed
- Upgrades no longer recompile the Full Disk Access helper unless its source changed. A rebuilt binary has a new code signature, which silently cancels its Full Disk Access permission; keeping it keeps the permission. The installer now says when re-granting is needed and only then opens System Settings.
- Upgrades skip the Homebrew install of YARA and ClamAV and the rule download when they are already present.

## [2.3.0] - 2026-10-03

### Added
- Sleep-aware scans. While a scan runs, the Mac is kept from idle sleep (`caffeinate -i`, released when the scan ends). If the Mac still sleeps (for example the lid is closed), the scan pauses and continues on wake as before, and now the summary and `report.json` (`sleep` field) report how many times and how long it slept, exclude that time from the duration, and name the modules that ran across a sleep.
- `macscan --status` shows the running module, its position and how long the scan has been running.

## [2.2.2] - 2026-10-03

### Fixed
- Module 08 trusted processes holding browser, keychain or wallet files by name. Names with spaces never matched (lsof writes them as `\x20`), Apple daemons were missing, and malware could simply copy a trusted name. Trust now requires an Apple program in a sealed system folder or a validly signed app with a Developer ID team; one real scan went from 19 false critical flags to none.

### Added
- Detection for the PolinRider / TasksJacker campaign (DPRK, 2026), which spreads through developer repositories: a VS Code `folderOpen` task that runs code (`node`, a fake font, `curl`, a shell) is now critical (`Auto-run task runs code on folder open:`); a project `.vscode/settings.json` that turns on `task.allowAutomaticTasks` is high; `.woff`/`.woff2` files that do not start with a real font signature are critical (`Font file is really a program (fake font):`). Only the first 4 bytes of each font are read, as the user.
- More published loader markers (PolinRider, TasksJacker, ForceMemo) in the injected-code search, which now also covers Python files.

## [2.2.1] - 2026-10-03

### Fixed
- Every GitHub link (README install commands, issue templates, SECURITY.md, CHANGELOG, the version bump script) pointed at `aamir-067/mac-triage` instead of the published repository `aamir-067/macscan-cli`, so the documented install commands failed. A test now checks the links.
- Module 21 also flags files named like a recovery key (for example an exported FileVault or Apple Account recovery key), which infostealers collect.

## [2.2.0] - 2026-10-03

### Fixed
- `macscan --set` now adds a setting that is missing from an older config file (it used to do nothing), and checks yes/no and enumerated values.

### Added
- `docs/companion-tools.md`: evaluation of Objective-See tools and the optional tools mac-triage uses (P2-5), and an upgrade checklist for VM testing in `docs/testing.md` (P3-1).
- Module 24 (opt-in, experimental, `EXEC_MONITOR=yes`): the built-in `eslogger` records program starts during a full scan, minus the scan's own process group; programs from temp, hidden or Downloads folders are high, unsigned ones medium (P2-3).
- Module 23: when osquery is installed and its whole path is root-owned, cross-checks launchd, startup items, network listeners, system extensions and Chromium extensions from an independent source (P2-2).
- Module 22 (opt-in, `SUPPLY_CHAIN=yes`): `osv-scanner` with its offline database for known-vulnerable dependencies, and `gitleaks` for secrets committed to repositories (file, line and rule only). Both run as the user and are skipped with an install hint when missing (P2-1).
- `NOTIFY=dialog`: at the end of a scan, a dialog with an **Open report** button that opens the summary (P3-2).
- `--include-trash` and `INCLUDE_TRASH=yes`: the file-system sweep, YARA and ClamAV also cover the Trash (P2-4).
- Severity for every flag (critical, high, medium, low) from a central rubric in `core/lib/severity.sh`. The summary shows counts per severity and lists the most severe first as `[HIGH] [module] message`; the flag text after the severity tag is unchanged. New inventory items in persistence-type categories are high, others medium.
- `macscan --ignore "<text>" --reason "<why>"`, `--ignored` and `--unignore <text|N>`: acknowledged flags are stored root-only with date and reason, listed in an "Acknowledged" section of the summary and not counted (P1-1).
- `report.json` beside the text report, with per-severity counts and one entry per finding including a stable fingerprint (P1-5).
- Install integrity check: the installer writes `manifest.sha256`; every scan and `macscan --verify` check hashes, unexpected files (for example an extra module), ownership and permissions of the install folder, and the LaunchDaemon definitions. Problems are critical flags (P1-7).
- Module 13 classifies where recently downloaded programs, installers and archives came from (`kMDItemWhereFroms`, since macOS 27 quarantine rows have no URLs): chat attachments and link shorteners are high, file shares, GitHub releases (with the owner/repo to verify) and free hosting are medium (P1-3).
- Module 21 finds plaintext secrets in Downloads, Desktop and Documents: password-manager exports (by name or CSV header), private keys outside `~/.ssh`, `.env` files outside a code project, and files named like password lists. Paths only; it reads at most the first line of CSV and key files, as the user (P1-2).

## [2.1.0] - 2026-10-02

### Security
- The root scan engine no longer writes into the user's report folder. A process running as the user could swap the in-progress report folder or the report zip for a symlink and make root overwrite, then `chown` to the user, a file such as a module script that root runs on a schedule (local privilege escalation). Reports are now built in a root-only folder and delivered by `core/deliver.sh`, which runs as the user.
- Rule updates no longer copy into, `chown` inside, or read from the user-owned temp folder as root (same escalation class, plus disclosure of root-only files through `rules/all.yarc`).
- Root temp files moved from the shared `/tmp` into a root-only per-scan folder. Module 19 wrote to a predictable `/tmp` name during the YARA scan; the installer wrote to a fixed `/tmp` path.
- Files in user-writable places (shell, git, SSH and package manager configs, history, `authorized_keys`, VS Code tasks, app policy files) are read with the user's rights, so a symlink cannot make root copy a protected file (for example a password hash) into a report.
- `/System/Volumes/Data/...` paths were treated as system paths, so a program started through that prefix skipped signature and temp-folder checks.
- SQLite is opened with `-noinit -safe -readonly`; root no longer inherits the caller's `HOME` or environment.
- Control characters and Unicode direction overrides in names are made visible in reports, history, logs and notifications. Notification text is passed to `osascript` as arguments.
- The scan request file is read as data instead of with `eval`; the scan lock is atomic; the engine re-validates its options.
- `macscan-helper` refuses to run unless started as root. **Re-grant Full Disk Access after upgrading** (its code signature changed).
- The installer refuses to install when any folder on the install path is a symlink, not owned by root, or writable by others; it edits the user's `.zshrc` as the user.

### Added
- Source tree in `src/` that mirrors the installed layout, a build script that produces a readable self-contained installer, a tarball and `SHA256SUMS`, and `install-mac-triage.sh --extract-only DIR`.
- Engine split into `core/lib/*.sh`; modules declare `@title`, `@quick` and `@toggle` in their header. `macscan --modules` shows titles.
- Test suite: static checks, unit, module smoke, detection fixture and build tests (`make test`), and CI on macOS.
- `--only 5` is accepted as `--only 05`.
- Broader secret redaction: Bearer and Basic credentials, `--password`/`--token` arguments, JSON secret fields, Slack and Discord webhooks, Stripe, GitLab, Hugging Face and Slack app tokens, Azure account keys.

### Changed
- If a report cannot be delivered, it is kept in `state/undelivered/` instead of being lost.

## [2.0.0] - 2026-10-02

### Added
- First tracked version: 20 modules, background service with a Full Disk Access helper, automatic weekly and new-app scans, inventory diff between scans, YARA (custom, YARA Forge core, Elastic macOS) and ClamAV, report retention.
- Full Disk Access detection that tries several protected folders, and dynamic discovery of TCC databases (macOS 27 moved the per-user database).

[Unreleased]: https://github.com/aamir-067/macscan-cli/compare/v2.5.0...HEAD
[2.5.0]: https://github.com/aamir-067/macscan-cli/compare/v2.4.1...v2.5.0
[2.4.1]: https://github.com/aamir-067/macscan-cli/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/aamir-067/macscan-cli/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/aamir-067/macscan-cli/compare/v2.2.2...v2.3.0
[2.2.2]: https://github.com/aamir-067/macscan-cli/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/aamir-067/macscan-cli/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/aamir-067/macscan-cli/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/aamir-067/macscan-cli/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/aamir-067/macscan-cli/releases/tag/v2.0.0
