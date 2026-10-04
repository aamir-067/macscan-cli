# shellcheck shell=bash
# Help pages for macscan. Plain text, no root needed: `macscan help [topic]`.

HELP_TOPICS="scan reports flags auto update settings privacy troubleshooting"

help_overview(){
  cat <<EOF
macscan $VERSION: read-only security scanner for macOS

USAGE
  macscan [command] [options]

START HERE
  macscan --quick              Quick scan, a few minutes. Good first run.
  macscan                      Full deep scan in the background (can take a while)
  macscan status               Is a scan running? When was the last one?
  macscan doctor               Check the setup and get the exact fix for any problem
  macscan last                 Open the latest report

EXAMPLES
  macscan --only 05,15                       Only launch items and browser extensions
  macscan --only 17 --days 7                 Code repositories, changes from the last week
  macscan --quick --no-notify                Quick scan without a notification
  macscan --ignore "com.example.tool" --reason "My own tool, checked"
  macscan --set AUTO_INTERVAL_DAYS=14        Automatic full scan every two weeks
  macscan update                             Install the newest version

Commands work with or without dashes: "macscan status" is "macscan --status".
Detailed help: macscan help <topic>   Topics: $HELP_TOPICS
All options:   macscan help options
EOF
}

help_options(){
  cat <<'EOF'
SCANNING
  macscan                      Full deep scan (background service with Full Disk Access, live progress)
  macscan --quick              Fast scan: skips file-system sweep, logs, YARA and ClamAV
  macscan --foreground         Run inside this terminal instead (terminal needs Full Disk Access)
  macscan --only 05,15         Run only these modules (see macscan modules)
  macscan --skip 19,20         Skip these modules
  macscan --days N             Look-back window for "recent" checks
  macscan --no-yara            Skip the YARA scan
  macscan --no-clamav          Skip the ClamAV scan
  macscan --clamav-full        ClamAV scans your whole home folder (slow)
  macscan --no-logs            Skip the unified log module
  macscan --include-trash      Also scan the Trash (file sweep, YARA, ClamAV)
  macscan --output /full/path  Save this scan somewhere else
  macscan --only-if-findings   Delete the report if nothing suspicious is found
  macscan --always-report      Keep the report even when clean
  macscan --no-zip             Don't create a zip
  macscan --no-notify          No notification when done
  macscan --open               Open the report when done
  macscan --keep N             Keep N reports after this scan

WHILE A SCAN RUNS
  macscan status               Schedule, running scan and its progress, last result, tool versions
  macscan log                  Watch a running scan (Ctrl+C stops watching, not the scan)
  macscan stop                 Stop a running scan (manual or automatic)

AUTOMATIC SCANS
  macscan auto on|off          Weekly scans plus a scan when a new app is installed

REPORTS AND FLAGS
  macscan last                 Open the latest full report
  macscan reports              List saved reports
  macscan history              Results of past scans
  macscan clean                Apply report cleanup now
  macscan ignore "TEXT" --reason "WHY"
                               Acknowledge flags containing TEXT: they move to an
                               "Acknowledged" section and stop counting
  macscan ignored              List acknowledged flags
  macscan unignore TEXT|N      Stop acknowledging (exact TEXT, or number from ignored)

UPDATING
  macscan update --check       See if a newer version is available
  macscan update [--yes]       Download, verify and install the newest version

SETUP AND MAINTENANCE
  macscan doctor               Check the whole setup, with the fix for each problem
  macscan check-fda            Check the scanner has Full Disk Access
  macscan verify               Check the installed files against the install manifest
  macscan update-rules         Update YARA rules and ClamAV signatures now
  macscan modules              List scan modules
  macscan config               Show settings
  macscan set KEY=VALUE        Change a setting (see macscan help settings)
  macscan uninstall            Remove macscan (your reports are kept)
  macscan version | help [topic]
EOF
}

