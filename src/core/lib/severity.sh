# shellcheck shell=bash
# Severity rubric. Each flag message is matched by prefix; the first rule wins.
# Flag text itself never changes, so known-flag substring matching keeps working.
#
#   critical  confirmed indicators, root-level persistence tricks, tampering with the tool
#   high      unsigned or hidden auto-start code, risky permissions, policy or trust changes
#   medium    unknown but plausible items worth a look, coverage gaps
#   low       hygiene

SEVERITY_RULES='critical	Injected malware marker found:
critical	File name used by known Mac stealers present:
critical	Extra account with UID 0:
critical	Authorization plugin installed
critical	Launch item runs from an unusual location:
critical	Unexpected process has a sensitive file open:
critical	Install integrity check failed:
critical	Unexpected file in install folder:
critical	Install file not owned by root or writable by others:
critical	Service definition changed:
high	YARA match:
high	ClamAV detection:
high	System Integrity Protection is not enabled
high	Gatekeeper is disabled
high	Unexpected admin account:
high	User account record created recently:
high	Passwordless sudo rule:
high	Custom sudoers file present:
high	PAM config loads a non-system module:
high	Auto-login password file
high	App rejected by Gatekeeper
high	High-risk permission granted recently:
high	Unpacked (sideloaded) extension in
high	Unsigned Firefox add-on:
high	Browser policy file present:
high	Browser policies.json present:
high	Chrome has force-installed extensions configured
high	Browser with extension loading or remote debugging flag:
high	Admin-trusted custom certificates exist
high	User-trusted custom certificates exist
high	A system proxy or PAC file is enabled
high	Suspicious command in
high	Shell overrides a sensitive command in
high	Sensitive command shadowed in PATH:
high	/etc/zshenv exists
high	DYLD variable in launch item:
high	launchd has
high	Process started with DYLD_INSERT_LIBRARIES:
high	Hidden launch item file:
high	Process running from a temp or shared folder:
high	Process running from a hidden folder in home:
high	Task auto-runs on folder open:
high	Config file with an abnormally long line:
high	SUID/SGID file outside system paths:
high	crontab exists for
high	/etc/crontab has entries
high	at jobs are queued
high	Legacy startup file exists:
high	LoginHook is set:
high	LogoutHook is set:
high	Remote access or tunnel process running:
high	Apple Remote Desktop agent is running
high	Program started during the scan from an unusual location:
high	Downloaded executable from a chat attachment:
high	Downloaded executable from a link shortener:
medium	Unsigned, ad-hoc or invalid signature:
medium	Launch item runs an interpreter directly:
medium	Launch item created in the last
medium	Non-Apple kernel extension loaded:
medium	Configuration profile installed
medium	Remote Login (SSH server) is ON
medium	Screen Sharing is enabled
medium	authorized_keys file exists on this Mac:
medium	Remote access or tunnel tool present:
medium	osascript is running:
medium	Repo git config can execute commands:
medium	Git setting that can run commands
medium	SSH config can run commands
medium	Non-default package registry configured:
medium	Installer or social/file-share download
medium	Downloaded executable from
medium	Custom hosts file entry:
medium	FileVault is off
medium	Scanner had no Full Disk Access
medium	Plaintext password export on disk:
medium	Private key file outside ~/.ssh:
medium	Possible password file (by name):
medium	.env file outside a project:
medium	Known-vulnerable dependencies in repository:
medium	Possible secret committed in repository:
medium	Unsigned program started during the scan:
low	Application firewall is off
low	Listener reachable from the network:
low	Permission belongs to an app no longer on disk:
low	Third-party Homebrew tap
low	File in ~/.ssh may be a private key:
low	No compiled YARA rules
low	ClamAV has no signature database
low	Could not locate any privacy (TCC) database'

# Inventory categories whose new items are high severity; other new items are medium.
SEVERITY_NEW_HIGH=' launch jobs btm kext sysext authplugin sudoers pam profiles cron users admins remote certs native_hosts browser_policy hooks mcp '

# classify_flags <flags file> [acknowledged file]
# Prints "rank<TAB>severity<TAB>acknowledged 0|1<TAB>ack note<TAB>flag line" per line.
# The acknowledged file has "date<TAB>substring<TAB>reason" lines (macscan --ignore).
classify_flags(){
  # BSD awk refuses newlines in -v values, so the rules travel in the environment.
  MT_SEV_RULES="$SEVERITY_RULES" MT_SEV_NEW="$SEVERITY_NEW_HIGH" awk -F'\t' '
    BEGIN {
      rules = ENVIRON["MT_SEV_RULES"]; newhigh = ENVIRON["MT_SEV_NEW"]
      n = split(rules, r, "\n")
      for (i = 1; i <= n; i++) { split(r[i], p, "\t"); sev[i] = p[1]; pre[i] = p[2] }
      rank["critical"] = 1; rank["high"] = 2; rank["medium"] = 3; rank["low"] = 4
      na = 0
    }
    FILENAME == ackfile { if (NF >= 3 && $2 != "") { na++; apat[na] = $2; anote[na] = $3 " (since " $1 ")" } next }
    NF == 0 { next }
    {
      line = $0; s = ""
      if (index(line, "[new since last scan] [") == 1) {
        cat = substr(line, 24); cat = substr(cat, 1, index(cat, "]") - 1)
        s = (index(newhigh, " " cat " ") ? "high" : "medium")
      } else {
        msg = line; if (substr(msg, 1, 1) == "[") msg = substr(msg, index(msg, "] ") + 2)
        for (i = 1; i <= n; i++) if (index(msg, pre[i]) == 1) { s = sev[i]; break }
        if (s == "") s = "medium"
      }
      ack = 0; note = ""
      for (i = 1; i <= na; i++) if (index(line, apat[i])) { ack = 1; note = anote[i]; break }
      printf "%d\t%s\t%d\t%s\t%s\n", rank[s], s, ack, note, line
    }' ackfile="${2:-/dev/null}" "${2:-/dev/null}" "$1"
}
