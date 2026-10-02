# shellcheck shell=bash
# shellcheck disable=SC2034  # these variables are read by run.sh and the modules
# Engine option parsing. Sets the scan variables from config defaults and argv.

options_defaults(){
  DAYS="$LOOKBACK_DAYS"; OUTBASE="$REPORT_DIR"; KEEP="$KEEP_REPORTS"; QUICK=0; ONLY=""; SKIP=""; TASK="scan"
  DO_YARA="$YARA"; DO_CLAM="$CLAMAV"; CLAM_SCOPE="$CLAMAV_SCOPE"; NO_LOGS=0; OPEN=0
  OIF="$ONLY_IF_FINDINGS"; DO_ZIP="$ZIP"; DO_NOTIFY="$NOTIFY"; FG=0
}

# options_parse "$@": returns 2 on an unknown option or bad value.
options_parse(){
  while [ $# -gt 0 ]; do
    case "$1" in
      --foreground) FG=1; shift;;
      --quick) QUICK=1; REASON="manual quick scan"; shift;;
      --no-yara) DO_YARA=no; shift;;
      --no-clamav) DO_CLAM=no; shift;;
      --clamav-full) CLAM_SCOPE=full; shift;;
      --no-logs) NO_LOGS=1; shift;;
      --days) DAYS="${2:-}"; shift 2;;
      --only) ONLY="${2:-}"; shift 2;;
      --skip) SKIP="${2:-}"; shift 2;;
      --output) OUTBASE="${2:-}"; shift 2;;
      --keep) KEEP="${2:-}"; shift 2;;
      --only-if-findings) OIF=yes; shift;;
      --always-report) OIF=no; shift;;
      --no-zip) DO_ZIP=no; shift;;
      --no-notify) DO_NOTIFY=no; shift;;
      --open) OPEN=1; shift;;
      --task) TASK="${2:-}"; shift 2;;
      *) echo "Unknown option: $1 (see macscan --help)"; return 2;;
    esac
  done
  options_validate
}

options_validate(){
  local n
  for n in "$DAYS" "$KEEP" "$MAX_AGE_DAYS" "$AUTO_INTERVAL_DAYS"; do
    case "$n" in ''|*[!0-9]*) echo "Expected a number, got: $n"; return 2;; esac
  done
  [ "$KEEP" -ge 1 ] || KEEP=1
  case "$OUTBASE" in /*) ;; *) echo "--output needs a full path"; return 2;; esac
  case "$OUTBASE" in *"/../"*|*"/..") echo "--output must not contain .."; return 2;; esac
  case "$ONLY$SKIP" in *[!0-9,]*) echo "--only and --skip take module numbers like 05,15"; return 2;; esac
  case "$TASK" in scan|check-fda|update-rules|clean) ;; *) echo "Unknown task: $TASK"; return 2;; esac
  ONLY=$(module_list "$ONLY"); SKIP=$(module_list "$SKIP")
  return 0
}

# module_list "5,15" -> "05,15" so single-digit module numbers work.
module_list(){ printf '%s' "$1" | tr ',' '\n' | awk 'NF{printf "%s%02d", (n++ ? "," : ""), $1}'; }
