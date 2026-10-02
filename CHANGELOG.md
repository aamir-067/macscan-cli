# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/). For mac-triage, a flag wording change counts as breaking, because users match known flags by substring.

## [Unreleased]

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

[Unreleased]: https://github.com/aamir-067/mac-triage/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/aamir-067/mac-triage/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/aamir-067/mac-triage/releases/tag/v2.0.0
