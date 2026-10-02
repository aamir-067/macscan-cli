#!/bin/bash
# mac-triage scan engine. Runs as root and only reads.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; STATE="$ROOT/state"; VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo unknown)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=C
unset PERL5LIB PERLLIB PERL5OPT BASH_ENV ENV
umask 077
[ "$EUID" -eq 0 ] || { echo "Must run as root."; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/config"
# shellcheck disable=SC2034  # used by core/lib/rules.sh
YARAC=/opt/homebrew/bin/yarac
# shellcheck disable=SC2034
FRESHCLAM=/opt/homebrew/bin/freshclam
LOG="$STATE/current.log"; PIDF="$STATE/running.pid"; HIST="$STATE/history.log"
for lib in options modules auto notify rules report; do
  # shellcheck source=/dev/null
  source "$ROOT/core/lib/$lib.sh"
done

MODE="manual"; REASON="manual scan"; APPS_NOW=""
case "${1:-}" in
  --from-request) shift; if [ -f "$STATE/request" ]; then eval "set -- $(cat "$STATE/request")"; rm -f "$STATE/request"; fi;;
  --scheduled) MODE="auto"; shift;;
esac

options_defaults
options_parse "$@" || exit 2

export U="$TARGET_USER"
UID_N="$(id -u "$U" 2>/dev/null)"; export UID_N
[ -n "$UID_N" ] || { echo "User $U not found."; exit 1; }
UH="$(dscl . -read "/Users/$U" NFSHomeDirectory | awk '{print $2}')"; export UH
export DAYS QUICK CLAM_SCOPE OUTBASE ROOT STATE
export RUN="" INV=""
# shellcheck source=common.sh
source "$ROOT/core/common.sh"

if [ "$TASK" = update-rules ]; then update_rules force; update_clam force; exit 0; fi
if [ "$TASK" = clean ]; then cleanup_reports; echo "Report cleanup done."; exit 0; fi

if [ "$MODE" = auto ]; then
  [ "$AUTO" = on ] || exit 0
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then exit 0; fi
  APPS_NOW=$(mktemp /tmp/mactriage.XXXXXX); app_list > "$APPS_NOW"
  [ -f "$STATE/apps.list" ] || cp "$APPS_NOW" "$STATE/apps.list"
  SHOULD=0
  if [ "$AUTO_ON_NEW_APP" = yes ] && [ -n "$(comm -13 "$STATE/apps.list" "$APPS_NOW")" ]; then
    sleep 120; app_list > "$APPS_NOW"
    ADDED=$(comm -13 "$STATE/apps.list" "$APPS_NOW" | sed 's#.*/##' | tr '\n' ' ')
    [ -n "$ADDED" ] && { SHOULD=1; REASON="new app installed: $ADDED"; }
  fi
  LASTFULL=$(cat "$STATE/last-full-scan" 2>/dev/null || echo 0)
  if [ "$SHOULD" = 0 ] && [ $(( $(date +%s) - LASTFULL )) -ge $(( AUTO_INTERVAL_DAYS * 86400 )) ]; then
    SHOULD=1; REASON="scheduled scan (every $AUTO_INTERVAL_DAYS days)"
  fi
  if [ "$SHOULD" = 0 ]; then cp "$APPS_NOW" "$STATE/apps.list"; rm -f "$APPS_NOW"; exit 0; fi
  if low_battery; then echo "$(date '+%F %T') | auto | postponed (low battery) | $REASON" >> "$HIST"; rm -f "$APPS_NOW"; exit 0; fi
fi

if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then echo "A scan is already running."; exit 3; fi
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"; [ -n "${NAME:-}" ] && rm -rf "${WORK:?}/$NAME"' EXIT
rm -rf "$STATE/work"
trap 'echo; echo "Scan stopped by request."; echo "$(date "+%F %T") | $MODE | stopped | $REASON" >> "$HIST"; exit 130' TERM INT
exec > >(tee "$LOG") 2>&1
echo "@@START@@ $(date)"

