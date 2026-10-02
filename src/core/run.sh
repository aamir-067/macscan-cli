#!/bin/bash
# mac-triage scan engine. Runs as root and only reads.
ROOT="/usr/local/mac-triage"; STATE="$ROOT/state"; VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo unknown)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=C
unset PERL5LIB PERLLIB PERL5OPT BASH_ENV ENV
umask 077
[ "$EUID" -eq 0 ] || { echo "Must run as root."; exit 1; }
source "$ROOT/config"
YARAC=/opt/homebrew/bin/yarac; FRESHCLAM=/opt/homebrew/bin/freshclam
LOG="$STATE/current.log"; PIDF="$STATE/running.pid"; HIST="$STATE/history.log"

MODE="manual"; REASON="manual scan"; FG=0; APPS_NOW=""
case "${1:-}" in
  --from-request) shift; if [ -f "$STATE/request" ]; then eval "set -- $(cat "$STATE/request")"; rm -f "$STATE/request"; fi;;
  --scheduled) MODE="auto"; shift;;
esac

DAYS="$LOOKBACK_DAYS"; OUTBASE="$REPORT_DIR"; KEEP="$KEEP_REPORTS"; QUICK=0; ONLY=""; SKIP=""; TASK="scan"
DO_YARA="$YARA"; DO_CLAM="$CLAMAV"; CLAM_SCOPE="$CLAMAV_SCOPE"; NO_LOGS=0; OPEN=0
OIF="$ONLY_IF_FINDINGS"; DO_ZIP="$ZIP"; DO_NOTIFY="$NOTIFY"
while [ $# -gt 0 ]; do
  case "$1" in
    --foreground) FG=1; shift;;
    --quick) QUICK=1; REASON="manual quick scan"; shift;;
    --no-yara) DO_YARA=no; shift;;
    --no-clamav) DO_CLAM=no; shift;;
    --clamav-full) CLAM_SCOPE=full; shift;;
    --no-logs) NO_LOGS=1; shift;;
    --days) DAYS="$2"; shift 2;;
    --only) ONLY="$2"; shift 2;;
    --skip) SKIP="$2"; shift 2;;
    --output) OUTBASE="$2"; shift 2;;
    --keep) KEEP="$2"; shift 2;;
    --only-if-findings) OIF=yes; shift;;
    --always-report) OIF=no; shift;;
    --no-zip) DO_ZIP=no; shift;;
    --no-notify) DO_NOTIFY=no; shift;;
    --open) OPEN=1; shift;;
    --task) TASK="$2"; shift 2;;
    *) echo "Unknown option: $1 (see macscan --help)"; exit 2;;
  esac
done
for n in "$DAYS" "$KEEP" "$MAX_AGE_DAYS" "$AUTO_INTERVAL_DAYS"; do case "$n" in ''|*[!0-9]*) echo "Expected a number, got: $n"; exit 2;; esac; done
[ "$KEEP" -ge 1 ] || KEEP=1
case "$OUTBASE" in /*) ;; *) echo "--output needs a full path"; exit 2;; esac

export U="$TARGET_USER"
UID_N="$(id -u "$U" 2>/dev/null)"; export UID_N
[ -n "$UID_N" ] || { echo "User $U not found."; exit 1; }
UH="$(dscl . -read "/Users/$U" NFSHomeDirectory | awk '{print $2}')"; export UH
export DAYS QUICK CLAM_SCOPE OUTBASE ROOT STATE
export RUN="" INV=""
source "$ROOT/core/common.sh"

notify(){
  [ "$DO_NOTIFY" = yes ] || return 0
  local t="${1//\"/}" m="${2//\"/}"
  launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/osascript -e "display notification \"$m\" with title \"$t\" sound name \"Glass\"" >/dev/null 2>&1
}
app_list(){ find /Applications /Users/*/Applications -maxdepth 2 -name "*.app" -not -path "*.app/*" 2>/dev/null | sort; }
low_battery(){
  local b pct; b=$(pmset -g batt 2>/dev/null)
  echo "$b" | grep -q "Battery Power" || return 1
  pct=$(echo "$b" | grep -o '[0-9]*%' | head -1 | tr -d %)
  [ -n "$pct" ] && [ "$pct" -lt "$AUTO_MIN_BATTERY" ]
}

