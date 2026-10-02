#!/usr/bin/env bats
# core/lib/lock.sh

load ../helpers

setup(){ make_env; PIDF="$STATE/running.pid"; source "$SRC/core/lib/lock.sh"; }
teardown(){ drop_env; }

@test "the first caller gets the lock, a second one does not" {
  lock_acquire
  [ "$(cat "$PIDF")" = $$ ]
  run bash -c 'STATE="$1"; PIDF="$1/running.pid"; source "$2/core/lib/lock.sh"; lock_acquire' _ "$STATE" "$SRC"
  [ "$status" -eq 1 ]
}

@test "a stale lock from a dead process is taken over" {
  mkdir "$STATE/lock"; echo 999999 > "$PIDF"
  lock_acquire
  [ "$(cat "$PIDF")" = $$ ]
}

@test "release removes the lock" {
  lock_acquire; lock_release
  [ ! -e "$STATE/lock" ] && [ ! -e "$PIDF" ]
}
