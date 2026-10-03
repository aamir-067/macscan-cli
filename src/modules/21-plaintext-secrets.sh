#!/bin/bash
# @title  Plaintext secrets in Downloads, Desktop and Documents (paths only)
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"

section "Password exports, private keys and .env files (paths only, never contents)"
echo "Only the first line of CSV and key files is read, to recognize their format."
echo "If one of these is yours: confirm the secrets are in your password manager, then delete the file."

# in_project <file>: the file sits inside a code project (its .env is expected there).
in_project(){
  local d; d=$(dirname "$1")
  while [ "$d" != "$UH" ] && [ "$d" != / ] && [ -n "$d" ]; do
    for m in .git package.json pyproject.toml requirements.txt composer.json Gemfile go.mod Cargo.toml; do
      [ -e "$d/$m" ] && return 0
    done
    d=$(dirname "$d")
  done
  return 1
}

hit(){ echo "$2: $3"; flag "$2: $3"; inv secrets "$1 $3"; }

L=$(tmpf)
find "$UH/Downloads" "$UH/Desktop" "$UH/Documents" -maxdepth 6 \
  \( -path "$OUTBASE" -o -name node_modules -o -name .git -o -name "*.app" -o -name Library -o -name .venv -o -name venv \) -prune \
  -o -type f -size -50000k -print 2>/dev/null > "$L"

while IFS= read -r f; do
  b=$(basename "$f" | tr '[:upper:]' '[:lower:]')
  case "$b" in
    bitwarden_export*|1passwordexport*|*.1pux|*.1pif|lastpass*export*|*passwords*.csv|*logins*.csv|keepass*export*.csv|dashlane*export*)
      hit export "Plaintext password export on disk" "$f"; continue;;
    *.csv)
      h=$(rd "$f" 2>/dev/null | head -1 | tr -d '"\r' | tr '[:upper:]' '[:lower:]')
      case "$h" in
        *url*user*pass*|*login_uri*|*user*pass*url*|*login_username*login_password*)
          hit export "Plaintext password export on disk" "$f"; continue;;
      esac;;
  esac
  case "$b" in
    *.p12|*.pfx|*.ppk|*.keystore|*.jks)
      hit key "Private key file outside ~/.ssh" "$f"; continue;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519|*.pem|*.key|*private*key*)
      if rd "$f" 2>/dev/null | head -1 | grep -q 'BEGIN .*PRIVATE KEY'; then hit key "Private key file outside ~/.ssh" "$f"; continue; fi;;
  esac
  case "$b" in
    .env.example|.env.sample|.env.template|.env.dist|*.env.example) ;;
    .env|.env.*|*.env)
      in_project "$f" || hit env ".env file outside a project" "$f"; continue;;
  esac
  case "$b" in
    *password*|*passwd*|*credentials*|*recovery*code*|*recovery*key*|*backup*code*|*seed*phrase*|*mnemonic*)
      hit name "Possible password file (by name)" "$f";;
  esac
done < "$L"
rm -f "$L"
