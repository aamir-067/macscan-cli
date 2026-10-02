#!/usr/bin/env bats
# core/lib/execmon.sh and module 24, with synthetic eslogger events.

load ../helpers

setup(){ make_env; source "$SRC/core/lib/execmon.sh"; }
teardown(){ drop_env; }

ev(){ # ev <group> <path> <signing id> <team> <platform true|false>
  printf '{"process":{"group_id":%s},"event":{"exec":{"target":{"group_id":%s,"executable":{"path":"%s"},"signing_id":"%s","team_id":"%s","is_platform_binary":%s},"args":["x"]}}}\n' "$1" "$1" "$2" "$3" "$4" "$5"
}

@test "exec_filter keeps other programs and drops the scan's own process group" {
  out=$( { ev 500 /usr/bin/find com.apple.find "" true; ev 77 /private/tmp/.x/agent agent "" false; echo 'not json'; } | exec_filter 500)
  [ "$out" = "$(printf '/private/tmp/.x/agent\tagent\t-\t0')" ]
}

@test "module 24 flags programs from unusual locations and unsigned ones" {
  load_common
  { printf '/private/tmp/.x/agent\tagent\t-\t0\n'; printf '/usr/bin/true\tcom.apple.true\t-\t1\n'; printf '/Applications/Tool.app/Contents/MacOS/Tool\ttool\t-\t0\n'; printf '/Applications/Good.app/Contents/MacOS/Good\tgood\tABCDE12345\t0\n'; } > "$MT_TMP/exec.tsv"
  EXEC_MONITOR=yes MODULE=24 PATH="$REPO/tests/stubs:/usr/bin:/bin:/usr/sbin:/sbin" run /bin/bash "$SRC/modules/24-exec-monitor.sh"
  [ "$status" -eq 0 ]
  grep -qF "Program started during the scan from an unusual location: /private/tmp/.x/agent" "$RUN/.flags.raw"
  grep -qF "Unsigned program started during the scan: /Applications/Tool.app/Contents/MacOS/Tool" "$RUN/.flags.raw"
  [ "$(grep -c . "$RUN/.flags.raw")" = 2 ]
}

@test "module 24 explains when nothing was captured" {
  load_common
  MODULE=24 run /bin/bash "$SRC/modules/24-exec-monitor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No exec events were captured"* ]] || return 1
}
