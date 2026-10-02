#!/usr/bin/env bats
# Download origin classification (P1-3).

load ../helpers

setup(){ make_env; load_common; }
teardown(){ drop_env; }

@test "origins are classified by host" {
  [ "$(origin_category 'https://cdn.discordapp.com/attachments/1/2/Setup.dmg')" = chat ]
  [ "$(origin_category 'https://bit.ly/3abc')" = shortener ]
  [ "$(origin_category 'https://www.dropbox.com/s/x/app.zip?dl=1')" = fileshare ]
  [ "$(origin_category 'https://mega.nz/file/abc')" = fileshare ]
  [ "$(origin_category 'https://github.com/someone/tool/releases/download/v1/tool.dmg')" = github-release ]
  [ "$(origin_category 'https://objects.githubusercontent.com/github-production-release-asset/x')" = github-release ]
  [ "$(origin_category 'https://evil-notch.pages.dev/download')" = hosting ]
  [ "$(origin_category 'HTTPS://USER@T.CO:443/x')" = shortener ]
}

@test "ordinary vendor sites are not classified" {
  [ -z "$(origin_category 'https://www.google.com/chrome/')" ]
  [ -z "$(origin_category 'https://github.com/someone/tool')" ]
  [ -z "$(origin_category 'https://dl.example.com/app.dmg')" ]
}

@test "exec_like recognizes installers, archives and executables" {
  exec_like "$UH/Downloads/Notch.dmg"; exec_like "$UH/Downloads/x.PKG"; exec_like "$UH/Downloads/run.command"
  touch "$UH/plain"; chmod +x "$UH/plain"; exec_like "$UH/plain"
  not exec_like "$UH/Downloads/photo.jpg"
}

@test "origin_check flags a dmg from a Discord attachment and names the repo for GitHub releases" {
  origin_check "$UH/Downloads/NotchApp.dmg" "https://cdn.discordapp.com/attachments/1/2/NotchApp.dmg" "https://discord.com/channels/1"
  origin_check "$UH/Downloads/tool.zip" "https://github.com/someone/tool/releases/download/v1/tool.zip"
  origin_check "$UH/Downloads/photo.jpg" "https://cdn.discordapp.com/attachments/1/2/photo.jpg"
  grep -qxF "[test] Downloaded executable from a chat attachment: $UH/Downloads/NotchApp.dmg <- https://cdn.discordapp.com/attachments/1/2/NotchApp.dmg" "$RUN/.flags.raw"
  grep -qF "GitHub release (verify the repository someone/tool): $UH/Downloads/tool.zip" "$RUN/.flags.raw"
  [ "$(grep -c . "$RUN/.flags.raw")" = 2 ]
}