help_topic(){
  case "$1" in
    scan) cat <<'EOF'
SCANNING

  macscan --quick      A few minutes. Checks persistence, accounts, remote access,
                       processes, network, privacy permissions, apps, browsers,
                       developer tools and code repositories. Skips the slow parts:
                       file-system sweep (14), logs (18), YARA (19) and ClamAV (20).
  macscan              Everything. Can take from 15 minutes to over an hour, mostly
                       for YARA and ClamAV. It runs in a background service, so you
                       can close the terminal; "macscan log" watches it again.

  Pick modules:        macscan modules            (list with numbers and titles)
                       macscan --only 05,15       (just these)
                       macscan --skip 19,20       (all except these)
  Look-back window:    macscan --days 14          ("recently created" means 14 days)

  The Mac going to sleep is fine: the scan pauses and continues on wake, and the
  report says which modules ran across a sleep. While a scan runs, the Mac is kept
  from idle-sleeping; closing a laptop lid still sleeps it.

  macscan never changes, deletes or quarantines anything. It only reads and reports.
EOF
    ;;
    reports) cat <<'EOF'
REPORTS

  Where:   ~/Documents/mac-triage-reports/scan_<date>_<mode>/  (change with: macscan set REPORT_DIR=/path)
  Files:   00-SUMMARY_<date>.txt   start here: red flags, most severe first, then what is
                                   new or removed since the last scan
           FULL-REPORT_<date>.txt  summary plus every module's full output
           report.json             the same findings for scripts and tools
           modules/NN-name.txt     one file per module

  macscan last          open the newest full report
  macscan reports       list saved reports
  macscan history       one line per past scan

  The newest 4 reports are kept and anything older than 30 days is removed
  (settings KEEP_REPORTS and MAX_AGE_DAYS). Secrets that appear in configs or
  command lines are masked before anything is written. Reports still contain
  personal data (file names, apps, URLs): treat them as private.
EOF
    ;;
    flags) cat <<'EOF'
READING AND ACKNOWLEDGING FLAGS

  A flag looks like:  [HIGH] [05-persistence-launchd] Launch item runs from an unusual location: ...
  Severity:   CRITICAL  known malware traits, tampering, credential theft in progress
              HIGH      unsigned or hidden auto-start code, risky permissions or policies
              MEDIUM    worth a look: unknown but plausible items, coverage gaps
              LOW       hygiene
  A flag is something to verify, not proof of malware. "New since last scan" items
  are the strongest early-warning signal.

  When you have checked a flag and it is fine, acknowledge it so it stops counting:
    macscan ignore "part of the flag text" --reason "why it is fine"
    macscan ignored                  list them (with date and reason)
    macscan unignore 1               stop acknowledging number 1
  Matching is by substring, so use at least 8 specific characters. Acknowledged
  flags still appear in the report, in their own section, so nothing is hidden.
EOF
    ;;
    auto) cat <<'EOF'
AUTOMATIC SCANS

  On by default: a full scan every 7 days, and a scan a couple of minutes after a
  new app appears in /Applications or ~/Applications. Automatic scans wait when the
  battery is below 30 percent.

    macscan auto off                       turn them off
    macscan auto on                        turn them on again
    macscan set AUTO_INTERVAL_DAYS=14      every two weeks
    macscan set AUTO_ON_NEW_APP=no         not when apps are installed
    macscan set AUTO_MIN_BATTERY=50        wait for more battery
    macscan set NOTIFY=dialog              end with a dialog that can open the report
EOF
    ;;
    update) cat <<'EOF'
UPDATING

  macscan update --check     is a newer version available?
  macscan update             download, verify (SHA-256) and install it
  With Homebrew:             brew upgrade macscan && macscan-setup

  Upgrades keep your settings, scan history, acknowledged flags, YARA rules and
  reports, and add new settings with their defaults. Full Disk Access stays valid
  unless the helper program itself changed; the installer tells you when it did.
  The installer refuses to run while a scan is in progress, and refuses to install
  an older version over a newer one unless you pass --allow-downgrade.

  Remove macscan:  macscan uninstall      (Homebrew: macscan-setup --uninstall, then brew uninstall macscan)
