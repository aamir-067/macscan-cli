#!/bin/bash
# @title  Shell startup files and command hijacking
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Shell startup files (user and root)"
RCS=("$UH"/.zshrc "$UH"/.zshenv "$UH"/.zprofile "$UH"/.zlogin "$UH"/.zlogout "$UH"/.bashrc "$UH"/.bash_profile "$UH"/.bash_login "$UH"/.profile "$UH"/.inputrc /var/root/.zshrc /var/root/.zshenv /var/root/.bashrc /var/root/.profile /var/root/.bash_profile /etc/zshenv /etc/zshrc /etc/zprofile /etc/zlogin /etc/profile /etc/bashrc)
for f in "${RCS[@]}"; do
  [ -f "$f" ] || continue
  echo; echo "[$f] modified: $(stat -f '%Sm' "$f")"
  inv shell_rc "$f $(sha "$f")"
  grep -nvE '^[[:space:]]*#|^[[:space:]]*$' "$f"
  grep -nE "curl |wget |base64|osascript|nohup |/tmp/|\|[[:space:]]*(ba|z)?sh([[:space:]]|$)" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | while IFS= read -r l; do flag "Suspicious command in $f: $l"; done
done
[ -f /etc/zshenv ] && flag "/etc/zshenv exists (not present by default)"

section "Files your shell loads that changed in the last $DAYS days"
find "$UH/.oh-my-zsh" "$AS/amazon-q/shell" "$UH/.orbstack/shell" "$UH/.local/bin" "$UH/.zsh" "$UH/.config/zsh" -type f -mtime -"$DAYS" -not -path "*/.git/*" 2>/dev/null | head -150

section "Command hijacking (static checks, nothing is executed)"
for f in "${RCS[@]}" "$UH"/.oh-my-zsh/custom/*.zsh "$UH"/.oh-my-zsh/custom/*/*.zsh; do
  [ -f "$f" ] || continue
  grep -nE "^[[:space:]]*(alias[[:space:]]+(sudo|su|ssh|scp|git|security|passwd|login|osascript|curl)=|(function[[:space:]]+)?(sudo|su|ssh|git|security|passwd)[[:space:]]*\(\))" "$f" | while IFS= read -r l; do echo "$f: $l"; flag "Shell overrides a sensitive command in $f: $l"; done
done
sub "Sensitive commands that should only exist in system folders"
for dir in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/local/sbin "$UH/.local/bin" "$UH/bin" "$UH/.bun/bin" "$UH/.cargo/bin" "$UH"/.nvm/versions/node/*/bin "$UH/.antigravity/antigravity/bin" "$UH/.antigravity-ide/antigravity-ide/bin" "$UH/.opencode/bin"; do
  for c in sudo su passwd login security osascript launchctl dscl; do
    [ -e "$dir/$c" ] && { echo "$dir/$c"; flag "Sensitive command shadowed in PATH: $dir/$c"; }
  done
done

section "Suspicious commands in shell history"
for h in "$UH/.zsh_history" "$UH/.bash_history" /var/root/.zsh_history /var/root/.bash_history "$UH"/.zsh_sessions/*.history; do
  [ -f "$h" ] || continue
  echo "[$h]"
  grep -aiE "curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh|wget[^|]*\|[[:space:]]*(ba|z)?sh|base64 (-d|-D|--decode)|osascript|xattr .*(-c|-d|-r)|com\.apple\.quarantine|spctl --(master|global)-disable|chmod \+x /tmp|security (find|dump|unlock|export)|launchctl (load|bootstrap|submit)|nohup|sqlite3 .*(Cookies|Login Data|TCC)" "$h" | tail -150
done
