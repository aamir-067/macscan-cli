# shellcheck shell=bash
# Desktop notification shown to the target user.

# Text is passed as arguments, never spliced into AppleScript source.
# NOTIFY=yes shows a notification. NOTIFY=dialog shows a dialog with an "Open report"
# button (a notification posted by a script cannot open anything when clicked); it runs
# in the background and closes itself after 5 minutes, so the scan is not held up.
notify(){
  case "$DO_NOTIFY" in yes|dialog) ;; *) return 0;; esac
  local t m f="${3:-}"
  t=$(printf '%s' "$1" | one_line); m=$(printf '%s' "$2" | one_line)
  if [ "$DO_NOTIFY" = dialog ] && [ -n "$f" ]; then
    (
      r=$(launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/osascript \
        -e 'on run argv' \
        -e 'set r to display dialog (item 2 of argv) with title (item 1 of argv) buttons {"Close", "Open report"} default button 2 giving up after 300' \
        -e 'return button returned of r' -e 'end run' "$t" "$m" 2>/dev/null)
      [ "$r" = "Open report" ] && launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/open "$f"
    ) >/dev/null 2>&1 &
    return 0
  fi
  launchctl asuser "$UID_N" sudo -u "$U" /usr/bin/osascript \
    -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' \
    "$t" "$m" >/dev/null 2>&1
}
