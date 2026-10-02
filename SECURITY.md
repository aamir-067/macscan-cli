# Security policy

mac-triage runs as root on a schedule, so a bug in it can matter more than a bug in a normal app. Reports are welcome and taken seriously.

## Supported versions

Only the latest release receives fixes. Upgrade with the newest installer from the [releases page](https://github.com/aamir-067/mac-triage/releases).

## Reporting a vulnerability

Please **do not open a public issue** for a vulnerability. Use GitHub's private reporting instead:
**Security > Report a vulnerability** on this repository.

Include what you can:

- the affected version (`macscan --version`) and macOS version,
- what an attacker needs first (for example "code running as the logged-in user"),
- what they gain (for example "write to a root-owned file"),
- steps or a proof of concept that does not harm the reporter's or anyone else's system.

You can expect an acknowledgement within a week. Fixes are released as a new version with a CHANGELOG entry that credits you, unless you prefer not to be named.

**Never attach scan reports.** They contain personal data about the machine they came from.

## Threat model in short

The tool assumes that anything running as the logged-in user may be hostile, because that is what it is looking for. A finding is in scope when such a process can use mac-triage to:

- run code, write, delete or change ownership of files as root,
- read files it could not otherwise read,
- hide from a scan or make a report lie (for example by injecting fake lines or terminal escapes),
- abuse the Full Disk Access granted to `macscan-helper`.

Out of scope: attackers who already have root, physical access, and the accuracy of third-party YARA rules or ClamAV signatures (report those upstream).
