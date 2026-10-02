#!/bin/bash
source /usr/local/mac-triage/core/common.sh
section "cron and at"
for u in $(dscl . list /Users | grep -v '^_'); do c=$(crontab -u "$u" -l 2>/dev/null); [ -n "$c" ] && { echo "[$u]"; echo "$c"; inv cron "$u $(echo "$c" | shasum | cut -c1-16)"; flag "crontab exists for $u"; }; done
ls -la /usr/lib/cron/tabs /usr/lib/cron/jobs 2>/dev/null
grep -vE '^[[:space:]]*(#|$)' /etc/crontab 2>/dev/null && flag "/etc/crontab has entries"
atq 2>/dev/null | grep . && flag "at jobs are queued"

section "periodic, rc, emond, login hooks"
ls -laT /etc/periodic/daily /etc/periodic/weekly /etc/periodic/monthly 2>/dev/null
for f in /etc/daily.local /etc/weekly.local /etc/monthly.local /etc/periodic.conf.local /etc/rc.local /etc/launchd.conf; do
  [ -f "$f" ] && { echo "[$f]"; cat "$f"; flag "Legacy startup file exists: $f"; }
done
ls -la /etc/emond.d/rules /private/var/db/emondClients 2>/dev/null
for k in LoginHook LogoutHook; do v=$(defaults read com.apple.loginwindow "$k" 2>/dev/null); [ -n "$v" ] && { echo "$k=$v"; flag "$k is set: $v"; }; done
sub "Apps reopened at login"
for f in "$UH"/Library/Preferences/ByHost/com.apple.loginwindow.*.plist; do [ -f "$f" ] && plutil -p "$f" 2>/dev/null | grep -E "BundleID|Path" | head -40; done

section "Kernel and system extensions"
kmutil showloaded 2>/dev/null | grep -E '^[[:space:]]*[0-9]+' | grep -v com.apple | while read -r l; do echo "$l"; inv kext "$(echo "$l" | awk '{print $6}')"; flag "Non-Apple kernel extension loaded: $l"; done
ls -la /Library/Extensions 2>/dev/null
systemextensionsctl list 2>&1 | tee /dev/null
systemextensionsctl list 2>/dev/null | grep -E "[A-Z0-9]{10}" | awk '{for(i=1;i<=NF;i++) if($i ~ /\./ && $i !~ /^\(/) {print $i; break}}' | while read -r l; do inv sysext "$l"; done

section "Authorization plugins, directory services, PAM"
ls -la /Library/Security/SecurityAgentPlugins 2>/dev/null
for p in /Library/Security/SecurityAgentPlugins/*; do [ -e "$p" ] && { inv authplugin "$p"; flag "Authorization plugin installed (can see login passwords): $p"; }; done
sub "Login mechanisms"; security authorizationdb read system.login.console 2>/dev/null | grep "<string>" | head -40
ls -la /Library/DirectoryServices/PlugIns 2>/dev/null
sub "PAM"; ls -laT /etc/pam.d
for f in /etc/pam.d/*; do inv pam "$f $(sha "$f")"; done
grep -lE "/usr/local|/opt|/Users" /etc/pam.d/* 2>/dev/null | while read -r f; do flag "PAM config loads a non-system module: $f"; done

section "Plugins loaded by system components"
for d in /Library/Spotlight /Library/QuickLook "/Library/Input Methods" "/Library/Internet Plug-Ins" "/Library/Screen Savers" /Library/PreferencePanes /Library/Audio/Plug-Ins/HAL /Library/ColorPickers "$UH/Library/Spotlight" "$UH/Library/QuickLook" "$UH/Library/Input Methods" "$UH/Library/Screen Savers" "$UH/Library/PreferencePanes" "$UH/Library/Internet Plug-Ins"; do
  [ -d "$d" ] && { echo "[$d]"; ls -laT "$d"; for x in "$d"/*; do [ -e "$x" ] && inv sysplugins "$x"; done; }
done
sub "App extensions (non-Apple)"
asuser pluginkit -mA 2>/dev/null | grep -v com.apple | while IFS= read -r l; do echo "$l"; inv app_ext "$(echo "$l" | sed -E 's/^[^A-Za-z]*//; s/\(.*//')"; done
sub "Folder Actions and user scripts"
ls -la "$UH/Library/Scripts/Folder Action Scripts" "/Library/Scripts/Folder Action Scripts" "$UH/Library/Scripts" "$UH/Library/Workflows/Applications/Folder Actions" 2>/dev/null
sub "PATH additions"; ls -laT /etc/paths.d; cat /etc/paths /etc/paths.d/* 2>/dev/null
