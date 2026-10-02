#!/bin/bash
# @title  Accounts and admin rights
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Accounts and admin rights"
sub "Local users (UID 0 and 500+)"
dscl . list /Users UniqueID | awk '$2==0 || $2>=500' | while read -r n id; do echo "$n $id"; inv users "$n $id"; done
dscl . list /Users UniqueID | awk '$2==0 {print $1}' | grep -vx root | while read -r x; do flag "Extra account with UID 0: $x"; done
sub "Admin group"; adm=$(dscl . read /Groups/admin GroupMembership 2>/dev/null); echo "$adm"
for a in $(echo "$adm" | cut -d: -f2); do inv admins "$a"; case "$a" in root|"$U") ;; *) flag "Unexpected admin account: $a";; esac; done
sub "Hidden users"; dscl . list /Users IsHidden 2>/dev/null
sub "User records created in the last $DAYS days"
find /var/db/dslocal/nodes/Default/users -name "*.plist" -Btime -"$DAYS" 2>/dev/null | grep -v "/_" | while read -r f; do echo "$f"; flag "User account record created recently: $f"; done
sub "Recent logins"; last -40
sub "sudoers (active lines)"; grep -vE '^[[:space:]]*(#|$)' /etc/sudoers; inv sudoers "/etc/sudoers $(sha /etc/sudoers)"
ls -laT /etc/sudoers.d
for f in /etc/sudoers.d/*; do [ -f "$f" ] && { echo "[$f]"; cat "$f"; inv sudoers "$f $(sha "$f")"; flag "Custom sudoers file present: $f"; }; done
grep -h "NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v '^[[:space:]]*#' | while read -r l; do flag "Passwordless sudo rule: $l"; done
sub "Auto-login"; defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>&1
[ -f /etc/kcpassword ] && flag "Auto-login password file /etc/kcpassword exists"
sub "Guest account"; defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>&1
