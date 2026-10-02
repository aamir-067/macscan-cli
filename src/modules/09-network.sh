#!/bin/bash
# @title  Network listeners, connections, proxy and DNS
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Listening sockets"
lsof -nP -iTCP -sTCP:LISTEN
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 && $9 !~ /^(127\.0\.0\.1|\[::1\]|localhost)/ {print $1, $2, $3, $9}' | sort -u | grep -vE "^(ControlCe|rapportd|sharingd|mDNSRespo|identitys|launchd|AirPlayXP)" | while read -r l; do inv listeners "$(echo "$l" | awk '{print $1}') network"; flag "Listener reachable from the network: $l"; done
sub "UDP sockets"; lsof -nP -iUDP | head -80

section "Connection sampling (6 snapshots over 60 seconds)"
T=$(tmpf)
for _ in 1 2 3 4 5 6; do lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null | awk 'NR>1 {print $1, $2, $3, $9}'; sleep 10; done | sort | uniq -c | sort -rn > "$T"
cat "$T"
section "Remote endpoints with reverse DNS"
awk '{print $5}' "$T" | sed -E 's/.*->//; s/:[0-9]+$//; s/^\[//; s/\]$//' | sort -u | grep -vE "^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|::1|fe80)" | head -120 | while read -r ip; do
  echo "$ip -> $(tmo 3 dig +short -x "$ip" 2>/dev/null | head -1)"
done
rm -f "$T"

section "Proxy, PAC and DNS"
scutil --proxy
scutil --proxy | grep -E "(HTTPEnable|HTTPSEnable|SOCKSEnable|ProxyAutoConfigEnable) : 1" >/dev/null && { inv network "system proxy enabled"; flag "A system proxy or PAC file is enabled (check it is yours)"; }
networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | sed 's/^\*//' | while IFS= read -r svc; do
  echo "[$svc]"
  networksetup -getwebproxy "$svc" 2>/dev/null | grep -E "Enabled|Server"
  networksetup -getsecurewebproxy "$svc" 2>/dev/null | grep -E "Enabled|Server"
  networksetup -getautoproxyurl "$svc" 2>/dev/null
  networksetup -getdnsservers "$svc" 2>/dev/null
done
sub "Resolvers"; scutil --dns | grep -E "nameserver\[[0-9]+\]" | sort -u
if [ -d /etc/resolver ]; then ls -la /etc/resolver; for x in /etc/resolver/*; do [ -f "$x" ] && inv network "resolver $x $(sha "$x")"; done; fi

section "hosts file"
grep -vE '^[[:space:]]*#|^[[:space:]]*$' /etc/hosts; inv network "hosts $(sha /etc/hosts)"
grep -vE '^[[:space:]]*#|^[[:space:]]*$' /etc/hosts | grep -vE "^(127\.0\.0\.1|255\.255\.255\.255|::1|fe80::1%lo0)[[:space:]]+(localhost|broadcasthost)[[:space:]]*$" | while read -r l; do flag "Custom hosts file entry: $l"; done

section "VPN, network extensions, packet filter, routes"
scutil --nc list
systemextensionsctl list 2>/dev/null | grep -iE "network|filter|vpn"
pfctl -s rules 2>/dev/null | head -60; ls -la /etc/pf.anchors
netstat -rn -f inet | head -40