update_rules(){
  local now last tmp
  [ -x "$YARAC" ] || { echo "YARA is not installed, skipping rule update."; return 0; }
  now=$(date +%s); last=$(cat "$STATE/rules-updated" 2>/dev/null || echo 0)
  if [ "${1:-}" != force ] && [ $((now-last)) -lt 604800 ] && [ -f "$ROOT/rules/all.yarc" ]; then return 0; fi
  echo "Updating YARA rules (runs as $U)..."
  tmp=$(sudo -u "$U" /usr/bin/mktemp -d /tmp/mactriage-rules.XXXXXX) || return 0
  cp "$ROOT/rules/custom.yar" "$tmp/custom.yar"; chown "$U" "$tmp/custom.yar"
  sudo -u "$U" -H /bin/bash -c '
    cd "$1" || exit 1; Y="$2"
    if /usr/bin/curl -fsSL --max-time 300 -o forge.zip "https://github.com/YARAHQ/yara-forge/releases/latest/download/yara-forge-rules-core.zip"; then
      mkdir -p forge && /usr/bin/ditto -x -k forge.zip forge 2>/dev/null
      f=$(find forge -name "*.yar" | head -1)
      if [ -n "$f" ] && "$Y" -w "$f" /dev/null 2>/dev/null; then cp "$f" forge.yar; echo "  YARA Forge core rules: ok"; else echo "  YARA Forge core rules: did not compile, skipped"; fi
    else echo "  YARA Forge core rules: download failed"; fi
    if /usr/bin/curl -fsSL --max-time 900 -o el.zip "https://github.com/elastic/protections-artifacts/archive/refs/heads/main.zip"; then
      mkdir -p el && /usr/bin/ditto -x -k el.zip el 2>/dev/null
      : > elastic.yar; ok=0
      find el -path "*/yara/rules/*" \( -name "MacOS_*.yar" -o -name "Multi_*.yar" \) > el.list
      while IFS= read -r r; do if "$Y" -w "$r" /dev/null 2>/dev/null; then echo "include \"$PWD/$r\"" >> elastic.yar; ok=$((ok+1)); fi; done < el.list
      if [ "$ok" -gt 0 ]; then echo "  Elastic macOS and multi-platform rules: $ok files"; else rm -f elastic.yar; fi
    else echo "  Elastic rules: download failed"; fi
    A="custom:custom.yar"; F=""; E=""
    [ -f forge.yar ] && F="forge:forge.yar"; [ -f elastic.yar ] && E="elastic:elastic.yar"
    if "$Y" -w $A $F $E all.yarc 2>yarac.err; then echo "custom $F $E" > sets.txt
    elif "$Y" -w $A $F all.yarc 2>>yarac.err; then echo "custom $F" > sets.txt
    else "$Y" -w $A all.yarc 2>>yarac.err && echo "custom" > sets.txt; fi
  ' _ "$tmp" "$YARAC"
  if [ -s "$tmp/all.yarc" ]; then
    cp "$tmp/all.yarc" "$ROOT/rules/all.yarc.new" && mv -f "$ROOT/rules/all.yarc.new" "$ROOT/rules/all.yarc"
    sed -e 's/forge:forge.yar/yara-forge/' -e 's/elastic:elastic.yar/elastic/' "$tmp/sets.txt" > "$ROOT/rules/sets.txt" 2>/dev/null
    chmod 644 "$ROOT/rules/all.yarc" "$ROOT/rules/sets.txt"; date +%s > "$STATE/rules-updated"
    echo "  Compiled rule sets: $(cat "$ROOT/rules/sets.txt")"
  else echo "  Rule compile failed, keeping the previous rules."; fi
  rm -rf "$tmp"
}

update_clam(){
  local now last
  [ -x "$FRESHCLAM" ] || return 0
  now=$(date +%s); last=$(cat "$STATE/clam-updated" 2>/dev/null || echo 0)
  if [ "${1:-}" != force ] && [ $((now-last)) -lt 86400 ]; then return 0; fi
  echo "Updating ClamAV signatures (runs as $U)..."
  if sudo -u "$U" -H "$FRESHCLAM" --quiet; then date +%s > "$STATE/clam-updated"; echo "  ClamAV signatures: ok"
  else echo "  ClamAV update failed, will retry next scan."; fi
}

