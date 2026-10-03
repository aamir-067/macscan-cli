# shellcheck shell=bash
# shellcheck disable=SC2034  # SLEEP_* are read by run.sh and core/lib/report.sh
# Sleep awareness for long scans.
#
# When a Mac sleeps (idle sleep, or the lid is closed), macOS freezes every process,
# the scan included. On wake it continues where it stopped, so the scan still finishes,
# but modules that sample live state (processes, connections) may mix before-sleep and
# after-sleep data. The engine therefore:
#   1. keeps the Mac from idle-sleeping while a scan runs (caffeinate -i, released when
#      the scan exits; closing the lid of a laptop still sleeps it, nothing safe can stop that),
#   2. reads the power log afterwards and reports every sleep that happened during the
#      scan, excludes it from the duration, and names the modules that ran across one.

power_keep_awake(){
  [ -x /usr/bin/caffeinate ] || return 0
  /usr/bin/caffeinate -i -w "$$" >/dev/null 2>&1 &
  return 0
}

# sleep_intervals <start epoch> <end epoch>: reads `pmset -g log` on stdin and prints
# "<sleep epoch> <wake epoch>" for every sleep that overlaps the window. A sleep still in
# progress at <end> is closed at <end>. Brief DarkWakes (maintenance) inside a sleep are
# treated as part of it.
sleep_intervals(){
  perl -MTime::Local -e '
    my ($s, $e) = @ARGV; my $sl;
    while (<STDIN>) {
      next unless /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d) ([+-])(\d\d)(\d\d)\s+(Sleep|Wake|DarkWake)\s{2,}/;
      my $t = timegm($6, $5, $4, $3, $2 - 1, $1) - ($7 eq "+" ? 1 : -1) * ($8 * 3600 + $9 * 60);
      if ($10 eq "Sleep") { $sl = $t unless defined $sl }
      elsif ($10 eq "Wake" && defined $sl) { print "$sl $t\n" if $t > $s && $sl < $e; undef $sl }
    }
    print "$sl $e\n" if defined $sl && $sl < $e;
  ' "$1" "$2"
}

# sleep_report <start epoch> <end epoch> <timing file>: sets SLEEP_COUNT, SLEEP_SECONDS and
# SLEEP_MODULES (modules whose run overlapped a sleep). The timing file has
# "<module> <start epoch> <end epoch>" lines.
sleep_report(){
  local iv
  iv=$(pmset -g log 2>/dev/null | sleep_intervals "$1" "$2")
  SLEEP_COUNT=$(printf '%s\n' "$iv" | grep -c . || true)
  SLEEP_SECONDS=$(printf '%s\n' "$iv" | awk -v s="$1" -v e="$2" 'NF==2 { a = ($1 < s ? s : $1); b = ($2 > e ? e : $2); if (b > a) t += b - a } END { print t + 0 }')
  SLEEP_MODULES=""
  [ "$SLEEP_COUNT" -gt 0 ] && [ -f "$3" ] || return 0
  SLEEP_MODULES=$(printf '%s\n' "$iv" | awk 'NR==FNR { if (NF==2) { n++; S[n]=$1; W[n]=$2 } next }
    { for (i = 1; i <= n; i++) if ($2 < W[i] && $3 > S[i]) { print $1; break } }' - "$3" | tr '\n' ' ' | sed 's/ $//')
}
