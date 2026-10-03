#!/usr/bin/env bats
# macscan --update: release lookup, verified download, refusal on tampering.

load ../helpers

setup(){
  make_env
  # shellcheck source=/dev/null
  source "$SRC/macscan"
  VERSION=2.3.0
  REL="$TEST_TMP/releases"; mkdir -p "$REL/download/v9.9.9"
  printf '{"tag_name":"v9.9.9","name":"x"}' > "$REL/latest.json"
  printf '#!/bin/bash\n[ "$1" = --version ] && echo "mac-triage installer 9.9.9"\n' > "$REL/download/v9.9.9/install-mac-triage.sh"
  (cd "$REL/download/v9.9.9" && shasum -a 256 install-mac-triage.sh > SHA256SUMS)
  MT_API="file://$REL/latest.json"; MT_DL="file://$REL/download"
  OUT="$TEST_TMP/dl"; mkdir -p "$OUT"
}
teardown(){ drop_env; }

@test "the latest release version is read from GitHub's answer" {
  [ "$(latest_version)" = 9.9.9 ]
}

@test "garbage or an unreachable server gives no version" {
  printf 'not json' > "$REL/latest.json"; [ -z "$(latest_version)" ]
  MT_API="file://$TEST_TMP/missing"; [ -z "$(latest_version)" ]
}

@test "--update --check reports an available update without installing" {
  run update --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update available: 2.3.0 -> 9.9.9"* && "$output" == *"macscan --update"* ]] || return 1
}

@test "--update says up to date when there is nothing newer" {
  VERSION=9.9.9
  run update --check
  [[ "$output" == *"is up to date"* ]] || return 1
}

@test "a verified download passes" {
  run download_release 9.9.9 "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHA-256 matches"* ]] || return 1
}

@test "a tampered installer is refused" {
  echo "echo pwned" >> "$REL/download/v9.9.9/install-mac-triage.sh"
  run download_release 9.9.9 "$OUT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum verification FAILED"* ]] || return 1
}

@test "an installer claiming another version is refused" {
  printf '#!/bin/bash\necho "mac-triage installer 1.0.0"\n' > "$REL/download/v9.9.9/install-mac-triage.sh"
  (cd "$REL/download/v9.9.9" && shasum -a 256 install-mac-triage.sh > SHA256SUMS)
  run download_release 9.9.9 "$OUT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not version 9.9.9"* ]] || return 1
}