# shellcheck source=fda.sh
source "$ROOT/core/fda.sh"
[ "$FG" = 0 ] && echo "$FDA (checked $(date '+%F %H:%M'))" > "$STATE/fda-status"
if [ "$TASK" = check-fda ]; then
  echo "Full Disk Access for the scanner: $FDA"; echo "Details: $FDA_DETAIL"
  [ "$FDA" = no ] && echo "Add $ROOT/bin/macscan-helper in System Settings > Privacy & Security > Full Disk Access, then run this again."
  echo "@@DONE@@"; exit 0
fi

STAMP=$(date +%Y-%m-%d_%H-%M-%S)
# The report is built in a root-only staging folder and handed to the user at the end.
NAME="scan_${STAMP}_${MODE}"; WORK="$STATE/work"; mkdir -p "$WORK"; chmod 700 "$WORK"
RUN="$WORK/$NAME"; rm -rf "$RUN"; mkdir -p "$RUN/modules"; export RUN
INV="$STATE/inv/new_$STAMP"; mkdir -p "$INV"; export INV
: > "$RUN/.flags.raw"
T0=$(date +%s)
echo "mac-triage $VERSION | $MODE | $REASON"
echo "User: $U | look-back: $DAYS days | Full Disk Access: $FDA"
echo "Output: $OUTBASE/$NAME"
[ "$FDA" = no ] && { MODULE=core flag "Scanner had no Full Disk Access, some areas could not be read"; }
if [ "$QUICK" = 0 ]; then
  [ "$DO_YARA" = yes ] && update_rules
  [ "$DO_CLAM" = yes ] && update_clam
fi
echo

MODS=("$ROOT"/modules/*.sh); TOTAL=${#MODS[@]}; i=0
for m in "${MODS[@]}"; do
  i=$((i+1)); name=$(basename "$m" .sh)
  module_selected "$m" || continue
  t=$(date +%s); printf "[%2d/%d] %-28s " "$i" "$TOTAL" "$name"
  export MODULE="$name"
  { echo "#### $name | $(date)"; tmo 14400 /bin/bash "$m"; } 2>&1 | redact > "$RUN/modules/$name.txt"
  echo "done in $(( $(date +%s) - t ))s"
done

NEWS="$RUN/.news"
diff_inventories

NFLAGS=$(sort -u "$RUN/.flags.raw" | grep -c .)
SUM="$RUN/00-SUMMARY_${STAMP}.txt"
write_summary | redact > "$SUM"
rm -f "$RUN/.flags.raw" "$NEWS"
REPORT="$RUN/FULL-REPORT_${STAMP}.txt"
{ cat "$SUM"; for f in "$RUN"/modules/*.txt; do echo; echo; cat "$f"; done; } > "$REPORT"

if [ "$OIF" = yes ] && [ "$NFLAGS" -eq 0 ]; then RESULT="clean, report not kept"; REPORT=""
elif deliver_report; then RESULT="report: $OUTBASE/$NAME"; REPORT="$OUTBASE/$NAME/$(basename "$REPORT")"
else
  mkdir -p "$STATE/undelivered"; rm -rf "${STATE:?}/undelivered/$NAME"; mv "$RUN" "$STATE/undelivered/$NAME"
  RESULT="report could not be saved in $OUTBASE. It is kept (root only) in $STATE/undelivered/$NAME"; REPORT=""
fi
rm -rf "$RUN"
cleanup_reports
[ "$QUICK" = 0 ] && [ -z "$ONLY$SKIP" ] && date +%s > "$STATE/last-full-scan"
[ "$MODE" = auto ] && [ -n "$APPS_NOW" ] && { cp "$APPS_NOW" "$STATE/apps.list"; rm -f "$APPS_NOW"; }
MINS=$(( ($(date +%s)-T0)/60 ))
echo "$(date '+%F %T') | $MODE | $REASON | flags: $NFLAGS | $MINS min | $RESULT" >> "$HIST"
echo; echo "Finished in $MINS minutes. Red flags: $NFLAGS"; echo "$RESULT"
if [ "$NFLAGS" -gt 0 ]; then notify "Mac scan: $NFLAGS red flags" "Report saved in $(basename "$OUTBASE")"
else notify "Mac scan complete" "No red flags found."; fi
[ "$OPEN" = 1 ] && [ -n "$REPORT" ] && launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/open "$REPORT"
echo "@@DONE@@"
