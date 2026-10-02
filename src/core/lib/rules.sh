# shellcheck shell=bash
# YARA rule and ClamAV signature updates. Downloads and compiles run as the user, never as root.

# The download and compile happen in a temp folder owned by the user. Root never
# writes into that folder and never reads it directly: inputs go in through stdin and
# outputs come back through `cat` run as the user, so a symlink planted there cannot
# make root overwrite, chown or disclose a file the user could not already touch.

# rules_build_as_user <user tmp dir>: stdin is custom.yar.
rules_build_as_user(){
  sudo -u "$U" -H /bin/bash -c '
    cd "$1" || exit 1; Y="$2"
    cat > custom.yar
    if /usr/bin/curl -fsSL --max-time 300 -o forge.zip "https://github.com/YARAHQ/yara-forge/releases/latest/download/yara-forge-rules-core.zip"; then
      mkdir -p forge && /usr/bin/ditto -x -k forge.zip forge 2>/dev/null
      f=$(find forge -name "*.yar" | head -1)
      if [ -n "$f" ] && "$Y" -w "$f" /dev/null 2>/dev/null; then cp "$f" forge.yar; echo "  YARA Forge core rules: ok"; else echo "  YARA Forge core rules: did not compile, skipped"; fi
    else echo "  YARA Forge core rules: download failed"; fi
    if /usr/bin/curl -fsSL --max-time 900 -o el.zip "https://github.com/elastic/protections-artifacts/archive/refs/heads/main.zip"; then
      mkdir -p el && /usr/bin/ditto -x -k el.zip el 2>/dev/null
      : > elastic.yar; ok=0
      find el -path "*/yara/rules/*" \( -name "MacOS_*.yar" -o -name "Multi_*.yar" \) > el.list
      while IFS= read -r r; do if "$Y" -w "$r" /dev/null 2>/dev/null; then echo "include \"$PWD/$r\"" >> elastic.yar; ok=$((ok+1)); fi; done < el.list
      if [ "$ok" -gt 0 ]; then echo "  Elastic macOS and multi-platform rules: $ok files"; else rm -f elastic.yar; fi
    else echo "  Elastic rules: download failed"; fi
    A="custom:custom.yar"; F=""; E=""
    [ -f forge.yar ] && F="forge:forge.yar"; [ -f elastic.yar ] && E="elastic:elastic.yar"
    if "$Y" -w $A $F $E all.yarc 2>yarac.err; then echo "custom $F $E" > sets.txt
    elif "$Y" -w $A $F all.yarc 2>>yarac.err; then echo "custom $F" > sets.txt
    else "$Y" -w $A all.yarc 2>>yarac.err && echo "custom" > sets.txt; fi
  ' _ "$1" "$YARAC"
}

# rules_collect <user tmp dir> <root-only stage dir>: copies and validates the results.
rules_collect(){
  local utmp="$1" stage="$2" sets
  # shellcheck disable=SC2024  # intended: read as the user, write into the root-only stage
  sudo -u "$U" /bin/cat "$utmp/all.yarc" > "$stage/all.yarc" 2>/dev/null || return 1
  [ "$(head -c 4 "$stage/all.yarc")" = YARA ] || { echo "  Compiled rules have an unexpected format, ignored."; return 1; }
  sets=$(sudo -u "$U" /bin/cat "$utmp/sets.txt" 2>/dev/null | head -1 | tr -s ' ' | sed 's/ $//')
  case "$sets" in
    "custom"|"custom forge:forge.yar"|"custom elastic:elastic.yar"|"custom forge:forge.yar elastic:elastic.yar") ;;
    *) echo "  Rule set list has unexpected content, ignored."; return 1;;
  esac
  echo "$sets" | sed -e 's/forge:forge.yar/yara-forge/' -e 's/elastic:elastic.yar/elastic/' > "$stage/sets.txt"
}

update_rules(){
  local now last utmp stage
  [ -x "$YARAC" ] || { echo "YARA is not installed, skipping rule update."; return 0; }
  now=$(date +%s); last=$(cat "$STATE/rules-updated" 2>/dev/null || echo 0)
  if [ "${1:-}" != force ] && [ $((now-last)) -lt 604800 ] && [ -f "$ROOT/rules/all.yarc" ]; then return 0; fi
  echo "Updating YARA rules (runs as $U)..."
  utmp=$(sudo -u "$U" /usr/bin/mktemp -d /tmp/mactriage-rules.XXXXXX) || return 0
  case "$utmp" in /tmp/mactriage-rules.*) ;; *) echo "  Unexpected temp folder, skipping."; return 0;; esac
  stage=$(mktemp -d "$STATE/rules.XXXXXX") || return 0
  rules_build_as_user "$utmp" < "$ROOT/rules/custom.yar"
  if rules_collect "$utmp" "$stage"; then
    cp "$stage/all.yarc" "$ROOT/rules/all.yarc.new" && mv -f "$ROOT/rules/all.yarc.new" "$ROOT/rules/all.yarc"
    cp "$stage/sets.txt" "$ROOT/rules/sets.txt"
    chmod 644 "$ROOT/rules/all.yarc" "$ROOT/rules/sets.txt"; date +%s > "$STATE/rules-updated"
    echo "  Compiled rule sets: $(cat "$ROOT/rules/sets.txt")"
  else echo "  Rule compile failed, keeping the previous rules."; fi
  sudo -u "$U" /bin/rm -rf "$utmp"
  rm -rf "$stage"
}

update_clam(){
  local now last
  [ -x "$FRESHCLAM" ] || return 0
  now=$(date +%s); last=$(cat "$STATE/clam-updated" 2>/dev/null || echo 0)
  if [ "${1:-}" != force ] && [ $((now-last)) -lt 86400 ]; then return 0; fi
  echo "Updating ClamAV signatures (runs as $U)..."
  if sudo -u "$U" -H "$FRESHCLAM" --quiet; then date +%s > "$STATE/clam-updated"; echo "  ClamAV signatures: ok"
  else echo "  ClamAV update failed, will retry next scan."; fi
}
