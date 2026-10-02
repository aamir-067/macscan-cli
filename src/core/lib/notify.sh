# shellcheck shell=bash
# Desktop notification shown to the target user.

notify(){
  [ "$DO_NOTIFY" = yes ] || return 0
  local t="${1//\"/}" m="${2//\"/}"
  launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/osascript -e "display notification \"$m\" with title \"$t\" sound name \"Glass\"" >/dev/null 2>&1
}
