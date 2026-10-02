# Companion tools

mac-triage takes a snapshot when it runs. It does not watch your Mac between scans and cannot block anything. These free tools cover that gap well. They were evaluated as companions rather than as modules (P2-5 on the roadmap).

## Objective-See (free, open source)

| Tool | What it does | Why not a module |
|---|---|---|
| **BlockBlock** | Watches persistence locations (launch items, login items and similar) continuously and alerts the moment something installs itself. | It is a real-time monitor that needs its own system extension and asks you to allow or block. A scheduled scanner cannot do that job. Strongly recommended next to mac-triage. |
| **LuLu** | Outbound firewall: asks before an unknown program connects out. | Same reason: real-time and interactive. It also helps against infostealers that try to upload what they took. |
| **KnockKnock** | Lists persistent software on demand, with signing details and optional VirusTotal hash lookups. | Overlaps with modules 05 and 06. Useful as a second opinion when a launch item flag is unclear. |
| **OverSight** | Alerts when the microphone or camera turns on. | Real-time. |

Get them only from [objective-see.org](https://objective-see.org) or their official GitHub repositories, and check the code signature (`codesign -dv --verbose=2 <app>`, team ID of Objective-See) before running them.

## Optional tools mac-triage uses when present

| Tool | Module | Install |
|---|---|---|
| YARA | 19 | `brew install yara` (the installer does this) |
| ClamAV | 20 | `brew install clamav` (the installer does this) |
| osv-scanner, gitleaks | 22 (opt-in `SUPPLY_CHAIN=yes`) | `brew install osv-scanner gitleaks` |
| osquery | 23 | Official package from [osquery.io](https://osquery.io) (installs root-owned, which module 23 requires) |

**Evaluated and left out:** guarddog (malicious-package heuristics for npm and PyPI). It downloads and unpacks every dependency to analyse it, which is too slow and too network-heavy for a scheduled scan. Run it by hand on a project you are unsure about.
