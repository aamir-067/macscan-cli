#!/bin/bash
# mac-triage shared helpers. Read-only.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export LC_ALL=C
DAYS="${DAYS:-60}"; MODULE="${MODULE:-core}"
AS="$UH/Library/Application Support"

section(){ echo; echo "==================== $* ===================="; }
sub(){ echo; echo "--- $*"; }
flag(){ echo "[!] $*"; echo "[$MODULE] $*" >> "$RUN/.flags.raw"; }
inv(){ local c="$1"; shift; [ -n "$INV" ] || return 0; printf '%s\n' "$*" >> "$INV/$c.txt"; }
asuser(){ launchctl asuser "$UID_N" sudo -H -u "$U" "$@"; }
tmo(){ local t="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$t" "$@"; }
# Temp files go in the scan's private folder (MT_TMP, root-only, inside state/).
# Never use the shared /tmp: another process can predict a name there and plant a symlink.
tmpf(){ mktemp "${MT_TMP:?}/t.XXXXXX"; }
sha(){ shasum -a 256 "$1" 2>/dev/null | awk '{print substr($1,1,16)}'; }
is_self(){ case "$1" in "$ROOT"/*|*com.mactriage.*) return 0;; esac; return 1; }
is_system_path(){ case "$1" in /System/*|/usr/libexec/*|/usr/sbin/*|/sbin/*|/bin/*|/usr/bin/*|/Library/Apple/*) return 0;; esac; return 1; }
is_dev_path(){ case "$1" in /opt/homebrew/*|/usr/local/Cellar/*|/usr/local/bin/*|"$UH"/.nvm/*|"$UH"/.bun/*|"$UH"/.cargo/*|"$UH"/.rustup/*|"$UH"/.local/*|"$UH"/.npm/*|"$UH"/go/*|"$UH"/.orbstack/*|*/node_modules/*|*/target/debug/*|*/target/release/*) return 0;; esac; return 1; }

sig(){
  local p="$1" info team auth state
  info=$(codesign -dv --verbose=2 "$p" 2>&1)
  team=$(awk -F= '/^TeamIdentifier=/{print $2}' <<<"$info")
  auth=$(awk -F= '/^Authority=/{print $2; exit}' <<<"$info")
  grep -q "Signature=adhoc" <<<"$info" && auth="ADHOC-SIGNED"
  grep -q "not signed" <<<"$info" && auth="UNSIGNED"
  if codesign --verify "$p" >/dev/null 2>&1; then state="valid"; else state="INVALID-OR-UNSIGNED"; fi
  echo "$p | ${auth:-unknown} | team=${team:-none} | $state"
}
sigf(){
  local line; line=$(sig "$1"); echo "$line"
  case "$line" in *UNSIGNED*|*ADHOC*|*INVALID*)
    if is_self "$1"; then echo "   note: this is mac-triage itself"
    elif is_dev_path "$1"; then echo "   note: developer tool path, often ad-hoc signed"
    else flag "Unsigned, ad-hoc or invalid signature: $line"; fi;;
  esac
}

redact(){ perl -pe '
  s/-----BEGIN [A-Z ]*PRIVATE KEY-----.*/<redacted private key>/;
  s/\b(sk-[A-Za-z0-9_-]{10,}|sk_live_[A-Za-z0-9]{10,}|rk_live_[A-Za-z0-9]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[abpr]-[A-Za-z0-9-]{10,}|npm_[A-Za-z0-9]{30,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})/<redacted>/g;
  s/\b((?:[A-Za-z0-9_]*(?:API_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE_KEY|ACCESS_KEY))\s*[=:]\s*)\S.*/$1<redacted>/gi;
  s#(://[^:/\s]+:)[^@/\s]+@#$1<redacted>@#g;
'; }

# Folders never walked: cloud drives, VM disks, caches, dependency trees, our own reports
PB=( -path "$UH/Library" -o -path "$UH/.Trash" -o -path "$UH/.orbstack" -o -path "$OUTBASE" -o -name node_modules -o -path "$UH/.npm" -o -path "$UH/.cache" -o -path "$UH/.gradle" -o -path "$UH/.rustup" -o -path "$UH/.cargo/registry" -o -path "$UH/go/pkg" -o -path "$UH/.bun/install" )
PRUNE=( \( "${PB[@]}" -o -name .git \) -prune -o )
# shellcheck disable=SC2034  # used by module 17
PRUNE_KEEPGIT=( \( "${PB[@]}" \) -prune -o )

# Discovery by structure, so newly installed browsers, editors and AI tools are found automatically
chromium_ext_dirs(){ find "$AS" -maxdepth 5 -type d -name Extensions -not -path "*/Extensions/*" 2>/dev/null | while IFS= read -r d; do ls "$d"/*/*/manifest.json >/dev/null 2>&1 && echo "$d"; done; }
firefox_ext_files(){ find "$AS" -maxdepth 5 -name extensions.json -path "*Profiles*" 2>/dev/null | sort -u; }
editor_ext_dirs(){ for d in "$UH"/.*/extensions "$UH"/.*/*/extensions "$AS/Zed/extensions/installed"; do [ -d "$d" ] && echo "$d"; done; }
mcp_files(){
  {
    [ -f "$UH/.claude.json" ] && echo "$UH/.claude.json"
    find "$UH" -maxdepth 5 "${PRUNE[@]}" -type f \( -name "*.json" -o -name "*.jsonc" \) -size -3000k -print0 2>/dev/null | xargs -0 grep -lE '"(mcpServers|mcp)"[[:space:]]*:' 2>/dev/null
    find "$AS" -maxdepth 3 -type f -name "*.json" -size -3000k -print0 2>/dev/null | xargs -0 grep -lE '"(mcpServers|mcp)"[[:space:]]*:' 2>/dev/null
  } | sort -u
}