cleanup_reports(){
  [ -d "$OUTBASE" ] || return 0
  local all newest n
  all=$(find "$OUTBASE" -maxdepth 1 -type d -name 'scan_*' | sort)
  newest=$(echo "$all" | tail -1)
  echo "$all" | while IFS= read -r d; do
    [ -n "$d" ] && [ "$d" != "$newest" ] && [ -n "$(find "$d" -maxdepth 0 -mtime +"$MAX_AGE_DAYS")" ] && rm -rf "$d" "$d.zip"
  done
  all=$(find "$OUTBASE" -maxdepth 1 -type d -name 'scan_*' | sort); n=$(echo "$all" | grep -c .)
  if [ "$n" -gt "$KEEP" ]; then echo "$all" | head -n $((n-KEEP)) | while IFS= read -r d; do rm -rf "$d" "$d.zip"; done; fi
  for z in "$OUTBASE"/scan_*.zip; do [ -f "$z" ] && [ ! -d "${z%.zip}" ] && rm -f "$z"; done
  return 0
}

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
trap 'rm -f "$PIDF"' EXIT
trap 'echo; echo "Scan stopped by request."; echo "$(date "+%F %T") | $MODE | stopped | $REASON" >> "$HIST"; exit 130' TERM INT
exec > >(tee "$LOG") 2>&1
echo "@@START@@ $(date)"

source "$ROOT/core/fda.sh"
[ "$FG" = 0 ] && echo "$FDA (checked $(date '+%F %H:%M'))" > "$STATE/fda-status"
if [ "$TASK" = check-fda ]; then
  echo "Full Disk Access for the scanner: $FDA"; echo "Details: $FDA_DETAIL"
  [ "$FDA" = no ] && echo "Add $ROOT/bin/macscan-helper in System Settings > Privacy & Security > Full Disk Access, then run this again."
  echo "@@DONE@@"; exit 0
fi

STAMP=$(date +%Y-%m-%d_%H-%M-%S)
[ -L "$OUTBASE" ] && { echo "The report folder is a symlink. Refusing to write there."; exit 4; }
mkdir -p "$OUTBASE" && chown "$U" "$OUTBASE"
RUN="$OUTBASE/scan_${STAMP}_${MODE}"; mkdir -p "$RUN/modules"; export RUN
INV="$STATE/inv/new_$STAMP"; mkdir -p "$INV"; export INV
: > "$RUN/.flags.raw"
T0=$(date +%s)
echo "mac-triage $VERSION | $MODE | $REASON"
echo "User: $U | look-back: $DAYS days | Full Disk Access: $FDA"
echo "Output: $RUN"
[ "$FDA" = no ] && { MODULE=core flag "Scanner had no Full Disk Access, some areas could not be read"; }
if [ "$QUICK" = 0 ]; then
  [ "$DO_YARA" = yes ] && update_rules
  [ "$DO_CLAM" = yes ] && update_clam
fi
echo

