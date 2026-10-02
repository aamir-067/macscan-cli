#!/bin/bash
# mac-triage shared helpers. Read-only.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/text.sh
source "$ROOT/core/lib/text.sh"
export LC_ALL=C
DAYS="${DAYS:-60}"; MODULE="${MODULE:-core}"
AS="$UH/Library/Application Support"

section(){ echo; echo "==================== $* ===================="; }
sub(){ echo; echo "--- $*"; }
flag(){ echo "[!] $*"; [ -z "$RUN" ] || echo "[$MODULE] $*" >> "$RUN/.flags.raw"; }
inv(){ local c="$1"; shift; [ -n "$INV" ] || return 0; printf '%s\n' "$*" >> "$INV/$c.txt"; }
asuser(){ launchctl asuser "$UID_N" sudo -H -u "$U" "$@"; }
tmo(){ local t="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$t" "$@"; }
# Temp files go in the scan's private folder (MT_TMP, root-only, inside state/).
# Never use the shared /tmp: another process can predict a name there and plant a symlink.
# SQLite as root on files a user can create: skip ~/.sqliterc, use safe mode (no .shell,
# ATTACH, extensions or file I/O functions) and open read-only.
sql(){ /usr/bin/sqlite3 -noinit -safe -readonly "$@"; }
tmpf(){ mktemp "${MT_TMP:?}/t.XXXXXX"; }
sha(){ shasum -a 256 "$1" 2>/dev/null | awk '{print substr($1,1,16)}'; }
# Places the target user can write. Files there are read with the user's rights, so a
# symlink planted there cannot make root print a file the user may not read (for
# example an account's password hash under /var/db/dslocal).
user_path(){ case "$1" in "$UH"/*|/Users/Shared/*|/Applications/*|/opt/homebrew/*|/usr/local/*|/tmp/*|/private/tmp/*|/var/tmp/*|/private/var/tmp/*) return 0;; esac; return 1; }
rd(){ local f; for f in "$@"; do if user_path "$f"; then sudo -u "$U" /bin/cat -- "$f"; else cat -- "$f"; fi; done; }
is_self(){ case "$1" in "$ROOT"/*|*com.mactriage.*) return 0;; esac; return 1; }
# /System/Volumes/Data is the writable data volume: /System/Volumes/Data/private/tmp/x is
# the same file as /private/tmp/x. Strip that prefix before judging where something lives.
canon_path(){ case "$1" in /System/Volumes/Data/*) printf '%s\n' "${1#/System/Volumes/Data}";; *) printf '%s\n' "$1";; esac; }
is_system_path(){ case "$1" in /System/Volumes/Data/*) return 1;; /System/*|/usr/libexec/*|/usr/sbin/*|/sbin/*|/bin/*|/usr/bin/*|/Library/Apple/*) return 0;; esac; return 1; }
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

# redact: masks secrets in everything written to a report. Patterns are deliberately
# broad; a masked harmless value costs little, a leaked key costs a rotation.
redact(){ sanitize | perl -pe '
  s/-----BEGIN [A-Z ]*PRIVATE KEY-----.*/<redacted private key>/;
  s/\b(sk-[A-Za-z0-9_-]{10,}|sk_(?:live|test)_[A-Za-z0-9]{10,}|rk_live_[A-Za-z0-9]{10,}|whsec_[A-Za-z0-9]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|hf_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[abpr]-[A-Za-z0-9-]{10,}|xapp-[A-Za-z0-9-]{10,}|npm_[A-Za-z0-9]{30,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})/<redacted>/g;
  s#(hooks\.slack\.com/services/|discord(?:app)?\.com/api/webhooks/)\S+#$1<redacted>#gi;
  s/\b(Bearer|Basic)\s+[A-Za-z0-9._~+\/-]{8,}=*/$1 <redacted>/g;
  s/((?:^|\s)--?(?:password|passwd|pass|token|secret|api[-_]?key|access[-_]?key|auth-token)[= ])\S+/$1<redacted>/gi;
  s/("[A-Za-z0-9_-]*(?:password|passwd|secret|token|api_?key|apikey|auth(?!or)|private_?key|access_?key)[A-Za-z0-9_-]*"\s*:\s*)"[^"]*"/$1"<redacted>"/gi;
  s/\b((?:[A-Za-z0-9_]*(?:API_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE_KEY|ACCESS_KEY|AccountKey))\s*[=:]\s*)\S.*/$1<redacted>/gi;
  s#(://[^:/\s]+:)[^@/\s]+@#$1<redacted>@#g;
