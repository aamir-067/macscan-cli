#!/usr/bin/env bats
# Static checks over every shipped script.

load ../helpers

scripts(){ echo "$SRC/macscan"; ls "$SRC"/core/*.sh "$SRC"/core/lib/*.sh "$SRC"/modules/*.sh "$SRC/installer/install.sh" "$REPO/scripts/"*.sh; }

@test "every script parses with /bin/bash (3.2)" {
  for f in $(scripts); do /bin/bash -n "$f" || { echo "syntax: $f"; return 1; }; done
}

@test "shellcheck reports nothing" {
  command -v shellcheck >/dev/null || skip "shellcheck is not installed"
  run shellcheck -s bash $(scripts)
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "no Bash 4+ features (associative arrays, mapfile, case modification, |&, namerefs)" {
  run grep -nE 'declare -A|local -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|\|&|declare -n|local -n|;;&' $(scripts)
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "the C helper compiles without warnings" {
  command -v clang >/dev/null || skip "clang is not available"
  run clang -O2 -Wall -Wextra -Werror -o "$BATS_TEST_TMPDIR/helper" "$SRC/helper/macscan-helper.c"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "the custom YARA rules compile" {
  [ -x /opt/homebrew/bin/yarac ] || skip "YARA is not installed"
  /opt/homebrew/bin/yarac -w "$SRC/rules/custom.yar" "$BATS_TEST_TMPDIR/r.yarc"
}

@test "the root engine never writes into the user's report folder itself" {
  # Only core/deliver.sh (run as the user) may create, zip, chown or delete reports.
  run grep -nE 'chown (-R )?"\$U" "\$(RUN|OUTBASE)|ditto -c|rm -rf "\$d"|> *"\$OUTBASE|mkdir -p "\$OUTBASE' "$SRC/core/run.sh" "$SRC"/core/lib/*.sh "$SRC/core/common.sh"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "root never copies into, chowns or writes inside user-owned temp folders" {
  run grep -nE 'chown "\$U"|cp [^|;]* "\$(tmp|utmp)/|> *"\$(tmp|utmp)/' "$SRC/core/run.sh" "$SRC"/core/lib/*.sh "$SRC/core/common.sh"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "root code never creates files in the shared /tmp" {
  # Allowed: `mktemp -d` (atomic, private) and the case check on its result.
  run grep -nE '/tmp/mactriage|mktemp /tmp|> */tmp/|2> */tmp/' "$SRC/core/run.sh" "$SRC"/core/lib/*.sh "$SRC/core/common.sh" "$SRC"/modules/*.sh "$SRC/installer/install.sh"
  [ "$(echo "$output" | grep -v 'mktemp -d ' | grep -v 'case "\$utmp"' | grep -c .)" = 0 ] || { echo "$output"; return 1; }
}
