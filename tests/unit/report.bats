#!/usr/bin/env bats
# Inventory diff, summary and report retention (core/lib/report.sh).

load ../helpers

setup(){
  make_env
  # shellcheck source=/dev/null
  source "$SRC/core/lib/report.sh"
  NEWS="$RUN/.news"; KEEP=2; MAX_AGE_DAYS=30
}
teardown(){ drop_env; }

@test "first scan saves a baseline and raises no 'new' flags" {
  printf 'b\na\n' > "$INV/apps.txt"
  diff_inventories
  grep -q "\[apps\] baseline saved (2 items)" "$NEWS"
  [ ! -s "$RUN/.flags.raw" ]
  [ "$(cat "$STATE/inv/last/apps.txt")" = "$(printf 'a\nb')" ]
}

@test "items added since the last scan become flags, removed ones are listed" {
  mkdir -p "$STATE/inv/last"; printf 'a\nb\n' > "$STATE/inv/last/apps.txt"
  printf 'a\nc\n' > "$INV/apps.txt"
  diff_inventories
  grep -qxF "[new since last scan] [apps] c" "$RUN/.flags.raw"
  grep -qxF "  - b" "$NEWS"
  [ ! -d "$INV" ]
}

@test "summary lists unique flags, most severe first, with counts" {
  source "$SRC/core/lib/severity.sh"; source "$SRC/core/common.sh"
  printf '[09-network] Listener reachable from the network: a\n[a] x\n[a] x\n[17-code-repos] Injected malware marker found: /p.js\n' > "$RUN/.flags.raw"; : > "$NEWS"
  VERSION=t MODE=manual REASON=test FDA=yes T0=$(date +%s) ROOT="$SRC"
  prepare_flags
  [ "$NFLAGS" = 3 ] && [ "$N_CRIT" = 1 ] && [ "$N_LOW" = 1 ]
  run write_summary
  [[ "$output" == *"RED FLAGS: 3 (critical 1, high 0, medium 1, low 1)"* ]] || return 1
  [ "$(grep -c '^\[MEDIUM\] \[a\] x$' <<<"$output")" = 1 ]
  [ "$(grep '^\[' <<<"$output" | head -1)" = "[CRITICAL] [17-code-repos] Injected malware marker found: /p.js" ]
  [ "$(grep '^\[' <<<"$output" | tail -1)" = "[LOW] [09-network] Listener reachable from the network: a" ]
}

@test "acknowledged flags are listed separately and not counted" {
  source "$SRC/core/lib/severity.sh"; source "$SRC/core/common.sh"
  printf '[a] keep me\n[b] ignore me please\n' > "$RUN/.flags.raw"; : > "$NEWS"
  printf '2026-10-01\tignore me please\tknown\n' > "$STATE/acknowledged.tsv"
  VERSION=t MODE=manual REASON=test FDA=yes T0=$(date +%s) ROOT="$SRC"
  prepare_flags
  [ "$NFLAGS" = 1 ] && [ "$N_ACK" = 1 ]
  run write_summary
  [[ "$output" == *"ACKNOWLEDGED (not counted): 1"* ]] || return 1
  [[ "$output" == *"acknowledged: known (since 2026-10-01)"* ]] || return 1
}

@test "report.json is valid, counts match and fingerprints are stable" {
  source "$SRC/core/lib/severity.sh"; source "$SRC/core/common.sh"
  printf '[17-code-repos] Injected malware marker found: /p.js\n[new since last scan] [launch] /L/x.plist | /tmp/x | ab\n[b] ignore me please\n' > "$RUN/.flags.raw"
  printf '2026-10-01\tignore me please\tknown\n' > "$STATE/acknowledged.tsv"; : > "$NEWS"
  VERSION=9.9.9 MODE=manual REASON=test FDA=yes T0=$(date +%s) ROOT="$SRC"
  prepare_flags
  write_json > "$TEST_TMP/r.json"
  run /usr/bin/python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert d["schema_version"]==1 and d["version"]=="9.9.9"
assert d["counts"]=={"total":2,"critical":1,"high":1,"medium":0,"low":0,"acknowledged":1}, d["counts"]
f={x["message"]:x for x in d["findings"]}
assert f["/L/x.plist | /tmp/x | ab"]["category"]=="launch" and f["/L/x.plist | /tmp/x | ab"]["new_since_last_scan"]
assert f["ignore me please"]["acknowledged"] and f["ignore me please"]["acknowledgement"].startswith("known")
assert len(f["Injected malware marker found: /p.js"]["fingerprint"])==16
print(f["Injected malware marker found: /p.js"]["fingerprint"])
' "$TEST_TMP/r.json"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "$(printf '%s' '17-code-repos|Injected malware marker found: /p.js' | shasum -a 256 | cut -c1-16)" ]
}

@test "the summary and report.json state the sleep and exclude it from the duration" {
  source "$SRC/core/lib/severity.sh"; source "$SRC/core/common.sh"
  : > "$RUN/.flags.raw"; : > "$NEWS"
  VERSION=t MODE=manual REASON=test FDA=yes T0=$(( $(date +%s) - 3600 )) ROOT="$SRC"
  SLEEP_COUNT=1 SLEEP_SECONDS=1800 SLEEP_MODULES="09-network 19-yara"
  prepare_flags
  run write_summary
  [[ "$output" == *"Duration: 30 min"* ]] || return 1
  [[ "$output" == *"slept 1 time(s) during this scan for 30 min"* ]] || return 1
  [[ "$output" == *"09-network 19-yara"* ]] || return 1
  write_json | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["sleep"]=={"count":1,"seconds":1800,"modules":["09-network","19-yara"]}, d["sleep"]; assert 1790 < d["duration_seconds"] < 1810'
}
