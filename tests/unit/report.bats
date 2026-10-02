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

@test "retention keeps the newest KEEP reports and removes their zips" {
  mkdir -p "$OUTBASE"
  for d in 2026-01-01 2026-01-02 2026-01-03; do mkdir "$OUTBASE/scan_${d}_manual"; touch "$OUTBASE/scan_${d}_manual.zip"; done
  cleanup_reports
  [ ! -e "$OUTBASE/scan_2026-01-01_manual" ] && [ ! -e "$OUTBASE/scan_2026-01-01_manual.zip" ]
  [ -d "$OUTBASE/scan_2026-01-03_manual" ] && [ -d "$OUTBASE/scan_2026-01-02_manual" ]
}

@test "retention removes orphan zips" {
  mkdir -p "$OUTBASE"; touch "$OUTBASE/scan_2026-01-01_manual.zip"
  cleanup_reports
  [ ! -e "$OUTBASE/scan_2026-01-01_manual.zip" ]
}

@test "summary lists unique flags and the count" {
  printf '[a] x\n[a] x\n[b] y\n' > "$RUN/.flags.raw"; : > "$NEWS"
  VERSION=t MODE=manual REASON=test FDA=yes T0=$(date +%s) NFLAGS=2 ROOT="$SRC"
  run write_summary
  [[ "$output" == *"RED FLAGS: 2"* ]]
  [ "$(grep -c '^\[a\] x$' <<<"$output")" = 1 ]
}
