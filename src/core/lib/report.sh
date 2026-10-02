# shellcheck shell=bash
# Report assembly: inventory diff, summary, full report, retention.

cleanup_reports(){
  [ -d "$OUTBASE" ] || return 0
  local all newest n
  all=$(find "$OUTBASE" -maxdepth 1 -type d -name 'scan_*' | sort)
  newest=$(echo "$all" | tail -1)
  echo "$all" | while IFS= read -r d; do
    if [ -n "$d" ] && [ "$d" != "$newest" ] && [ -n "$(find "$d" -maxdepth 0 -mtime +"$MAX_AGE_DAYS")" ]; then rm -rf "$d" "$d.zip"; fi
  done
  all=$(find "$OUTBASE" -maxdepth 1 -type d -name 'scan_*' | sort); n=$(echo "$all" | grep -c . || true)
  if [ "$n" -gt "$KEEP" ]; then echo "$all" | head -n $((n-KEEP)) | while IFS= read -r d; do rm -rf "$d" "$d.zip"; done; fi
  for z in "$OUTBASE"/scan_*.zip; do if [ -f "$z" ] && [ ! -d "${z%.zip}" ]; then rm -f "$z"; fi; done
  return 0
}

# diff_inventories: compares $INV/*.txt with the last scan's copy in $STATE/inv/last,
# writes the human summary to $NEWS and "new since last scan" flags to $RUN/.flags.raw.
diff_inventories(){
  local lastd="$STATE/inv/last" f c l
  mkdir -p "$lastd"; : > "$NEWS"
  for f in "$INV"/*.txt; do
    [ -f "$f" ] || continue
    c=$(basename "$f" .txt); sort -u "$f" -o "$f"
    if [ -f "$lastd/$c.txt" ]; then
      comm -13 "$lastd/$c.txt" "$f" > "$f.add"; comm -23 "$lastd/$c.txt" "$f" > "$f.rem"
      if [ -s "$f.add" ]; then
        echo "[$c] new:" >> "$NEWS"; sed 's/^/  + /' "$f.add" >> "$NEWS"
        while IFS= read -r l; do echo "[new since last scan] [$c] $l" >> "$RUN/.flags.raw"; done < "$f.add"
      fi
      [ -s "$f.rem" ] && { echo "[$c] removed:" >> "$NEWS"; sed 's/^/  - /' "$f.rem" >> "$NEWS"; }
      rm -f "$f.add" "$f.rem"
    else echo "[$c] baseline saved ($(grep -c . "$f") items)" >> "$NEWS"; fi
    cp "$f" "$lastd/$c.txt"
  done
  rm -rf "$INV"
}

# write_summary: prints the summary text (caller redirects it).
write_summary(){
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
}
