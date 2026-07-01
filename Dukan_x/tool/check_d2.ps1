$src = Get-Content -Raw 'g:\desktop app genuine\Dukan_x\lib\features\academic_coaching\presentation\screens\ac_batches_screen.dart'
"Length: $($src.Length)"
"Has 'TODO'? $($src.Contains('TODO'))"
$matches = [regex]::Matches($src, '//\s*TODO\b')
"Regex matches: $($matches.Count)"
foreach ($m in $matches) {
  "Match at $($m.Index): $($m.Value)"
}
