#!/usr/bin/env bats
# redact() must mask secrets and leave normal text alone.
# Fake tokens are assembled at runtime so no secret-shaped string sits in the repo.

load ../helpers

setup(){ make_env; load_common; }
teardown(){ drop_env; }

rep(){ printf "%0${2}d" 0 | tr 0 "$1"; }   # rep CHAR N

@test "normal text is unchanged" {
  run bash -c 'source "$1/core/common.sh"; printf "%s\n" "Launch item: /Library/LaunchDaemons/x.plist | team=ABCDE12345" | redact' _ "$SRC"
  [ "$output" = "Launch item: /Library/LaunchDaemons/x.plist | team=ABCDE12345" ]
}

@test "GitHub, OpenAI, AWS, Google, Slack and npm tokens are masked" {
  for t in "gh""p_$(rep a 36)" "github_""pat_$(rep b 30)" "sk-$(rep c 40)" "AK""IA$(rep D 16)" "AI""za$(rep e 35)" "xox""b-$(rep 1 20)" "npm_$(rep f 36)"; do
    out=$(printf 'token here %s end\n' "$t" | redact)
    [[ "$out" != *"$t"* ]] || { echo "not masked: $t -> $out"; return 1; }
    [[ "$out" == *"<redacted>"* ]]
  done
}

@test "JWTs are masked" {
  jwt="ey""J$(rep a 20).$(rep b 20).$(rep c 20)"
  out=$(echo "Authorization header $jwt" | redact)
  [[ "$out" != *"$jwt"* ]]
}

@test "KEY=value style secrets are masked, the key name is kept" {
  out=$(printf 'export OPENAI_API_KEY=abc123secret\nDB_PASSWORD: hunter2\n' | redact)
  [[ "$out" == *"OPENAI_API_KEY=<redacted>"* ]]
  [[ "$out" == *"DB_PASSWORD: <redacted>"* ]]
  [[ "$out" != *hunter2* && "$out" != *abc123secret* ]]
}

@test "credentials inside URLs are masked" {
  out=$(echo "remote https://user:s3cr3tpass@github.com/x/y.git" | redact)
  [[ "$out" == *"https://user:<redacted>@github.com/x/y.git"* ]]
}

@test "private key blocks are masked" {
  out=$(printf '%s\n' "-----BEGIN OPENSSH PRIVATE KEY-----" | redact)
  [ "$out" = "<redacted private key>" ]
}
