#!/usr/bin/env bats
# Module smoke tests: run a module as the current user against a fixture home.
# Each must exit 0, finish within its time limit, and write nothing into the home.

load ../helpers

setup(){
  make_env
  mkdir -p "$UH/.ssh" "$UH/code/app/.vscode" "$UH/Downloads" "$UH/Desktop"
  printf 'export PATH="$HOME/bin:$PATH"\nalias ll="ls -l"\n' > "$UH/.zshrc"
  printf '{"name":"app","scripts":{"test":"jest"}}\n' > "$UH/code/app/package.json"
}
teardown(){ drop_env; }

smoke(){
  local before after
  before=$(tree_snapshot "$UH")
  MODULE="$1" PATH="$REPO/tests/stubs:/usr/bin:/bin:/usr/sbin:/sbin" run perl -e 'alarm shift; exec @ARGV' "$2" /bin/bash "$(ls "$SRC"/modules/"$1"-*.sh)"
  [ "$status" -eq 0 ] || { echo "exit $status"; echo "$output" | tail -20; return 1; }
  after=$(tree_snapshot "$UH")
  [ "$before" = "$after" ] || { echo "module changed files in the home folder"; diff <(echo "$before") <(echo "$after"); return 1; }
}

@test "07 shell and path runs cleanly" { smoke 07 120; }
@test "13 download history runs cleanly" { smoke 13 180; }
@test "15 browsers runs cleanly" { smoke 15 180; }
@test "16 developer environment runs cleanly" { smoke 16 300; }
@test "17 code repositories runs cleanly" { smoke 17 300; }

@test "a clean fixture home raises no shell, repo or registry flags" {
  smoke 07 120; smoke 16 300; smoke 17 300
  run grep -E "Suspicious command|Task auto-runs|Injected malware marker|Non-default package registry" "$RUN/.flags.raw"
  [ "$status" -eq 1 ]
}
@test "21 plaintext secrets runs cleanly" { smoke 21 120; }
@test "22 supply chain runs cleanly (tools present or not)" { SUPPLY_CHAIN=yes smoke 22 600; }
