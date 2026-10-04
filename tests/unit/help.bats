#!/usr/bin/env bats
# macscan help pages, plain-word commands and doctor.

load ../helpers

@test "macscan help needs no root and shows examples and topics" {
  run /bin/bash "$SRC/macscan" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"EXAMPLES"* && "$output" == *"macscan help <topic>"* ]] || return 1
  [[ "$output" == *"macscan $(cat "$REPO/VERSION"):"* ]] || return 1
}

@test "every help topic has a page" {
  source "$SRC/core/lib/help.sh"
  for t in $HELP_TOPICS options; do
    out=$(help_topic "$t"); [ -n "$out" ] || { echo "empty topic: $t"; return 1; }
  done
}

@test "an unknown topic lists the real ones" {
  run /bin/bash "$SRC/macscan" help nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"Topics: scan reports"* ]] || return 1
}

@test "help options lists every option the engine accepts" {
  source "$SRC/core/lib/help.sh"; opts=$(help_options)
  for o in $(grep -oE '^ *--[a-z-]+\)' "$SRC/core/lib/options.sh" | tr -d ' )' | grep -v -- '--task'); do
    [[ "$opts" == *"$o"* ]] || { echo "not documented: $o"; return 1; }
  done
}

@test "plain words map to commands; unknown words are refused" {
  source "$SRC/core/lib/help.sh"
  [ "$(cli_alias status)" = --status ] && [ "$(cli_alias doctor)" = --doctor ] && [ "$(cli_alias quick)" = --quick ]
  [ -z "$(cli_alias rm)" ]
  run /bin/bash "$SRC/macscan" rm -rf
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown command: rm"* ]] || return 1
}

doctor_env(){
  make_env
  source "$SRC/macscan"
  ROOT="$TEST_TMP/root"; STATE="$ROOT/state"; mkdir -p "$ROOT/core" "$ROOT/bin" "$ROOT/rules" "$STATE"
  REPORT_DIR="$TEST_TMP/reports"; mkdir -p "$REPORT_DIR"; AUTO=on; AUTO_INTERVAL_DAYS=7; VERSION=2.5.0
  printf 'exit 0\n' > "$ROOT/core/run.sh"; printf 'x' > "$ROOT/bin/macscan-helper"; chmod +x "$ROOT/bin/macscan-helper"
  echo "yes (checked today)" > "$STATE/fda-status"; date +%s > "$STATE/last-full-scan"
  launchctl(){ return 0; }; codesign(){ return 0; }; readlink(){ echo "$ROOT/macscan"; }
  latest_version(){ echo 2.5.0; }
}

@test "doctor reports a healthy setup" {
  doctor_env
  run doctor
  [[ "$output" == *"ok    Installed files match"* && "$output" == *"ok    Up to date (2.5.0)"* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"FIX"* ]] || { echo "$output"; return 1; }
  drop_env
}

@test "doctor prints the fix for each problem and fails" {
  doctor_env
  echo "no (checked today)" > "$STATE/fda-status"; printf 'exit 1\n' > "$ROOT/core/run.sh"
  launchctl(){ return 1; }; latest_version(){ echo 9.0.0; }
  run doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"FIX   Full Disk Access is off"* && "$output" == *"-> System Settings > Privacy & Security"* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"FIX   The scan service is not loaded"* && "$output" == *"-> macscan install-services"* ]] || return 1
  [[ "$output" == *"Version 9.0.0 is available"* && "$output" == *"problem(s) to fix"* ]] || return 1
  drop_env
}
