# shellcheck shell=bash
# Exec monitoring with the built-in eslogger (EXEC_MONITOR=yes). Captures every program
# started while the scan runs, so short-lived ones between snapshots are seen too.
# Events from the scan's own process group are dropped as they arrive.

# exec_filter <scan process group>: eslogger JSON lines on stdin; prints
# "path<TAB>signing id<TAB>team id<TAB>platform 0|1" for each exec outside the group.
# Empty fields are written as "-" (read would collapse consecutive tabs).
exec_filter(){
  perl -MJSON::PP -ne '
    BEGIN { $| = 1; $pg = shift @ARGV }
    my $e = eval { decode_json($_) } or next;
    my $p = $e->{process} || {}; my $t = (($e->{event} || {})->{exec} || {})->{target} or next;
    next if defined $p->{group_id} && $p->{group_id} == $pg;
    next if defined $t->{group_id} && $t->{group_id} == $pg;
    my $path = ($t->{executable} || {})->{path} // next;
    $path =~ s/[\t\n]/ /g;
    printf "%s\t%s\t%s\t%d\n", $path, ($t->{signing_id} || "-"), ($t->{team_id} || "-"), $t->{is_platform_binary} ? 1 : 0;
  ' "$1"
}

execmon_start(){
  [ "${EXEC_MONITOR:-no}" = yes ] && [ "$QUICK" = 0 ] && [ -x /usr/bin/eslogger ] || return 0
  local pg; pg=$(ps -o pgid= -p $$ | tr -d ' ')
  /usr/bin/eslogger exec 2>"$MT_TMP/eslogger.err" > >(exec_filter "$pg" > "$MT_TMP/exec.tsv") &
  ESPID=$!
  echo "Exec monitoring: on (eslogger pid $ESPID)"
}

execmon_stop(){ [ -n "${ESPID:-}" ] && kill "$ESPID" 2>/dev/null; ESPID=""; return 0; }
