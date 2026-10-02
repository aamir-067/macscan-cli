#!/bin/bash
source /usr/local/mac-triage/core/common.sh
q(){ local title="$1" last="$2" pred="$3" n="${4:-80}"; sub "$title (last $last)"; tmo 420 log show --last "$last" --style compact --predicate "$pred" 2>/dev/null | tail -"$n"; }
section "Unified log (macOS keeps days to weeks of history)"
q "XProtect Remediator results" 30d 'subsystem == "com.apple.XProtectFramework.PluginAPI" AND category == "XPEvent.structured"'
q "XProtect and Gatekeeper malware blocks" 30d 'process == "XProtect" OR (process == "syspolicyd" AND eventMessage CONTAINS[c] "malware")'
q "Gatekeeper overrides (Open Anyway)" 30d 'process == "syspolicyd" AND (eventMessage CONTAINS[c] "override" OR eventMessage CONTAINS[c] "user approved")'
q "Privacy permission changes" 14d 'process == "tccd" AND (eventMessage CONTAINS[c] "Update Access Record" OR eventMessage CONTAINS[c] "granted")' 150
q "osascript activity" 14d 'process == "osascript"'
q "Authorization prompts that succeeded" 14d 'subsystem == "com.apple.Authorization" AND eventMessage CONTAINS[c] "Succeeded authorizing"'
q "Keychain command-line tool use" 14d 'process == "security"'
q "sudo usage" 14d 'process == "sudo"' 120
q "curl and wget runs" 7d 'process == "curl" OR process == "wget"'
q "Login window authentication" 7d 'process == "loginwindow" AND eventMessage CONTAINS[c] "authenticat"' 40
section "Install log"; grep -E "Installed|installer\[" /var/log/install.log 2>/dev/null | tail -150
section "Crash reports from the last $DAYS days (by program)"
find /Library/Logs/DiagnosticReports "$UH/Library/Logs/DiagnosticReports" -type f -Btime -"$DAYS" 2>/dev/null | sed 's#.*/##' | sed -E 's/[-_][0-9]{4}-[0-9]{2}-[0-9]{2}.*//' | sort | uniq -c | sort -rn | head -60
