# mac-triage

**A deep, read-only security scanner for macOS.** One command (`macscan`) checks the places Mac malware, infostealers and supply-chain attacks hide: persistence, privacy permissions, browser extensions, shell configs, developer tools, AI tool hooks and MCP servers, code repositories, network state, logs, and files (with YARA and ClamAV). It writes a plain-text report and tells you what changed since the last scan.

[![CI](https://github.com/aamir-067/mac-triage/actions/workflows/ci.yml/badge.svg)](https://github.com/aamir-067/mac-triage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> mac-triage observes and reports. It never deletes, quarantines or changes anything on your Mac. Every flag is something to verify, not proof of malware.

## Contents

- [What it checks](#what-it-checks)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Reports](#reports)
- [Configuration](#configuration)
- [How it stays safe](#how-it-stays-safe)
- [Privacy](#privacy)
- [Limitations](#limitations)
- [Uninstall](#uninstall)
- [Development](#development)
- [License](#license)

## What it checks

| # | Module | Highlights |
|---|---|---|
| 01 | System posture | SIP, sealed system volume, Gatekeeper, FileVault, firewall, XProtect, boot args |
| 02 | Accounts | UID 0 accounts, unexpected admins, new user records, sudoers and `NOPASSWD`, auto-login |
| 03 | Remote access | SSH server, Screen Sharing, ARD, `authorized_keys`, AnyDesk, TeamViewer, ngrok, cloudflared and similar |
| 04 | Profiles and MDM | Configuration profiles and managed preferences |
| 05 | launchd and BTM | Every LaunchAgent and LaunchDaemon with its target's signature, hidden items, interpreters, temp locations, `DYLD_*`, Background Task Management records |
| 06 | Other persistence | cron, at, periodic, login hooks, kernel and system extensions, authorization plugins, PAM, Spotlight and QuickLook plugins |
| 07 | Shell | Shell startup files that download and run code, aliases or functions that override `sudo`, `ssh`, `git`; shadowed system commands; suspicious history |
| 08 | Processes | Process tree, signatures of all non-Apple executables, programs running from temp or hidden folders, unexpected readers of browser and keychain files, `DYLD_INSERT_LIBRARIES` |
| 09 | Network | Listeners reachable from the network, sampled connections with reverse DNS, proxies, PAC, DNS, hosts file, VPN and filters |
| 10 | Privacy (TCC) | All granted permissions, high-risk ones granted recently, permissions held by apps no longer installed |
| 11 | Keychain and certificates | Custom trust settings, certificates in the System keychain |
| 12 | Applications | Signature and notarization of every app, apps outside `/Applications`, installer packages, Homebrew taps |
| 13 | Downloads | Quarantine history, file origins (`kMDItemWhereFroms`), downloads from social and file-sharing links |
| 14 | File system | New Mach-O binaries, scripts and plists outside app and dev folders, SUID files, staging archives, stealer artifacts |
| 15 | Browsers | Extensions of every Chromium and Firefox-family browser (found automatically) with risky permissions, sideloaded extensions, native messaging hosts, policies, saved-credential counts (never contents) |
| 16 | Developer environment and AI tools | Editor extensions, MCP server commands, AI tool hooks, Claude Code plugins, registry hijacks, global packages, git and SSH configs that run commands, credential files (paths only) |
| 17 | Code repositories | Known injected-loader markers, obfuscation, install scripts, VS Code tasks that run on folder open, git hooks, repo configs that run commands |
| 18 | Logs | XProtect results, Gatekeeper overrides, TCC changes, `osascript`, sudo, curl, crash reports |
| 19 | YARA | Custom rules plus YARA Forge core and Elastic macOS rules, run as you |
| 20 | ClamAV | Antivirus scan of your user folders and system launch locations, run as you |

New browsers, editors and AI tools are discovered by their folder structure, so they are covered without a code change. Every scan keeps a stable inventory (apps, launch items, extensions, MCP servers, hooks, permissions, and more) and reports anything **new since the last scan**, which is the most useful early-warning signal.

## Requirements

- macOS on Apple Silicon or Intel. Developed and tested on macOS 27; recent versions should work, though some paths differ between releases.
- An administrator account (the installer and scans use `sudo`).
- Xcode Command Line Tools (`xcode-select --install`) to compile the small Full Disk Access helper.
- Optional: [Homebrew](https://brew.sh). The installer uses it to add YARA and ClamAV. Without them, modules 19 and 20 are skipped.

Everything else is built into macOS. The tool is plain Bash 3.2 (the `/bin/bash` every Mac ships) plus one small C program (about 40 lines).

## Install

### From a release (recommended)

```bash
VERSION=2.1.0
curl -fLO "https://github.com/aamir-067/mac-triage/releases/download/v$VERSION/install-mac-triage.sh"
curl -fLO "https://github.com/aamir-067/mac-triage/releases/download/v$VERSION/SHA256SUMS"
shasum -a 256 -c SHA256SUMS --ignore-missing     # must print: install-mac-triage.sh: OK
less install-mac-triage.sh                        # it is readable; nothing is encoded
sudo bash install-mac-triage.sh
```

To see exactly which files would be installed without running anything as root:

```bash
bash install-mac-triage.sh --extract-only ./preview
```

### From source

```bash
git clone https://github.com/aamir-067/mac-triage.git
cd mac-triage
make test        # optional: needs shellcheck and bats-core (brew install shellcheck bats-core)
make install     # builds dist/install-mac-triage.sh and runs it with sudo
```

### Last step: Full Disk Access

macOS protects many of the places malware hides. The installer opens System Settings and a Finder window at the end:

1. Drag `macscan-helper` into **System Settings > Privacy & Security > Full Disk Access** and turn it on.
2. Run `macscan --check-fda`. It should print `yes`.

Re-check after every upgrade. If the helper was recompiled, its code signature changed and macOS treats it as a new program, so you need to add it again.

## Usage

```bash
macscan                 # full deep scan in the background service, with live progress
macscan --quick         # skips the file-system sweep, logs, YARA and ClamAV (a few minutes)
macscan --only 05,15    # just persistence and browsers
macscan --status        # schedule, running scan, last result, tool versions
macscan --last          # open the latest full report
macscan --help          # everything else
```

Ctrl+C stops *watching*; the scan keeps running. `macscan --log` resumes watching and `macscan --stop` cancels.

### Automatic scans

On by default: a full scan every 7 days, and a scan a couple of minutes after a new app appears in `/Applications` or `~/Applications`. Automatic scans are postponed when the battery is below 30 percent.

```bash
macscan --auto off
macscan --set AUTO_INTERVAL_DAYS=14
```

## Reports

Reports are saved in `~/Documents/mac-triage-reports/scan_<date>_<mode>/` (plus a `.zip` of the same folder):

- `00-SUMMARY_<date>.txt`: red flags, then what is new or removed since the last scan. Start here.
- `FULL-REPORT_<date>.txt`: the summary followed by every module's full output.
- `modules/NN-name.txt`: one file per module.

A flag line looks like `[05-persistence-launchd] Launch item runs from an unusual location: <plist> -> <target>`. Secrets that appear in configs or command lines (API keys, tokens, passwords, private keys, URL credentials) are masked before anything is written.

The newest 4 reports are kept, and anything older than 30 days is removed (the newest is always kept).

## Configuration

`macscan --config` shows the settings and `macscan --set KEY=VALUE` changes them.

| Key | Default | Meaning |
|---|---|---|
| `REPORT_DIR` | `~/Documents/mac-triage-reports` | Where reports go (full path) |
| `KEEP_REPORTS` | `4` | How many reports to keep |
| `MAX_AGE_DAYS` | `30` | Remove reports older than this (the newest is always kept) |
| `LOOKBACK_DAYS` | `60` | Window for "recently created or granted" checks |
| `AUTO_INTERVAL_DAYS` | `7` | Days between automatic full scans |
| `AUTO_ON_NEW_APP` | `yes` | Scan when a new app is installed |
| `AUTO_MIN_BATTERY` | `30` | Postpone automatic scans below this battery percentage |
| `ONLY_IF_FINDINGS` | `no` | Delete clean reports |
| `NOTIFY` | `yes` | Show a notification when a scan ends |
| `ZIP` | `yes` | Also save a zip of each report |
| `YARA` / `CLAMAV` | `yes` | Run the YARA and ClamAV modules |
| `CLAMAV_SCOPE` | `standard` | `standard` (user folders and launch locations) or `full` (whole home folder, slow) |

## How it stays safe

A scanner that runs as root on a schedule is itself a target. The design assumes that anything running as your user (the malware this tool looks for) may try to abuse it.

- **Root-owned code.** Everything lives in `/usr/local/mac-triage`, owned by root and writable only by root. The installer refuses to install if any folder on that path is not.
- **Root never writes where you can.** Reports are built in a root-only folder and handed to your report folder by a small script that runs as you, so a planted symlink can only redirect writes to places you could already write. Temp files live in a root-only folder, never in the shared `/tmp`.
- **Root never runs your code.** Homebrew tools (YARA, ClamAV, freshclam) and all downloads run as your user. Root uses only system binaries with a fixed `PATH`, a clean environment and `HOME=/var/root`.
- **Your files are read with your rights.** Shell configs, git and SSH configs and similar files in your home are read as you, so a symlink there cannot make root copy a protected file into a report.
- **Untrusted text stays inert.** SQLite databases are opened read-only in safe mode, control characters and Unicode direction overrides in names are made visible, and notification text is never spliced into script source.
- **Full Disk Access belongs to a tiny helper.** `macscan-helper` (C, about 40 lines) only starts the engine, refuses to run unless launched as root, and is the only thing you grant Full Disk Access to.

See [SECURITY.md](SECURITY.md) to report a vulnerability, and [CHANGELOG.md](CHANGELOG.md) for fixed issues.

## Privacy

- Nothing about your Mac is sent anywhere. Reports stay on your disk.
- Network use: YARA rules are downloaded from GitHub (YARA Forge, Elastic) weekly, and ClamAV signatures daily, by your user account. Module 09 runs reverse DNS lookups on the addresses your Mac is already talking to.
- Reports contain personal data (file names, app lists, URLs from your download history). Treat them like private documents and do not upload them anywhere.

## Limitations

Be clear about what a scan can and cannot tell you:

- It finds **artifacts on disk and in system state**. Malware that leaves no file, firmware or kernel-level implants, and anything outside this Mac (your cloud accounts) are out of scope.
- Many checks are heuristics. Expect flags you need to look at and dismiss; that is the trade-off for catching new things.
- Malware already running as root could hide from or tamper with any tool on the same machine, including this one.
- YARA rules are downloaded and compiled as your user, so malware running as you could weaken them. Treat a sudden drop in rule sets (shown in `macscan --status`) as suspicious.

## Uninstall

```bash
macscan --uninstall
```

This removes the tool and its services and keeps your reports. Also remove `macscan-helper` from Full Disk Access in System Settings. Optionally `brew uninstall yara clamav`.

## Development

```bash
make help        # list targets
make test        # shellcheck, Bash 3.2 checks, unit, module smoke, detection and build tests
make build       # dist/install-mac-triage.sh, a tarball and SHA256SUMS
```

The source in `src/` mirrors the installed layout. Read [docs/architecture.md](docs/architecture.md) first, then [docs/development.md](docs/development.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
