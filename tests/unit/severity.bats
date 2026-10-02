#!/usr/bin/env bats
# core/lib/severity.sh

load ../helpers

setup(){ make_env; source "$SRC/core/lib/severity.sh"; }
teardown(){ drop_env; }

sev_of(){ printf '%s\n' "$1" > "$TEST_TMP/f"; classify_flags "$TEST_TMP/f" | cut -f2; }

@test "known prefixes get their rubric severity" {
  [ "$(sev_of '[17-code-repos] Injected malware marker found: /x.js')" = critical ]
  [ "$(sev_of '[19-yara] YARA match: Rule /x')" = high ]
  [ "$(sev_of '[16-dev-environment] Non-default package registry configured: x')" = medium ]
  [ "$(sev_of '[09-network] Listener reachable from the network: x')" = low ]
}

@test "unknown messages default to medium" {
  [ "$(sev_of '[99-x] Something nobody wrote a rule for')" = medium ]
}

@test "new inventory items: persistence categories are high, others medium" {
  [ "$(sev_of '[new since last scan] [launch] /Library/LaunchAgents/x.plist | /tmp/x | abc')" = high ]
  [ "$(sev_of '[new since last scan] [apps] /Applications/X.app | team=ABC')" = medium ]
}

@test "the flag line itself is unchanged" {
  printf '%s\n' '[05-persistence-launchd] Hidden launch item file: /Library/LaunchAgents/.x' > "$TEST_TMP/f"
  [ "$(classify_flags "$TEST_TMP/f" | cut -f3)" = '[05-persistence-launchd] Hidden launch item file: /Library/LaunchAgents/.x' ]
}

@test "every flag message in the modules has an explicit rule" {
  missing=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s\n' "$SEVERITY_RULES" | awk -F'\t' -v m="$p" 'index(m,$2)==1{f=1} END{exit !f}' || missing="$missing
$p"
  done < <(grep -ho 'flag "[^"$]*' "$SRC"/modules/*.sh "$SRC"/core/*.sh | sed 's/^flag "//' | sort -u)
  [ -z "$missing" ] || { echo "no severity rule for:$missing"; return 1; }
}
