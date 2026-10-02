# shellcheck shell=bash
# Text filters for anything that came from the scanned system (file names, app names,
# config lines, log lines). That text can be written by an attacker.

# sanitize: makes control characters visible instead of letting a terminal act on them
# (ANSI escapes can rewrite or hide lines), and marks Unicode direction overrides that
# can make a file name read differently than it is. Tabs and newlines are kept.
sanitize(){ LC_ALL=C perl -pe '
  s/\r$//;
  s/([\x00-\x08\x0B-\x1F\x7F])/sprintf("<0x%02X>",ord($1))/ge;
  s/\xC2([\x80-\x9F])/sprintf("<U+%04X>",ord($1))/ge;
  s/\xE2\x80([\x8E\x8F\xAA-\xAE])/sprintf("<U+%04X>",0x2000+ord($1)-0x80)/ge;
  s/\xE2\x81([\xA6-\xA9])/sprintf("<U+%04X>",0x2040+ord($1)-0x80)/ge;
'; }

# one_line: sanitize and join into a single line (for history and notifications).
one_line(){ tr '\n' ' ' | sanitize | sed 's/ *$//'; }
