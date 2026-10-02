#!/bin/bash
# @title  Keychains and certificate trust
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Keychains"
asuser security list-keychains
ls -laT "$UH/Library/Keychains" /Library/Keychains 2>/dev/null
section "Custom certificate trust settings"
sub "Admin domain"; a=$(security dump-trust-settings -d 2>&1); echo "$a" | head -100
echo "$a" | grep "^Cert " | while IFS= read -r l; do inv certs "admin $l"; done
echo "$a" | grep -q "^Cert " && flag "Admin-trusted custom certificates exist (can allow traffic interception, verify each)"
sub "User domain"; u=$(asuser security dump-trust-settings 2>&1); echo "$u" | head -100
echo "$u" | grep "^Cert " | while IFS= read -r l; do inv certs "user $l"; done
echo "$u" | grep -q "^Cert " && flag "User-trusted custom certificates exist (verify each)"
section "Certificates in the System keychain"
security find-certificate -a /Library/Keychains/System.keychain 2>/dev/null | grep '"labl"' | sort -u | while IFS= read -r l; do echo "$l"; inv certs "system $l"; done
