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
  [[ "$output" == *"SCANNING"* ]] || return 1
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
