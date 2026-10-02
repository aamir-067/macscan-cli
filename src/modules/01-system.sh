#!/bin/bash
# @title  System and security posture
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "System and security posture"
sw_vers; uname -a; sysctl -n hw.model machdep.cpu.brand_string 2>/dev/null; uptime
s=$(csrutil status 2>&1); sub "System Integrity Protection"; echo "$s"
echo "$s" | grep -q "enabled" || flag "System Integrity Protection is not enabled"; inv posture "SIP: $s"
sub "Sealed system volume"; csrutil authenticated-root status 2>&1
g=$(spctl --status 2>&1); sub "Gatekeeper"; echo "$g"
echo "$g" | grep -q "enabled" || flag "Gatekeeper is disabled"; inv posture "Gatekeeper: $g"
f=$(fdesetup status 2>&1); sub "FileVault"; echo "$f"
echo "$f" | grep -q "On" || flag "FileVault is off"; inv posture "FileVault: $f"
fw=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1); sub "Firewall"; echo "$fw"
echo "$fw" | grep -qi "enabled" || flag "Application firewall is off"; inv posture "Firewall: $fw"
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sub "Firewall app rules"; /usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | head -100
sub "XProtect version"; defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null
sub "Software update settings"; defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>/dev/null
sub "Software update history"; softwareupdate --history 2>/dev/null | head -30
sub "NVRAM boot arguments"; b=$(nvram boot-args 2>&1); echo "$b"
echo "$b" | grep -q "not found" || inv posture "boot-args: $b"
