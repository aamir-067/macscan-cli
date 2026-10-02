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

@test "sql ignores ~/.sqliterc and refuses dangerous commands" {
  mkdir -p "$TEST_TMP/h"; printf '.shell touch %s/pwned\n' "$TEST_TMP" > "$TEST_TMP/h/.sqliterc"
  /usr/bin/sqlite3 "$TEST_TMP/t.db" "create table access(service); insert into access values('x');"
  HOME="$TEST_TMP/h" run sql "$TEST_TMP/t.db" "select service from access"
  [ "$output" = x ] && [ ! -e "$TEST_TMP/pwned" ]
  run sql "$TEST_TMP/t.db" "ATTACH '$TEST_TMP/o.db' AS o"
  [ "$status" -ne 0 ] && [ ! -e "$TEST_TMP/o.db" ]
}

@test "sql opens databases read-only" {
  /usr/bin/sqlite3 "$TEST_TMP/t.db" "create table a(x);"
  run sql "$TEST_TMP/t.db" "insert into a values(1)"
  [ "$status" -ne 0 ]
}

@test "user_path covers user-writable places and not system ones" {
  user_path "$UH/.zshrc"; user_path /opt/homebrew/etc/gitconfig; user_path /Applications/X.app/Contents/x.json; user_path /private/tmp/x
  ! user_path /etc/sudoers; ! user_path /var/root/.zshrc; ! user_path /var/db/dslocal/nodes/Default/users/x.plist
}

@test "rd reads user files with the user's rights (a planted symlink yields nothing)" {
  echo "secret-hash" > "$TEST_TMP/rootonly"; chmod 000 "$TEST_TMP/rootonly"
  ln -s "$TEST_TMP/rootonly" "$UH/.npmrc"
  PATH="$REPO/tests/stubs:$PATH" run rd "$UH/.npmrc"
  chmod 600 "$TEST_TMP/rootonly"
  [[ "$output" != *secret-hash* ]]
}

@test "rd prints ordinary files" {
  printf 'a\nb\n' > "$UH/.zshrc"
  PATH="$REPO/tests/stubs:$PATH" run rd "$UH/.zshrc"
  [ "$output" = "$(printf 'a\nb')" ]
}

@test "paths through the writable data volume are not treated as system paths" {
  ! is_system_path /System/Volumes/Data/private/tmp/evil
  ! is_system_path /System/Volumes/Data/Users/x/.hidden/agent
  [ "$(canon_path /System/Volumes/Data/private/tmp/evil)" = /private/tmp/evil ]
  [ "$(canon_path /usr/bin/true)" = /usr/bin/true ]
}
