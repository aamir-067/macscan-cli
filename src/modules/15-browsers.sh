#!/bin/bash
# @title  Browser extensions, policies and saved-credential counts
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Chromium-based browser extensions (found automatically)"
chromium_ext_dirs | while IFS= read -r ed; do
  pd=$(dirname "$ed"); br=$(dirname "$pd"); bname=${br#"$AS"/}; prof=$(basename "$pd")
  sub "$bname | $prof"
  for m in "$ed"/*/*/manifest.json; do
    [ -f "$m" ] || continue
    # shellcheck disable=SC2094  # the path is only passed as a name; the file is read once
    line=$(perl -MJSON::PP -e '
      local $/; my $j=eval{decode_json(<STDIN>)} or exit;
      my $path=$ARGV[0]; my ($id,$ver)=$path=~m{/Extensions/([^/]+)/([^/]+)/manifest\.json$};
      my $n=$j->{name}//"";
      if($n=~/^__MSG_(\w+)__$/){ my $key=lc $1; (my $dir=$path)=~s{/manifest\.json$}{}; my $loc=$j->{default_locale}//"en";
        if(open my $fh,"<","$dir/_locales/$loc/messages.json"){ my $mj=eval{decode_json(do{local $/; <$fh>})}; if($mj){ for(keys %$mj){ $n=$mj->{$_}{message} if lc($_) eq $key } } } }
      my @p=(@{$j->{permissions}||[]}, @{$j->{host_permissions}||[]}, @{$j->{optional_permissions}||[]});
      my $risk=join(",", grep { !ref($_) && /^(<all_urls>|cookies|nativeMessaging|debugger|webRequest|webRequestBlocking|proxy|management|clipboardRead|history|scripting|\*:\/\/\*\/\*|https?:\/\/\*\/\*)$/ } @p);
      print "$id | $n | v$ver | risky permissions: ".($risk||"none")."\n";' "$m" < "$m")
    [ -z "$line" ] && continue
    echo "$line"
    inv browser_ext "$bname | $prof | $(echo "$line" | awk -F' [|] ' '{print $1" | "$2}')"
  done
  for pf in "$pd/Secure Preferences" "$pd/Preferences"; do
    [ -f "$pf" ] || continue
    perl -MJSON::PP -e 'local $/; my $j=eval{decode_json(<STDIN>)} or exit; my $s=$j->{extensions}{settings}||{}; for my $id (keys %$s){ my $e=$s->{$id}; next unless ref $e eq "HASH"; print "UNPACKED $id path=".($e->{path}//"")."\n" if ($e->{location}//0)==4 }' < "$pf"
  done | sort -u | while read -r l; do echo "$l"; flag "Unpacked (sideloaded) extension in $bname $prof: $l"; done
done

section "Firefox-family add-ons (found automatically)"
firefox_ext_files | while IFS= read -r ej; do
  prof=$(basename "$(dirname "$ej")"); sub "$prof"
  perl -MJSON::PP -e 'local $/; my $j=eval{decode_json(<STDIN>)} or exit; for (@{$j->{addons}||[]}) { next if ($_->{location}//"") =~ /app-builtin|app-system/; my $up=$_->{userPermissions}||{}; my $o=join(",", @{$up->{origins}||[]}); my $p=join(",", @{$up->{permissions}||[]}); my $ss=defined $_->{signedState} ? $_->{signedState} : "?"; print "$_->{id} | ".($_->{defaultLocale}{name}//"")." | v$_->{version} | active=".($_->{active}?1:0)." | signed=$ss | perms=$p | origins=$o\n" }' < "$ej" | while IFS= read -r l; do
    echo "$l"; inv browser_ext "firefox | $prof | $(echo "$l" | awk -F' [|] ' '{print $1" | "$2}')"
    case "$l" in *"signed=0"*|*"signed=-"*) flag "Unsigned Firefox add-on: $l";; esac
  done
done

section "Safari extensions"
asuser pluginkit -mAvv -p com.apple.Safari.web-extension 2>/dev/null | head -60

section "Native messaging hosts (programs a browser extension can launch)"
find "$AS" "/Library/Application Support" /Library/Google /Library/Microsoft -maxdepth 4 -type d -name NativeMessagingHosts 2>/dev/null | while IFS= read -r d; do
  for j in "$d"/*.json; do
    [ -f "$j" ] || continue
    p=$(perl -MJSON::PP -e 'local $/; my $x=eval{decode_json(<STDIN>)}; print $x->{path} if $x' < "$j")
    echo "$j -> $p"; inv native_hosts "$j -> $p"
    [ -n "$p" ] && [ -e "$p" ] && { printf "   "; sigf "$p"; }
  done
done

section "Browser policies (force-installed extensions, managed settings)"
for d in com.google.Chrome com.brave.Browser com.microsoft.Edge org.mozilla.firefox; do
  for f in "/Library/Managed Preferences/$d.plist" "/Library/Managed Preferences/$U/$d.plist" "/Library/Preferences/$d.plist"; do
    [ -f "$f" ] && { echo "[$f]"; plutil -p "$f"; inv browser_policy "$f $(sha "$f")"; flag "Browser policy file present: $f"; }
  done
done
asuser defaults read com.google.Chrome ExtensionInstallForcelist 2>/dev/null && flag "Chrome has force-installed extensions configured"
for pj in /Applications/*.app/Contents/Resources/distribution/policies.json; do [ -f "$pj" ] && { rd "$pj"; flag "Browser policies.json present: $pj"; }; done

section "Saved passwords and cards per browser profile (counts only, no contents)"
chromium_ext_dirs | while IFS= read -r ed; do
  pd=$(dirname "$ed"); ld="$pd/Login Data"; [ -f "$ld" ] || continue
  T=$(tmpf)
  cp "$ld" "$T" 2>/dev/null; n=$(sql "$T" "select count(*) from logins" 2>/dev/null)
  c=""; [ -f "$pd/Web Data" ] && { cp "$pd/Web Data" "$T" 2>/dev/null; c=$(sql "$T" "select count(*) from credit_cards" 2>/dev/null); }
  rm -f "$T"
  echo "${pd#"$AS"/} | saved logins: ${n:-?} | saved cards: ${c:-?}"
done
firefox_ext_files | while IFS= read -r ej; do
  lj="$(dirname "$ej")/logins.json"
  [ -f "$lj" ] && echo "$(basename "$(dirname "$ej")") | saved logins: $(perl -MJSON::PP -e 'local $/; my $j=eval{decode_json(<STDIN>)}; print scalar @{$j->{logins}||[]} if $j' < "$lj")"
done
