#!/usr/bin/env bats
# The request file between macscan and the engine is data, never shell code.

load ../helpers

setup(){ make_env; }
teardown(){ drop_env; }

@test "arguments survive the round trip exactly and nothing is executed" {
  args=(--output "/Users/x/My Reports" --days 7 '$(touch '"$TEST_TMP"'/pwned)' "a'b\"c")
  printf '%s\0' "${args[@]}" > "$STATE/request"
  REQ=(); while IFS= read -r -d '' a; do REQ+=("$a"); done < "$STATE/request"
  [ "${#REQ[@]}" = 6 ]
  [ "${REQ[1]}" = "/Users/x/My Reports" ] && [ "${REQ[5]}" = "a'b\"c" ]
  [ ! -e "$TEST_TMP/pwned" ]
}

@test "the engine reads the request without eval" {
  not grep -nw 'eval' "$SRC/core/run.sh"
}
