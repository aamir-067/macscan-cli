#!/usr/bin/env bats
# core/lib/rules.sh: results are read out of the user's temp folder as the user and validated.

load ../helpers

setup(){
  make_env
  # shellcheck source=/dev/null
  source "$SRC/core/lib/rules.sh"
  export PATH="$REPO/tests/stubs:$PATH"
  UTMP="$TEST_TMP/utmp"; STAGE="$TEST_TMP/stage"; mkdir -p "$UTMP" "$STAGE"
}
teardown(){ chmod -R u+rw "$TEST_TMP" 2>/dev/null; drop_env; }

@test "valid compiled rules and set list are collected" {
  printf 'YARA\001\002' > "$UTMP/all.yarc"; echo "custom forge:forge.yar elastic:elastic.yar" > "$UTMP/sets.txt"
  rules_collect "$UTMP" "$STAGE"
  [ "$(cat "$STAGE/sets.txt")" = "custom yara-forge elastic" ]
  cmp "$UTMP/all.yarc" "$STAGE/all.yarc"
}

@test "a file that is not compiled YARA rules is rejected" {
  printf 'hello' > "$UTMP/all.yarc"; echo custom > "$UTMP/sets.txt"
  run rules_collect "$UTMP" "$STAGE"
  [ "$status" -ne 0 ]
}

@test "an unexpected set list is rejected" {
  printf 'YARA' > "$UTMP/all.yarc"; printf 'custom; rm -rf /\n' > "$UTMP/sets.txt"
  run rules_collect "$UTMP" "$STAGE"
  [ "$status" -ne 0 ]
}

@test "a symlink to a file the user cannot read yields nothing" {
  printf 'YARA-secret' > "$TEST_TMP/secret"; chmod 000 "$TEST_TMP/secret"
  ln -s "$TEST_TMP/secret" "$UTMP/all.yarc"; echo custom > "$UTMP/sets.txt"
  run rules_collect "$UTMP" "$STAGE"
  [ "$status" -ne 0 ]
  [ ! -s "$STAGE/all.yarc" ]
}