MODS=("$ROOT"/modules/*.sh); TOTAL=${#MODS[@]}; i=0
for m in "${MODS[@]}"; do
  i=$((i+1)); name=$(basename "$m" .sh); num=${name%%-*}
  if [ -n "$ONLY" ] && ! echo ",$ONLY," | grep -q ",$num,"; then continue; fi
  if [ -n "$SKIP" ] && echo ",$SKIP," | grep -q ",$num,"; then continue; fi
  if [ "$QUICK" = 1 ]; then case "$name" in 14-*|18-*|19-*|20-*) continue;; esac; fi
  [ "$NO_LOGS" = 1 ] && [ "$name" != "${name%logs}" ] && continue
  case "$name" in *-yara) [ "$DO_YARA" = yes ] || continue;; *-clamav) [ "$DO_CLAM" = yes ] || continue;; esac
  t=$(date +%s); printf "[%2d/%d] %-28s " "$i" "$TOTAL" "$name"
  export MODULE="$name"
  { echo "#### $name | $(date)"; tmo 14400 /bin/bash "$m"; } 2>&1 | redact > "$RUN/modules/$name.txt"
  echo "done in $(( $(date +%s) - t ))s"
done

LASTD="$STATE/inv/last"; mkdir -p "$LASTD"; NEWS="$RUN/.news"; : > "$NEWS"
for f in "$INV"/*.txt; do
  [ -f "$f" ] || continue
  c=$(basename "$f" .txt); sort -u "$f" -o "$f"
  if [ -f "$LASTD/$c.txt" ]; then
    comm -13 "$LASTD/$c.txt" "$f" > "$f.add"; comm -23 "$LASTD/$c.txt" "$f" > "$f.rem"
    if [ -s "$f.add" ]; then
      echo "[$c] new:" >> "$NEWS"; sed 's/^/  + /' "$f.add" >> "$NEWS"
      while IFS= read -r l; do echo "[new since last scan] [$c] $l" >> "$RUN/.flags.raw"; done < "$f.add"
    fi
    [ -s "$f.rem" ] && { echo "[$c] removed:" >> "$NEWS"; sed 's/^/  - /' "$f.rem" >> "$NEWS"; }
    rm -f "$f.add" "$f.rem"
  else echo "[$c] baseline saved ($(grep -c . "$f") items)" >> "$NEWS"; fi
  cp "$f" "$LASTD/$c.txt"
done
rm -rf "$INV"

NFLAGS=$(sort -u "$RUN/.flags.raw" | grep -c .)
SUM="$RUN/00-SUMMARY_${STAMP}.txt"
{
  echo "mac-triage $VERSION scan summary"
  echo "Date: $(date) | Mode: $MODE | Reason: $REASON"
  echo "User: $U | Look-back: $DAYS days | Full Disk Access: $FDA | Duration: $(( ($(date +%s)-T0)/60 )) min"
  echo "YARA rules: $(cat "$ROOT/rules/sets.txt" 2>/dev/null || echo none) | ClamAV: $( [ -x /opt/homebrew/bin/clamscan ] && echo installed || echo not installed)"
  echo
  echo "RED FLAGS: $NFLAGS"
  echo "Not every flag means malware. Each one is something to verify."
  echo
  sort -u "$RUN/.flags.raw"
  echo
  echo "NEW OR REMOVED SINCE THE LAST SCAN"
  cat "$NEWS"
} | redact > "$SUM"
rm -f "$RUN/.flags.raw" "$NEWS"
REPORT="$RUN/FULL-REPORT_${STAMP}.txt"
{ cat "$SUM"; for f in "$RUN"/modules/*.txt; do echo; echo; cat "$f"; done; } > "$REPORT"

if [ "$OIF" = yes ] && [ "$NFLAGS" -eq 0 ]; then rm -rf "$RUN"; RESULT="clean, report not kept"
else
  [ "$DO_ZIP" = yes ] && ( cd "$OUTBASE" && ditto -c -k --keepParent "$(basename "$RUN")" "$RUN.zip" ) && chown "$U" "$RUN.zip"
  chown -R "$U" "$RUN"; RESULT="report: $RUN"
fi
cleanup_reports
[ "$QUICK" = 0 ] && [ -z "$ONLY$SKIP" ] && date +%s > "$STATE/last-full-scan"
[ "$MODE" = auto ] && [ -n "$APPS_NOW" ] && { cp "$APPS_NOW" "$STATE/apps.list"; rm -f "$APPS_NOW"; }
MINS=$(( ($(date +%s)-T0)/60 ))
echo "$(date '+%F %T') | $MODE | $REASON | flags: $NFLAGS | $MINS min | $RESULT" >> "$HIST"
echo; echo "Finished in $MINS minutes. Red flags: $NFLAGS"; echo "$RESULT"
if [ "$NFLAGS" -gt 0 ]; then notify "Mac scan: $NFLAGS red flags" "Report saved in $(basename "$OUTBASE")"
else notify "Mac scan complete" "No red flags found."; fi
[ "$OPEN" = 1 ] && [ -f "$REPORT" ] && launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/open "$REPORT"
echo "@@DONE@@"
