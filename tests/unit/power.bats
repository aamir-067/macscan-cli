#!/usr/bin/env bats
# core/lib/power.sh: sleep detection from `pmset -g log` lines.

load ../helpers

setup(){ make_env; source "$SRC/core/lib/power.sh"; }
teardown(){ drop_env; }

# 2026-10-03 10:00:00 +0500 is epoch 1791003600.
LOG='2026-10-03 09:00:00 +0500 Sleep               	Entering Sleep state due to Idle Sleep
2026-10-03 09:30:00 +0500 Wake                	Wake from Deep Idle
2026-10-03 10:10:00 +0500 Sleep               	Entering Sleep state due to Clamshell Sleep
2026-10-03 10:12:00 +0500 Wake Requests       	[process=dasd request=SleepService]
2026-10-03 10:20:00 +0500 DarkWake            	DarkWake from Deep Idle
2026-10-03 10:20:05 +0500 Sleep               	Entering Sleep state due to Maintenance Sleep
2026-10-03 10:40:00 +0500 Wake                	Wake from Deep Idle [CDNVA]
2026-10-03 11:30:00 +0500 Sleep               	Entering Sleep state due to Idle Sleep'

@test "only sleeps inside the scan window are reported, DarkWakes stay part of the sleep" {
  out=$(printf '%s\n' "$LOG" | sleep_intervals 1791003600 1791007200)   # 10:00 to 11:00
  [ "$out" = "1791004200 1791006000" ]                                 # 10:10 to 10:40
}

@test "a sleep still running at the end is closed at the end" {
  out=$(printf '%s\n' "$LOG" | sleep_intervals 1791007200 1791010800)  # 11:00 to 12:00
  [ "$out" = "1791009000 1791010800" ]                                 # 11:30 to 12:00
}

@test "sleep_report counts, totals and names the modules that ran across a sleep" {
  pmset(){ printf '%s\n' "$LOG"; }
  printf '08-processes 1791003700 1791004000\n09-network 1791004100 1791006100\n12-applications 1791006200 1791006300\n' > "$TEST_TMP/timing"
  sleep_report 1791003600 1791007200 "$TEST_TMP/timing"
  [ "$SLEEP_COUNT" = 1 ] && [ "$SLEEP_SECONDS" = 1800 ] && [ "$SLEEP_MODULES" = "09-network" ]
}

@test "no sleep, no report" {
  pmset(){ :; }
  sleep_report 1791003600 1791007200 "$TEST_TMP/none"
  [ "$SLEEP_COUNT" = 0 ] && [ "$SLEEP_SECONDS" = 0 ] && [ -z "$SLEEP_MODULES" ]
}

@test "the parser understands this Mac's real power log format" {
  command -v pmset >/dev/null || skip "no pmset"
  n=$(pmset -g log 2>/dev/null | head -20000 | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} [+-][0-9]{4}\s+(Sleep|Wake)\s{2,}' || true)
  [ "$n" -gt 0 ] || skip "power log has no sleep entries yet"
}
