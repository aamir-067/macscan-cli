#!/usr/bin/env bats
# core/deliver.sh: hands a staged report to the user's report folder, as the user.

load ../helpers

setup(){
  make_env
  STAGE="$TEST_TMP/stage"; NAME="scan_2026-01-03_10-00-00_manual"
  mkdir -p "$STAGE/$NAME/modules"; echo "summary" > "$STAGE/$NAME/00-SUMMARY_x.txt"; echo m > "$STAGE/$NAME/modules/01-system.txt"
}
teardown(){ drop_env; }

deliver(){ (cd "$STAGE" && tar -cf - "$NAME") | /bin/bash "$SRC/core/deliver.sh" receive "$@"; }

@test "receive extracts the report and creates the zip" {
  run deliver "$OUTBASE" "$NAME" yes
  [ "$status" -eq 0 ]
  [ "$(cat "$OUTBASE/$NAME/00-SUMMARY_x.txt")" = summary ]
  unzip -l "$OUTBASE/$NAME.zip" | grep -q "$NAME/modules/01-system.txt"
}

@test "receive without zip leaves no zip" {
  deliver "$OUTBASE" "$NAME" no
  [ -d "$OUTBASE/$NAME" ] && [ ! -e "$OUTBASE/$NAME.zip" ]
}

@test "receive refuses a symlinked report folder" {
  mkdir -p "$TEST_TMP/elsewhere"; mkdir -p "$(dirname "$OUTBASE")"; ln -s "$TEST_TMP/elsewhere" "$OUTBASE"
  run deliver "$OUTBASE" "$NAME" yes
  [ "$status" -eq 4 ]
  [ -z "$(ls "$TEST_TMP/elsewhere")" ]
}

@test "receive does not write through a planted zip symlink" {
  mkdir -p "$OUTBASE"; echo ORIGINAL > "$TEST_TMP/victim"; ln -s "$TEST_TMP/victim" "$OUTBASE/$NAME.zip"
  deliver "$OUTBASE" "$NAME" yes
  [ "$(cat "$TEST_TMP/victim")" = ORIGINAL ]
  [ ! -L "$OUTBASE/$NAME.zip" ]
}

@test "receive refuses when the report folder name already exists" {
  mkdir -p "$OUTBASE"; ln -s "$TEST_TMP" "$OUTBASE/$NAME"
  run deliver "$OUTBASE" "$NAME" no
  [ "$status" -ne 0 ]
}

@test "receive rejects path tricks in the report name" {
  for n in "../x" "scan_1/../../x" "evil" ""; do
    run deliver "$OUTBASE" "$n" no
    [ "$status" -ne 0 ] || { echo "accepted: $n"; return 1; }
  done
}

@test "clean keeps the newest N reports and removes their zips" {
  mkdir -p "$OUTBASE"
  for d in 2026-01-01 2026-01-02 2026-01-03; do mkdir "$OUTBASE/scan_${d}_manual"; touch "$OUTBASE/scan_${d}_manual.zip"; done
  /bin/bash "$SRC/core/deliver.sh" clean "$OUTBASE" 2 30
  [ ! -e "$OUTBASE/scan_2026-01-01_manual" ] && [ ! -e "$OUTBASE/scan_2026-01-01_manual.zip" ]
  [ -d "$OUTBASE/scan_2026-01-03_manual" ] && [ -d "$OUTBASE/scan_2026-01-02_manual" ]
}

@test "clean removes orphan zips and ignores other files" {
  mkdir -p "$OUTBASE"; touch "$OUTBASE/scan_2026-01-01_manual.zip" "$OUTBASE/notes.txt"
  /bin/bash "$SRC/core/deliver.sh" clean "$OUTBASE" 4 30
  [ ! -e "$OUTBASE/scan_2026-01-01_manual.zip" ] && [ -e "$OUTBASE/notes.txt" ]
}

@test "deliver.sh refuses to run as root" {
  grep -q '\[ "\$EUID" -ne 0 \] || { echo "deliver.sh must not run as root"' "$SRC/core/deliver.sh"
}