'; }

# Download origins (macOS 27 leaves URLs out of the quarantine database, but each file
# keeps kMDItemWhereFroms). origin_category <url> prints chat, shortener, fileshare,
# github-release, hosting, or nothing.
origin_category(){
  local u host path
  u=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  host=$(printf '%s' "$u" | sed -E 's#^[a-z][a-z0-9+.-]*://##; s#[/?\#].*$##; s#^.*@##; s#:[0-9]+$##')
  path=$(printf '%s' "$u" | sed -E 's#^[a-z][a-z0-9+.-]*://[^/]*##')
  case "$host" in
    cdn.discordapp.com|media.discordapp.net|discord.com|t.me|telegram.org|*.telegram.org|cdn*.telesco.pe|web.whatsapp.com|*.whatsapp.net|files.slack.com|slack-files.com) echo chat;;
    bit.ly|t.co|tinyurl.com|is.gd|cutt.ly|rebrand.ly|shorturl.at|rb.gy|t.ly|goo.gl|ow.ly|buff.ly|tiny.cc|s.id|v.gd|shorturl.gg) echo shortener;;
    mega.nz|mega.io|*.mediafire.com|mediafire.com|*.dropbox.com|dropbox.com|*.dropboxusercontent.com|drive.google.com|drive.usercontent.google.com|wetransfer.com|*.wetransfer.com|we.tl|gofile.io|*.gofile.io|pixeldrain.com|anonfiles.com|*.sendspace.com|sendspace.com|*.4shared.com|transfer.sh|files.catbox.moe|catbox.moe|file.io|onedrive.live.com|1drv.ms|*.box.com|filebin.net|krakenfiles.com|uploadhaven.com) echo fileshare;;
    objects.githubusercontent.com|release-assets.githubusercontent.com) echo github-release;;
    github.com) case "$path" in /*/*/releases/download/*) echo github-release;; esac;;
    *.pages.dev|*.vercel.app|*.netlify.app|*.github.io|*.glitch.me|*.ngrok.io|*.ngrok-free.app|*.ngrok.app|*.trycloudflare.com|raw.githubusercontent.com|gist.githubusercontent.com|*.web.app|*.firebaseapp.com|*.r2.dev|*.workers.dev) echo hosting;;
  esac
}

# exec_like <file>: true for programs, installers, scripts and archives.
exec_like(){
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.dmg|*.pkg|*.mpkg|*.app|*.zip|*.tar|*.tgz|*.gz|*.bz2|*.xz|*.7z|*.rar|*.command|*.sh|*.tool|*.jar|*.iso|*.xip|*.scpt|*.applescript|*.terminal|*.workflow|*.py) return 0;;
  esac
  [ -f "$1" ] && [ -x "$1" ]
}

# origin_check <file> <url>...: flags an executable-like download by where it came from.
origin_check(){
  local f="$1" u c owner; shift
  exec_like "$f" || return 0
  for u in "$@"; do
    c=$(origin_category "$u")
    case "$c" in
      chat) flag "Downloaded executable from a chat attachment: $f <- $u";;
      shortener) flag "Downloaded executable from a link shortener: $f <- $u";;
      fileshare) flag "Downloaded executable from a file-sharing site: $f <- $u";;
      github-release)
        owner=$(printf '%s' "$u" | sed -nE 's#^https?://github\.com/([^/]+/[^/]+)/releases/download/.*#\1#p')
        flag "Downloaded executable from a GitHub release (verify the repository${owner:+ $owner}): $f <- $u";;
      hosting) flag "Downloaded executable from a free hosting site: $f <- $u";;
      *) continue;;
    esac
    return 0
  done
  return 0
}

# The Trash is skipped by the malware sweeps unless INCLUDE_TRASH=yes (--include-trash).
# shellcheck disable=SC2034  # used by modules 14 and 19
if [ "${INCLUDE_TRASH:-no}" = yes ]; then TRASHP="/nonexistent/mac-triage-no-prune"; else TRASHP="$UH/.Trash"; fi

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
