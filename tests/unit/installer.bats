#!/usr/bin/env bats
# Upgrade logic in src/installer/install.sh (sourced; main() does not run).

load ../helpers

setup(){
  make_env
  # shellcheck source=/dev/null
  source "$SRC/installer/install.sh"
  ROOT="$TEST_TMP/root"; mkdir -p "$ROOT/bin" "$ROOT/helper" "$ROOT/state"
  U=someone; UH=/Users/someone
}
teardown(){ drop_env; }

@test "version_cmp orders semantic versions" {
  [ "$(version_cmp 2.4.0 2.3.9)" = 1 ]
  [ "$(version_cmp 2.3.0 2.3.0)" = 0 ]
  [ "$(version_cmp 2.10.0 2.9.1)" = 1 ]
  [ "$(version_cmp 2.2.1 2.10.0)" = -1 ]
  [ "$(version_cmp 3 2.99.99)" = 1 ]
}

@test "a new config gets every default setting" {
  config_write "$ROOT/config" >/dev/null
  grep -qx 'TARGET_USER="someone"' "$ROOT/config"
  grep -qx 'EXEC_MONITOR="no"' "$ROOT/config"
  [ "$(grep -cE '^[A-Z_]+=' "$ROOT/config")" = "$(default_config | grep -cE '^[A-Z_]+=')" ]
}

@test "an upgrade adds only missing settings and never changes existing values" {
  printf 'TARGET_USER="someone"\nKEEP_REPORTS="9"\nAUTO="off"\n' > "$ROOT/config"
  added=$(config_write "$ROOT/config" | tr '\n' ' ')
  grep -qx 'KEEP_REPORTS="9"' "$ROOT/config" && grep -qx 'AUTO="off"' "$ROOT/config"
  [ "$(grep -c '^KEEP_REPORTS=' "$ROOT/config")" = 1 ]
  [[ " $added " == *" INCLUDE_TRASH "* && " $added " != *" KEEP_REPORTS "* ]] || return 1
  [ -z "$(config_write "$ROOT/config")" ]
}

@test "the helper is rebuilt only when its source changed (keeps Full Disk Access)" {
  echo 'int main(void){return 0;}' > "$TEST_TMP/new.c"
  helper_needs_build "$TEST_TMP/new.c"                       # nothing installed yet
  cp "$TEST_TMP/new.c" "$ROOT/helper/macscan-helper.c"; printf 'bin' > "$ROOT/bin/macscan-helper"; chmod +x "$ROOT/bin/macscan-helper"
  not helper_needs_build "$TEST_TMP/new.c"                   # same source, binary present
  echo '// changed' >> "$TEST_TMP/new.c"
  helper_needs_build "$TEST_TMP/new.c"                       # source changed
}

@test "a running scan is detected" {
  not scan_running
  echo $$ > "$ROOT/state/running.pid"
  scan_running
}

@test "installing needs root and says how" {
  [ "$EUID" -ne 0 ] || skip "running as root"
  run main
  [ "$status" -eq 1 ]
  [[ "$output" == *"sudo bash"* ]] || return 1
}

@test "--help explains upgrade, downgrade and uninstall" {
  run main --help
  [[ "$output" == *"--allow-downgrade"* && "$output" == *"--uninstall"* && "$output" == *"keeps your settings"* ]] || return 1
}
