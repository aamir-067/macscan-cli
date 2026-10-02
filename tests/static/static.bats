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
