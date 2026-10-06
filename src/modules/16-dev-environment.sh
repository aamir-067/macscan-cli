#!/bin/bash
# @title  Developer environment and AI tools
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Editor extensions (found automatically)"
editor_ext_dirs | while IFS= read -r d; do
  sub "$d"
  find "$d" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r x; do
    n=$(basename "$x"); echo "$(stat -f '%SB' "$x") $n"
    inv editor_ext "$d | $(echo "$n" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+.*$//')"
  done | sort
done

section "Neovim and shell plugins (where their code comes from)"
find "$UH/.local/share" "$UH/.oh-my-zsh/custom" "$UH/.config" -maxdepth 5 -path "*/.git/config" 2>/dev/null | while IFS= read -r c; do
  r=$(dirname "$(dirname "$c")"); url=$(awk -F' = ' '/url = /{print $2; exit}' "$c")
  echo "$r -> $url"; inv plugins "$(basename "$r") | $url"
done

section "MCP and AI tool server commands (found automatically)"
# mcp_where <path>: "temp" or "hidden" when an MCP server's program or script lives in a temp
# folder or in a hidden folder in home that no known tool installs into. SANDWORM_MODE's
# McpInject (npm worm, Socket and SafeDep, 2026-02) writes its server to a random hidden
# folder such as ~/.node-cache and registers it in Claude, Cursor, Continue and Windsurf.
mcp_where(){
  local p; p=$(canon_path "$1")
  case "$p" in
    "$UH"/.*/*) ;;
    "$UH"/*) return;;
    /tmp/*|/private/tmp/*|/var/tmp/*|/private/var/tmp/*|/var/folders/*|/private/var/folders/*|/Users/Shared/*) echo temp; return;;
    *) return;;
  esac
  is_dev_path "$p" && return
  case "$p" in "$UH"/.claude/plugins/*|"$UH"/.*/extensions/*|"$UH"/.volta/*|"$UH"/.pyenv/*|"$UH"/.asdf/*|"$UH"/.deno/*|"$UH"/.fnm/*|"$UH"/.nodenv/*|"$UH"/.pnpm/*|"$UH"/.docker/*|"$UH"/.pixi/*|"$UH"/.sdkman/*|"$UH"/.rbenv/*|"$UH"/.juliaup/*) return;; esac
  echo hidden
}
mcp_files | while IFS= read -r f; do
  echo "[$f]"
  perl -MJSON::PP -e '
    local $/; my $j=eval{decode_json(<STDIN>)} or exit;
    sub cmd { my $s=shift; my @c; for my $k (qw(command args url)) { my $v=$s->{$k}; next unless defined $v; push @c, (ref $v eq "ARRAY") ? (grep {!ref} @$v) : (ref $v ? () : $v) } join(" ",@c) }
    sub walk { my ($n,$p)=@_;
      if(ref $n eq "HASH"){
        for my $key (qw(mcpServers mcp)) { my $m=$n->{$key}; next unless ref $m eq "HASH"; for my $k (sort keys %$m){ my $s=$m->{$k}; next unless ref $s eq "HASH"; my $c=cmd($s); $c=~s/[\t\n]/ /g; print "$p$k: $c\t$c\n" } }
        for (keys %$n){ walk($n->{$_}, "$p$_/") if ref $n->{$_} } }
      elsif(ref $n eq "ARRAY"){ walk($_,$p) for @$n } }
    walk($j,"");' < "$f" | while IFS=$'\t' read -r l c; do
      echo "  $l"; inv mcp "$f | $l"
      # Paths in the command and its arguments only (never the JSON key path, which in
      # ~/.claude.json is a project folder). $HOME, ${HOME} and ~/ count as the home folder.
      c=${c//\$\{HOME\}/$UH}; c=${c//\$HOME/$UH}; c=${c//\~\//$UH/}
      w=$(printf '%s\n' "$c" | grep -oE "/[^[:space:]\"',;]+" | while IFS= read -r t; do mcp_where "$t"; done | sort -u | tail -1)
      case "$w" in
        temp) flag "MCP server runs code from a temp folder: $f | $l";;
        hidden) flag "MCP server runs code from a hidden folder (verify): $f | $l";;
      esac
    done
done

section "AI tool hooks (commands that run automatically)"
{ ls "$UH"/.claude/settings*.json 2>/dev/null; find "$UH" -maxdepth 6 "${PRUNE[@]}" -path "*/.claude/settings*.json" -print 2>/dev/null; } | sort -u | while IFS= read -r f; do
  /usr/bin/jq -r '(.hooks // {}) | .. | objects | select(has("command")) | .command' "$f" 2>/dev/null | while IFS= read -r c; do echo "$f: $c"; inv hooks "$f | $c"; done
done
sub "Claude Code plugins"
ls -1 "$UH/.claude/plugins/marketplaces" 2>/dev/null | while read -r m; do echo "marketplace: $m"; inv claude_plugins "marketplace $m"; done
/usr/bin/jq -r '(.plugins // {}) | keys[]' "$UH/.claude/plugins/installed_plugins.json" 2>/dev/null | while read -r p; do echo "plugin: $p"; inv claude_plugins "plugin $p"; done

section "Package manager configs (registry hijack check)"
for f in "$UH/.npmrc" "$UH/.yarnrc" "$UH/.yarnrc.yml" "$UH/.bunfig.toml" "$UH/.config/pip/pip.conf" "$UH/.pip/pip.conf" "$UH/.pypirc" "$UH/.cargo/config.toml" "$UH/.gemrc" /etc/npmrc /opt/homebrew/etc/npmrc; do
  [ -f "$f" ] && { echo "[$f]"; rd "$f"; inv registries "$f $(sha "$f")"; }
done
rd "$UH/.npmrc" "$UH/.yarnrc" "$UH/.yarnrc.yml" "$UH/.bunfig.toml" "$UH/.config/pip/pip.conf" "$UH/.pip/pip.conf" /etc/npmrc 2>/dev/null | grep -iE "registry|index-url" | grep -vE "registry\.npmjs\.org|registry\.yarnpkg\.com|pypi\.org" | while read -r l; do flag "Non-default package registry configured: $l"; done

section "Global packages"
for d in /opt/homebrew/lib/node_modules /usr/local/lib/node_modules "$UH"/.nvm/versions/node/*/lib/node_modules "$UH/.bun/install/global/node_modules"; do
  [ -d "$d" ] && { echo "[$d]"; ls -1 "$d" | while read -r p; do echo "$p"; inv global_pkgs "$d | $p"; done; }
done
sub "cargo bin"; ls -1 "$UH/.cargo/bin" 2>/dev/null
# shellcheck disable=SC2088  # label text, not a path
sub "~/.local/bin"; ls -la "$UH/.local/bin" 2>/dev/null
sub "Python user packages"; ls -1 "$UH"/Library/Python/*/lib/python/site-packages 2>/dev/null | grep -vE "dist-info|__pycache__" | head -120
sub "npx cache"; for p in "$UH"/.npm/_npx/*/node_modules; do [ -d "$p" ] && ls -1 "$p" | grep -v '^\.'; done | sort -u | head -150

section "Git configuration"
for f in "$UH/.gitconfig" "$UH/.config/git/config" /etc/gitconfig /opt/homebrew/etc/gitconfig; do [ -f "$f" ] && { echo "[$f]"; rd "$f"; inv gitcfg "$f $(sha "$f")"; }; done
# Only the exact "helper = osxkeychain" line is the macOS default; a helper line that merely
# mentions osxkeychain (for example a shell function that also runs curl) is still reported.
for f in "$UH/.gitconfig" "$UH/.config/git/config" /etc/gitconfig; do [ -f "$f" ] && rd "$f" | grep -vE '^[[:space:]]*[#;]' | grep -iE "hooksPath|templateDir|sshCommand|fsmonitor|pager|askpass|textconv|external|helper" | grep -viE '^[[:space:]]*helper[[:space:]]*=[[:space:]]*osxkeychain[[:space:]]*$' | sed "s|^|$f:|"; done | while read -r l; do flag "Git setting that can run commands (verify): $l"; done
sub "Hooks git adds to every new repository or runs in every repository"
# SANDWORM_MODE (npm worm, 2026-02) sets a global init.templateDir so every new clone gets
# its pre-commit and pre-push hooks; a global core.hooksPath reaches existing repositories.
{
  for f in "$UH/.gitconfig" "$UH/.config/git/config" /etc/gitconfig /opt/homebrew/etc/gitconfig; do
    [ -f "$f" ] || continue
    git_cfg "$f" init templatedir | while IFS= read -r d; do printf 'template\t%s\n' "$d/hooks"; done
    git_cfg "$f" core hookspath | while IFS= read -r d; do printf 'global\t%s\n' "$d"; done
  done
  printf 'template\t%s\n' "$UH/.git-templates/hooks"
} | sort -u | while IFS=$'\t' read -r kind d; do
  case "$d" in /*) ;; *) continue;; esac
  [ -d "$d" ] || continue
  for h in "$d"/*; do
    [ -f "$h" ] || continue
    case "$h" in *.sample) continue;; esac
    echo "$kind: $h"
    if hook_runs_hidden_code "$h"; then flag "Git hook downloads or runs hidden code: $h"
    elif [ "$kind" = template ]; then flag "Git template adds a hook to every new repository (verify): $h"
    else flag "Global git hook runs in every repository (verify): $h"; fi
  done
done

section "SSH client"
ls -laT "$UH/.ssh"; [ -f "$UH/.ssh/config" ] && rd "$UH/.ssh/config"; [ -f "$UH/.ssh/config" ] && inv sshcfg "$UH/.ssh/config $(sha "$UH/.ssh/config")"
grep -vE '^[[:space:]]*(#|$)' /etc/ssh/ssh_config 2>/dev/null; ls -la /etc/ssh/ssh_config.d 2>/dev/null
# Comments and "PermitLocalCommand no" are skipped: the stock /etc/ssh/ssh_config documents
# ProxyCommand and PermitLocalCommand in comments, which used to raise two flags on every Mac.
for f in "$UH/.ssh/config" /etc/ssh/ssh_config /etc/ssh/ssh_config.d/*; do [ -f "$f" ] && rd "$f" | grep -vE '^[[:space:]]*#' | grep -viE '^[[:space:]]*PermitLocalCommand[[:space:]=]+no[[:space:]]*$' | grep -iE "ProxyCommand|LocalCommand|PermitLocalCommand|KnownHostsCommand" | sed "s|^|$f:|"; done | while read -r l; do flag "SSH config can run commands (verify): $l"; done
ls "$UH/.ssh" 2>/dev/null | grep -vE "\.pub$|^config$|^known_hosts|^authorized_keys$" | while read -r k; do flag "File in ~/.ssh may be a private key: $k"; done

section "Credential files on disk (paths only)"
for f in "$UH/.aws/credentials" "$UH/.aws/config" "$UH/.config/gcloud/credentials.db" "$UH/.config/gcloud/application_default_credentials.json" "$UH/.azure" "$UH/.kube/config" "$UH/.docker/config.json" "$UH/.config/gh/hosts.yml" "$UH/.netrc" "$UH/.git-credentials" "$UH/.vercel" "$UH/.supabase" "$UH/.config/stripe/config.toml" "$UH/.config/configstore/firebase-tools.json"; do
  [ -e "$f" ] && { echo "present: $f (modified $(stat -f '%Sm' "$f"))"; inv creds "$f"; }
done
section ".env files on disk (paths only, no contents)"
find "$UH" "${PRUNE[@]}" -type f \( -name ".env" -o -name ".env.*" -o -name "*.env" \) -not -name ".env.example" -not -name ".env.sample" -print 2>/dev/null | while IFS= read -r f; do echo "$(stat -f '%Sm' "$f") $f"; done | sort | head -300
