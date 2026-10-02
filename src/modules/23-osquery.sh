#!/bin/bash
# @title  osquery cross-check (when osquery is installed)
# @quick  skip
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"

section "osquery cross-check of persistence, listeners and extensions"
BIN=""
for c in /usr/local/bin/osqueryi /opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd; do [ -e "$c" ] && { BIN="$c"; break; }; done
if [ -z "$BIN" ]; then echo "osquery is not installed (https://osquery.io), skipped."; exit 0; fi
if ! root_safe_bin "$BIN"; then
  echo "osquery at $BIN is not root-owned all the way up its path; it will not be run as root. Skipped."; exit 0
fi
case "$BIN" in */osqueryd) Q=("$BIN" -S);; *) Q=("$BIN");; esac
echo "Using ${Q[*]}. These tables repeat other modules from a second, independent source."

oq(){ sub "$1"; tmo 120 "${Q[@]}" --disable_events --logger_plugin=filesystem --logger_path="$MT_TMP" "$2" 2>&1 | head -"${3:-150}"; }
oq "Non-Apple launchd items" "SELECT path, label, program, program_arguments, run_at_load, keep_alive FROM launchd WHERE label NOT LIKE 'com.apple.%' ORDER BY path;"
oq "Startup items" "SELECT name, path, type, source, status FROM startup_items ORDER BY type, name;"
oq "Listening ports reachable from the network" "SELECT DISTINCT p.name, p.path, l.port, l.protocol, l.address FROM listening_ports l JOIN processes p USING (pid) WHERE l.port != 0 AND l.address NOT IN ('127.0.0.1', '::1') ORDER BY l.port;"
oq "System extensions" "SELECT identifier, version, team, state FROM system_extensions;"
oq "Chromium extensions of user accounts" "SELECT u.username, c.browser_type, c.name, c.identifier, c.version FROM users u CROSS JOIN chrome_extensions c USING (uid) WHERE u.uid >= 500 ORDER BY c.browser_type, c.name;" 300
