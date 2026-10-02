# shellcheck shell=bash
# One scan at a time. mkdir is atomic, so two runs cannot both take the lock.

lock_acquire(){
  local p
  if mkdir "$STATE/lock" 2>/dev/null; then echo $$ > "$PIDF"; return 0; fi
  p=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then return 1; fi
  # Left over from a run that was killed before it could clean up.
  rm -rf "$STATE/lock"; mkdir "$STATE/lock" 2>/dev/null || return 1
  echo $$ > "$PIDF"; return 0
}

lock_release(){ rm -f "$PIDF"; rmdir "$STATE/lock" 2>/dev/null; return 0; }
