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
