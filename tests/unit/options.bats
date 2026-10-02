#!/usr/bin/env bats
# Engine option parsing (core/lib/options.sh).

load ../helpers

setup(){
  # shellcheck source=/dev/null
  source "$SRC/core/lib/options.sh"
  LOOKBACK_DAYS=60 REPORT_DIR=/Users/x/reports KEEP_REPORTS=4 YARA=yes CLAMAV=yes CLAMAV_SCOPE=standard
  ONLY_IF_FINDINGS=no ZIP=yes NOTIFY=yes MAX_AGE_DAYS=30 AUTO_INTERVAL_DAYS=7
  options_defaults
}

@test "defaults come from config" {
  [ "$DAYS" = 60 ] && [ "$OUTBASE" = /Users/x/reports ] && [ "$KEEP" = 4 ] && [ "$QUICK" = 0 ]
}

@test "flags set the scan variables" {
  options_parse --quick --no-yara --days 14 --only 05,15 --keep 2 --no-zip
  [ "$QUICK" = 1 ] && [ "$DO_YARA" = no ] && [ "$DAYS" = 14 ] && [ "$ONLY" = 05,15 ] && [ "$KEEP" = 2 ] && [ "$DO_ZIP" = no ]
}

@test "unknown options are rejected" {
  run options_parse --frobnicate
  [ "$status" -eq 2 ]
}

@test "non-numeric --days is rejected" {
  run options_parse --days 7x
  [ "$status" -eq 2 ]
}

@test "a relative --output is rejected" {
  run options_parse --output reports
  [ "$status" -eq 2 ]
}

@test "--keep 0 is raised to 1" {
  options_parse --keep 0
  [ "$KEEP" = 1 ]
}

@test "single-digit module numbers are padded" {
  source "$SRC/core/lib/modules.sh"
  options_parse --only 5,15 --skip 9
  [ "$ONLY" = "05,15" ] && [ "$SKIP" = "09" ]
}

@test "module lists with anything but digits and commas are rejected" {
  run options_parse --only '05;id'
  [ "$status" -eq 2 ]
}

@test "unknown tasks and .. in --output are rejected" {
  run options_parse --task rm; [ "$status" -eq 2 ]
  run options_parse --output /Users/x/../../etc; [ "$status" -eq 2 ]
}

@test "--include-trash turns on the Trash sweep" {
  INCLUDE_TRASH=no
  options_parse --include-trash
  [ "$INCLUDE_TRASH" = yes ]
}
