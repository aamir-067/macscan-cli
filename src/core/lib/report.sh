# shellcheck shell=bash
# Report assembly: inventory diff, summary, full report, retention.

# Everything that writes into the user's report folder runs as the user
# (core/deliver.sh), never as root. See the comment at the top of deliver.sh.
as_target_user(){ sudo -u "$U" -H "$@"; }

# deliver_report: streams the staged report $WORK/$NAME to the user's report folder.
deliver_report(){
  (cd "$WORK" && tar -cf - "$NAME") | as_target_user /bin/bash "$ROOT/core/deliver.sh" receive "$OUTBASE" "$NAME" "$DO_ZIP"
}

cleanup_reports(){ as_target_user /bin/bash "$ROOT/core/deliver.sh" clean "$OUTBASE" "$KEEP" "$MAX_AGE_DAYS"; }

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

# prepare_flags: redacts and de-duplicates the raw flags, then sorts them by severity
# into $RUN/.flags.tsv (rank, severity, acknowledged, ack note, line). Acknowledged
# flags ($STATE/acknowledged.tsv, see macscan --ignore) are not counted.
# Sets NFLAGS, N_ACK and per-severity counts of the counted flags.
prepare_flags(){
  local t ack=/dev/null; t="$(printf '\t')"
  [ -f "$STATE/acknowledged.tsv" ] && ack="$STATE/acknowledged.tsv"
  sort -u "$RUN/.flags.raw" | redact > "$RUN/.flags"
  classify_flags "$RUN/.flags" "$ack" | sort -t "$t" -k1,1n -k5 > "$RUN/.flags.tsv"
  count(){ awk -F'\t' -v s="$1" -v a="$2" '$3==a && (s=="" || $2==s)' "$RUN/.flags.tsv" | grep -c . || true; }
  NFLAGS=$(count "" 0); N_ACK=$(count "" 1)
  N_CRIT=$(count critical 0); N_HIGH=$(count high 0); N_MED=$(count medium 0); N_LOW=$(count low 0)
}

# write_summary: prints the summary text (caller redirects it).
write_summary(){
  echo "mac-triage $VERSION scan summary"
  echo "Date: $(date) | Mode: $MODE | Reason: $REASON"
  echo "User: $U | Look-back: $DAYS days | Full Disk Access: $FDA | Duration: $(( ($(date +%s)-T0)/60 )) min"
  echo "YARA rules: $(cat "$ROOT/rules/sets.txt" 2>/dev/null || echo none) | ClamAV: $( [ -x /opt/homebrew/bin/clamscan ] && echo installed || echo not installed)"
  echo
  echo "RED FLAGS: $NFLAGS (critical $N_CRIT, high $N_HIGH, medium $N_MED, low $N_LOW)"
  echo "Not every flag means malware. Each one is something to verify. Most severe first."
  echo
  awk -F'\t' '$3==0 { printf "[%s] %s\n", toupper($2), $5 }' "$RUN/.flags.tsv"
  if [ "${N_ACK:-0}" -gt 0 ]; then
    echo
    echo "ACKNOWLEDGED (not counted): $N_ACK"
    awk -F'\t' '$3==1 { printf "[%s] %s\n    acknowledged: %s\n", toupper($2), $5, $4 }' "$RUN/.flags.tsv"
  fi
  echo
  echo "NEW OR REMOVED SINCE THE LAST SCAN"
  cat "$NEWS"
}

# write_json: prints report.json from $RUN/.flags.tsv (after prepare_flags).
# Each finding has a fingerprint (first 16 hex of SHA-256 over "module|message"),
# which stays the same across scans as long as the flag text does.
write_json(){
  MT_VERSION="$VERSION" MT_MODE="$MODE" MT_REASON="$REASON" MT_USER="$U" MT_DAYS="$DAYS" MT_FDA="$FDA" \
  MT_DURATION=$(( $(date +%s) - T0 )) MT_SETS="$(cat "$ROOT/rules/sets.txt" 2>/dev/null)" \
  MT_MODULES="$(ls "$RUN/modules" 2>/dev/null | sed 's/\.txt$//' | tr '\n' ' ')" \
  perl -MJSON::PP -MDigest::SHA=sha256_hex -MPOSIX=strftime -e '
    my (@f, %c);
    $c{$_} = 0 for qw(critical high medium low acknowledged);
    open(my $fh, "<", $ARGV[0]) or die;
    while (my $l = <$fh>) {
      chomp $l; my ($rank, $sev, $ack, $note, $line) = split /\t/, $l, 5;
      next unless defined $line && length $line;
      my ($module, $msg, $cat, $new) = ("", $line, undef, JSON::PP::false);
      if ($line =~ /^\[new since last scan\] \[([^\]]+)\] (.*)$/) { ($module, $cat, $msg, $new) = ("inventory", $1, $2, JSON::PP::true) }
      elsif ($line =~ /^\[([^\]]+)\] (.*)$/) { ($module, $msg) = ($1, $2) }
      if ($ack) { $c{acknowledged}++ } else { $c{$sev}++ }
      push @f, {
        severity => $sev, module => $module, (defined $cat ? (category => $cat) : ()),
        message => $msg, line => $line, new_since_last_scan => $new,
        fingerprint => substr(sha256_hex("$module|" . (defined $cat ? "$cat|" : "") . $msg), 0, 16),
        acknowledged => ($ack ? JSON::PP::true : JSON::PP::false),
        acknowledgement => ($ack ? $note : undef),
      };
    }
    my $total = 0; $total += $c{$_} for qw(critical high medium low);
    my $doc = {
      schema_version => 1, tool => "mac-triage", version => $ENV{MT_VERSION},
      generated => strftime("%Y-%m-%dT%H:%M:%S%z", localtime),
      mode => $ENV{MT_MODE}, reason => $ENV{MT_REASON}, user => $ENV{MT_USER},
      lookback_days => 0 + $ENV{MT_DAYS}, full_disk_access => $ENV{MT_FDA},
      duration_seconds => 0 + $ENV{MT_DURATION}, rule_sets => $ENV{MT_SETS},
      modules => [ grep { length } split / /, $ENV{MT_MODULES} ],
      counts => { total => $total, %c }, findings => \@f,
    };
    print JSON::PP->new->canonical->pretty->encode($doc);
  ' "$RUN/.flags.tsv"
}