EOF
    ;;
    settings) cat <<'EOF'
SETTINGS   (macscan config shows them, macscan set KEY=VALUE changes one)

  REPORT_DIR          where reports go (full path)
  KEEP_REPORTS        how many reports to keep (4)
  MAX_AGE_DAYS        remove reports older than this; the newest is always kept (30)
  LOOKBACK_DAYS       window for "recently created or granted" checks (60)
  AUTO                automatic scans on|off (on); use macscan auto on|off
  AUTO_INTERVAL_DAYS  days between automatic full scans (7)
  AUTO_ON_NEW_APP     scan when a new app is installed, yes|no (yes)
  AUTO_MIN_BATTERY    postpone automatic scans below this battery percent (30)
  ONLY_IF_FINDINGS    delete clean reports, yes|no (no)
  NOTIFY              yes|no|dialog (yes); dialog offers an Open report button
  ZIP                 also save a zip of each report, yes|no (yes)
  YARA, CLAMAV        run those scanners, yes|no (yes)
  CLAMAV_SCOPE        standard|full (standard); full scans the whole home folder
  INCLUDE_TRASH       also sweep the Trash, yes|no (no)
  SUPPLY_CHAIN        run osv-scanner and gitleaks on your repositories, yes|no (no)
  EXEC_MONITOR        record programs started during a scan with eslogger, yes|no (no)

  Example:  macscan set KEEP_REPORTS=8
EOF
    ;;
    privacy) cat <<'EOF'
PRIVACY

  Nothing about your Mac is sent anywhere. Reports stay on your disk.
  Network use: YARA rules (weekly) and ClamAV signatures (daily) are downloaded by
  your user account; macscan update checks GitHub for new versions; the network
  module looks up names for addresses your Mac is already talking to.
  Reports contain personal data (file names, app lists, download URLs). Do not
  upload them; when asking for help, share only the one or two lines needed.
EOF
    ;;
    troubleshooting) cat <<'EOF'
TROUBLESHOOTING

  First run:  macscan doctor    It checks everything below and prints the fix.

  "Full Disk Access: no"
      System Settings > Privacy & Security > Full Disk Access: add
      /usr/local/mac-triage/bin/macscan-helper and switch it on, then: macscan check-fda
  The scan did not start, or "Could not start the scan service"
      macscan install-services, then try again; or run in the terminal: macscan --foreground
  A report could not be saved
      It is kept in /usr/local/mac-triage/state/undelivered (root only). Check the report
      folder setting (macscan config) and that the folder is not a symlink.
  "Install integrity: PROBLEMS FOUND"
      Something changed files of the installation. Run macscan verify for details and
      reinstall with macscan update --yes (or macscan-setup). Treat it as suspicious.
  macscan: command not found
      It was uninstalled, or /usr/local/bin is missing from PATH. Reinstall:
      macscan-setup (Homebrew) or sudo bash install-mac-triage.sh
EOF
    ;;
    options|all) help_options;;
    *) echo "No help topic \"$1\". Topics: $HELP_TOPICS options"; return 1;;
  esac
}

# help_main [topic]
help_main(){
  if [ -z "${1:-}" ]; then help_overview; else help_topic "$1"; fi
}

# cli_alias <word>: maps plain-word commands to their --flag form ("" when not a command).
cli_alias(){
  case "$1" in
    status|stop|log|last|reports|history|clean|modules|config|verify|update|doctor|version|uninstall|ignored|ignore|unignore|set|auto|check-fda|update-rules|install-services)
      echo "--$1";;
    quick) echo "--quick";;
    *) echo "";;
  esac
}
