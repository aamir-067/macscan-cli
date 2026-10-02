rule MacTriage_JS_GlobalRequire_Loader
{
  meta:
    description = "Obfuscated JavaScript loader that exposes require/module globally (family seen injected into project repositories)"
    author = "mac-triage"
  strings:
    $g1 = /global\[_\$_[0-9a-f]{3,6}\[0x[0-9a-f]+\]\]\s*=\s*require/ ascii
    $g2 = "String.fromCharCode(127)" ascii
    $g3 = /typeof __filename\s*!==\s*_\$_[0-9a-f]{3,6}\[/ ascii
    $g4 = /var _\$jso[A-Za-z]+;/ ascii
  condition:
    filesize < 5MB and ($g1 or ($g2 and $g3) or ($g4 and $g2))
}

rule MacTriage_JS_StringShuffle_FunctionConstructor
{
  meta:
    description = "String-permutation decoder feeding the Function constructor, a common JS malware obfuscation"
    author = "mac-triage"
  strings:
    $s1 = /\.substr\(0,[a-zA-Z]{3}\);var [a-zA-Z]{3}='/ ascii
    $s2 = /var [a-zA-Z]{3}=[a-zA-Z]{3}\[[a-zA-Z]{3}\];/ ascii
    $s3 = /%\s*\d{6,7};?\};return [a-z]\.join\(''\)/ ascii
  condition:
    filesize < 5MB and 2 of them
}
