#!/usr/bin/env bats
# Command-line validation in src/macscan (sourced; main() does not run).

load ../helpers

setup(){
  make_env
  # shellcheck source=/dev/null
  source "$SRC/macscan"
  ROOT="$TEST_TMP/root"; STATE="$ROOT/state"; mkdir -p "$STATE"
  printf 'TARGET_USER="x"\nREPORT_DIR="/Users/x/r"\nKEEP_REPORTS="4"\nAUTO="on"\n' > "$ROOT/config"
}
teardown(){ drop_env; }

@test "--help works without root" {
  run /bin/bash "$SRC/macscan" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"START HERE"* && "$output" == *"EXAMPLES"* ]] || return 1
}

@test "--set changes a known key" {
  run set_config KEEP_REPORTS=7
  [ "$status" -eq 0 ]
  grep -qx 'KEEP_REPORTS="7"' "$ROOT/config"
}

@test "--set rejects unknown keys" {
  run set_config TARGET_USER=root
  [ "$status" -eq 1 ]
  grep -qx 'TARGET_USER="x"' "$ROOT/config"
}

@test "--set rejects shell metacharacters" {
  for v in '$(id)' '`id`' 'a;b' 'a"b' "a'b" 'a|b' 'a&b'; do
    run set_config "REPORT_DIR=$v"
    [ "$status" -eq 1 ] || { echo "accepted: $v"; return 1; }
  done
  grep -qx 'REPORT_DIR="/Users/x/r"' "$ROOT/config"
}

@test "--set needs numbers for numeric keys and a full path for REPORT_DIR" {
  run set_config KEEP_REPORTS=abc; [ "$status" -eq 1 ]
  run set_config KEEP_REPORTS=0; [ "$status" -eq 1 ]
  run set_config REPORT_DIR=relative/path; [ "$status" -eq 1 ]
}

@test "scan option validation accepts good input" {
  run validate --quick --only 05,15 --days 30 --output /Users/x/out
  [ "$status" -eq 0 ]
}

@test "scan option validation rejects bad input" {
  run validate --only '5;id'; [ "$status" -eq 2 ]
  run validate --days -1; [ "$status" -eq 2 ]
  run validate --output rel; [ "$status" -eq 2 ]
  run validate --evil; [ "$status" -eq 2 ]
}

@test "xml escapes characters that would break a property list" {
  [ "$(xml '/Users/a&b/<x>')" = '/Users/a&amp;b/&lt;x&gt;' ]
}

@test "--ignore stores text, reason and date; --unignore removes it" {
  ACK="$STATE/acknowledged.tsv"
  run ack_add "no longer on disk: com.old.app" --reason "Uninstalled"
  [ "$status" -eq 0 ]
  [ "$(cut -f2,3 "$ACK")" = "$(printf 'no longer on disk: com.old.app\tUninstalled')" ]
  run ack_add "no longer on disk: com.old.app" --reason "again"
  [ "$(grep -c . "$ACK")" = 1 ]
  run ack_remove 1
  [ ! -s "$ACK" ]
}

@test "--ignore rejects short, reason-less or control-character input" {
  ACK="$STATE/acknowledged.tsv"
  run ack_add "short" --reason "x"; [ "$status" -eq 1 ]
  run ack_add "long enough text"; [ "$status" -eq 1 ]
  run ack_add "$(printf 'bad\ttab text')" --reason "x"; [ "$status" -eq 1 ]
  run ack_add "escape text here" --reason "$(printf 'r\033[2J')"; [ "$status" -eq 1 ]
  [ ! -s "$ACK" ]
}

@test "--set adds a key that an older config file does not have" {
  run set_config INCLUDE_TRASH=yes
  [ "$status" -eq 0 ]
  grep -qx 'INCLUDE_TRASH="yes"' "$ROOT/config"
  run set_config INCLUDE_TRASH=no
  [ "$(grep -c '^INCLUDE_TRASH=' "$ROOT/config")" = 1 ]
}

@test "--set checks yes/no and enumerated values" {
  run set_config ZIP=maybe; [ "$status" -eq 1 ]
  run set_config NOTIFY=dialog; [ "$status" -eq 0 ]
  run set_config CLAMAV_SCOPE=everything; [ "$status" -eq 1 ]
}

@test "status shows module progress from the engine's progress file" {
  now=$(date +%s); echo "12 24 12-applications $((now-180)) $((now-1260))" > "$STATE/progress"
  run progress_line
  [[ "$output" == *"module 12/24 (12-applications) for 3 min"* ]] || return 1
  [[ "$output" == *"(21 min ago)"* ]] || return 1
}

@test "status ignores a malformed progress file" {
  echo "x y z" > "$STATE/progress"
  run progress_line
  [ -z "$output" ]
}
