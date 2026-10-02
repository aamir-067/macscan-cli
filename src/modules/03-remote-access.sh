#!/bin/bash
source /usr/local/mac-triage/core/common.sh
section "Remote access and sharing"
r=$(systemsetup -getremotelogin 2>/dev/null); sub "Remote Login (SSH server)"; echo "$r"
echo "$r" | grep -q ": On" && { flag "Remote Login (SSH server) is ON"; inv remote "Remote Login on"; }
sub "Sharing services"
launchctl print-disabled system 2>/dev/null | grep -iE "ssh|screensharing|smbd|ftp|ARD|remotemanagement|AppleFileServer"
for svc in com.apple.screensharing com.openssh.sshd com.apple.smbd com.apple.RemoteDesktop.agent; do
  launchctl print "system/$svc" >/dev/null 2>&1 && { echo "enabled: $svc"; inv remote "service $svc"; }
done
launchctl print system/com.apple.screensharing >/dev/null 2>&1 && flag "Screen Sharing is enabled"
pgrep -x ARDAgent >/dev/null && flag "Apple Remote Desktop agent is running"
sub "authorized_keys on this Mac"
for h in /Users/* /var/root; do f="$h/.ssh/authorized_keys"; [ -f "$f" ] && { echo "[$f]"; cat "$f"; inv remote "authorized_keys $f $(sha "$f")"; flag "authorized_keys file exists on this Mac: $f"; }; done
sub "sshd configuration (active lines)"; grep -vE '^[[:space:]]*(#|$)' /etc/ssh/sshd_config 2>/dev/null; ls -laT /etc/ssh/sshd_config.d 2>/dev/null
sub "Remote access and tunnel tools on disk"
find /Applications "$UH/Applications" "/Library/Application Support" "$AS" /opt/homebrew/bin /usr/local/bin "$UH/.local/bin" -maxdepth 2 \( -iname "*anydesk*" -o -iname "*teamviewer*" -o -iname "*rustdesk*" -o -iname "*screenconnect*" -o -iname "*splashtop*" -o -iname "*ngrok*" -o -iname "*cloudflared*" -o -iname "frpc" -o -iname "chisel" -o -iname "*parsec*" -o -iname "*jumpdesktop*" \) 2>/dev/null | while IFS= read -r p; do echo "$p"; inv remote "tool $p"; flag "Remote access or tunnel tool present: $p"; done
sub "Remote access and tunnel tools running"
ps -axo pid=,command= | grep -iE "anydesk|teamviewer|rustdesk|screenconnect|splashtop|ngrok|cloudflared|frpc|chisel|socat" | grep -v grep | while IFS= read -r l; do echo "$l"; flag "Remote access or tunnel process running: $(echo "$l" | cut -c1-200)"; done
