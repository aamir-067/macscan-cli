# shellcheck shell=bash
# Desktop notification shown to the target user.

# Text is passed as arguments, never spliced into AppleScript source.
notify(){
  [ "$DO_NOTIFY" = yes ] || return 0
  local t m
  t=$(printf '%s' "$1" | one_line); m=$(printf '%s' "$2" | one_line)
  launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/osascript \
    -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' \
    "$t" "$m" >/dev/null 2>&1
}
