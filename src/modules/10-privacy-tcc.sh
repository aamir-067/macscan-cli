#!/bin/bash
source /usr/local/mac-triage/core/common.sh
CUT="CAST(strftime('%s','now','-$DAYS days') AS INTEGER)"
section "Locating privacy (TCC) databases"
DBS=()
while IFS= read -r d; do DBS+=("$d"); done < <( { find "$UH/Library" -maxdepth 4 -path "$UH/Library/CloudStorage" -prune -o -name "TCC.db" -print; find "/Library/Application Support" /private/var/db -maxdepth 4 -name "TCC.db" -print; } 2>/dev/null | sort -u )
if [ ${#DBS[@]} -eq 0 ]; then flag "Could not locate any privacy (TCC) database, permission checks skipped"; exit 0; fi
printf '%s\n' "${DBS[@]}"

section "All granted privacy permissions"
for db in "${DBS[@]}"; do
  sub "$db"
  sqlite3 -readonly -separator ' | ' "$db" "select service, client, coalesce(indirect_object_identifier,''), datetime(last_modified,'unixepoch','localtime') from access where auth_value=2 order by service, client" 2>&1 || echo "Could not read this database."
  sqlite3 -readonly -separator ' | ' "$db" "select service, client from access where auth_value=2" 2>/dev/null | while IFS= read -r l; do inv tcc "$l"; done
done

section "High-risk permissions granted in the last $DAYS days"
for db in "${DBS[@]}"; do
  sqlite3 -readonly -separator ' | ' "$db" "select service, client, datetime(last_modified,'unixepoch','localtime') from access where auth_value=2 and last_modified > $CUT and service in ('kTCCServiceAccessibility','kTCCServiceListenEvent','kTCCServicePostEvent','kTCCServiceScreenCapture','kTCCServiceSystemPolicyAllFiles','kTCCServiceEndpointSecurityClient','kTCCServiceDeveloperTool','kTCCServiceAppleEvents')" 2>/dev/null
done | grep -v "com.mactriage" | while read -r l; do echo "$l"; flag "High-risk permission granted recently: $l"; done

section "Permissions held by apps that are no longer installed"
for db in "${DBS[@]}"; do sqlite3 -readonly "$db" "select distinct client from access where client_type=0" 2>/dev/null; done | sort -u | while read -r id; do
  [ -z "$id" ] && continue
  case "$id" in com.apple.*|com.mactriage.*) continue;; esac
  loc=$(mdfind "kMDItemCFBundleIdentifier == '$id'" 2>/dev/null | head -1)
  [ -z "$loc" ] && { echo "$id"; flag "Permission belongs to an app no longer on disk: $id"; }
done
