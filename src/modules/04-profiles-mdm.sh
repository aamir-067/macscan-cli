#!/bin/bash
# @title  Configuration profiles and MDM
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Configuration profiles and MDM"
profiles status -type enrollment 2>&1
p=$(profiles list -all 2>&1); echo "$p"
echo "$p" | grep -o "profileIdentifier: .*" | while IFS= read -r l; do inv profiles "$l"; flag "Configuration profile installed (verify it is yours): $l"; done
sub "Profile details"; profiles show -type configuration 2>&1 | head -300
sub "Managed preferences"; ls -laR "/Library/Managed Preferences" 2>/dev/null | head -80
