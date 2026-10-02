#!/usr/bin/env bats
# Helper functions in core/common.sh.

load ../helpers

setup(){ make_env; load_common; }
teardown(){ drop_env; }

@test "is_dev_path recognizes developer tool locations" {
  is_dev_path /opt/homebrew/bin/node
  is_dev_path "$UH/.nvm/versions/node/v20/bin/node"
  is_dev_path "$UH/code/app/node_modules/.bin/x"
  ! is_dev_path /Applications/Safari.app/Contents/MacOS/Safari
  ! is_dev_path "$UH/Downloads/tool"
}

@test "is_system_path accepts sealed system locations only" {
  is_system_path /usr/bin/true
  is_system_path /System/Library/CoreServices/Finder.app
  ! is_system_path /usr/local/bin/x
  ! is_system_path /private/tmp/x
}

@test "is_self matches the tool's own files and labels" {
  is_self "$ROOT/core/run.sh"
  is_self /Library/LaunchDaemons/com.mactriage.runner.plist
  ! is_self /Library/LaunchDaemons/com.example.plist
}

@test "flag prints a marker and records [module] message" {
  MODULE=07-shell run flag "Something odd"
  [ "$output" = "[!] Something odd" ]
  grep -qxF "[07-shell] Something odd" "$RUN/.flags.raw"
}

@test "inv appends a stable line to the category file" {
  inv apps "/Applications/X.app | team=ABC"
  inv apps "/Applications/Y.app | team=DEF"
  [ "$(wc -l < "$INV/apps.txt" | tr -d ' ')" = 2 ]
}

@test "inv does nothing when INV is empty" {
  INV="" inv apps "x"
  [ ! -e "$TEST_TMP/inv/apps.txt" ]
}

@test "sig reports a valid Apple signature" {
  run sig /bin/ls
  [[ "$output" == "/bin/ls | "*"| valid" ]]
}

@test "sig reports an unsigned binary" {
  cp /usr/bin/true "$TEST_TMP/unsigned"
  codesign --remove-signature "$TEST_TMP/unsigned"
  run sig "$TEST_TMP/unsigned"
  [[ "$output" == *"UNSIGNED"* || "$output" == *"INVALID-OR-UNSIGNED"* ]]
}

@test "sha prints the first 16 hex characters of SHA-256" {
  printf 'abc' > "$TEST_TMP/f"
  [ "$(sha "$TEST_TMP/f")" = "ba7816bf8f01cfea" ]
}

@test "tmo kills a command that runs too long" {
  run tmo 1 /bin/sleep 5
  [ "$status" -ne 0 ]
}

@test "tmpf creates private files inside MT_TMP" {
  f=$(tmpf)
  [[ "$f" == "$MT_TMP/"* ]] && [ -f "$f" ]
  [ "$(stat -f %Lp "$f")" = 600 ]
}

@test "tmpf refuses to run without MT_TMP" {
  run bash -c 'unset MT_TMP; source "$1/core/common.sh"; tmpf' _ "$SRC"
  [ "$status" -ne 0 ]
}
