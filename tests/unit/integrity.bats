#!/usr/bin/env bats
# core/lib/integrity.sh

load ../helpers

setup(){
  make_env; load_common; source "$SRC/core/lib/integrity.sh"
  ROOT="$TEST_TMP/root"; LD="$TEST_TMP/LaunchDaemons"; ME=$(id -un)
  mkdir -p "$ROOT/core" "$ROOT/modules" "$ROOT/state" "$ROOT/rules" "$ROOT/bin" "$LD"
  echo a > "$ROOT/core/run.sh"; echo b > "$ROOT/modules/01-system.sh"; echo c > "$ROOT/config"; echo d > "$ROOT/rules/all.yarc"
  echo s > "$ROOT/state/history.log"
  chmod -R go-w "$ROOT"
  integrity_manifest "$ROOT" > "$ROOT/manifest.sha256"
}
teardown(){ drop_env; }

@test "a fresh install passes and the manifest skips config, state and compiled rules" {
  integrity_check "$ME" "$LD"
  [ "$(grep -c . "$ROOT/manifest.sha256")" = 2 ]
}

@test "a changed file is a critical integrity flag" {
  echo evil >> "$ROOT/modules/01-system.sh"
  run integrity_check "$ME" "$LD"
  [ "$status" -eq 1 ]
  grep -qxF "[test] Install integrity check failed: modules/01-system.sh changed since install" "$RUN/.flags.raw"
}

@test "an extra module is flagged" {
  echo x > "$ROOT/modules/99-extra.sh"; chmod go-w "$ROOT/modules/99-extra.sh"
  run integrity_check "$ME" "$LD"
  grep -qF "Unexpected file in install folder: $ROOT/modules/99-extra.sh" "$RUN/.flags.raw"
}

@test "a group- or world-writable file is flagged" {
  chmod o+w "$ROOT/core/run.sh"
  run integrity_check "$ME" "$LD"
  grep -qF "Install file not owned by root or writable by others: $ROOT/core/run.sh" "$RUN/.flags.raw"
}

@test "a LaunchDaemon that runs something else is flagged" {
  plutil -create xml1 "$LD/com.mactriage.runner.plist"
  plutil -insert ProgramArguments -json '["/tmp/evil","--from-request"]' "$LD/com.mactriage.runner.plist"
  chmod 644 "$LD/com.mactriage.runner.plist"
  run integrity_check "$ME" "$LD"
  grep -qF "Service definition changed: $LD/com.mactriage.runner.plist runs /tmp/evil" "$RUN/.flags.raw"
}

@test "a missing manifest is flagged" {
  rm "$ROOT/manifest.sha256"
  run integrity_check "$ME" "$LD"
  grep -qF "manifest.sha256 is missing" "$RUN/.flags.raw"
}

@test "flag does not write anywhere when RUN is empty" {
  RUN="" run flag "x"
  [ "$output" = "[!] x" ]
}
