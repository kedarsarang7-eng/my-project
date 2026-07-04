# Merges the missing staff-module localization keys into each locale ARB file.
# Reads flat JSON files from tool/staff_l10n/<locale>.json and appends any
# keys that are not already present in lib/l10n/app_<locale>.arb.
# Preserves existing content and writes UTF-8 (no BOM). Idempotent.

$ErrorActionPreference = 'Stop'
$root      = Split-Path $PSScriptRoot -Parent
$arbDir    = Join-Path $root 'lib\l10n'
$transDir  = Join-Path $PSScriptRoot 'staff_l10n'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Canonical key order taken from the English template.
$enPath = Join-Path $arbDir 'app_en.arb'
$en     = Get-Content $enPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enKeys = $en.PSObject.Properties.Name | Where-Object { $_ -notlike '@*' }

foreach ($tf in Get-ChildItem $transDir -Filter '*.json') {
  $locale  = [System.IO.Path]::GetFileNameWithoutExtension($tf.Name)
  $arbPath = Join-Path $arbDir "app_$locale.arb"
  if (-not (Test-Path $arbPath)) { Write-Warning "No ARB for $locale"; continue }

  $arb   = Get-Content $arbPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $trans = Get-Content $tf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

  $existing = $arb.PSObject.Properties.Name
  $toAdd    = @()
  foreach ($k in ($enKeys | Where-Object { $_ -in $trans.PSObject.Properties.Name })) {
    if ($k -notin $existing) {
      $val  = ([string]$trans.$k).Replace('\', '\\').Replace('"', '\"')
      $toAdd += ('  "{0}": "{1}"' -f $k, $val)
    }
  }
  if ($toAdd.Count -eq 0) { Write-Output "${locale}: nothing to add"; continue }

  # Insert before the final closing brace, ensuring a trailing comma on the
  # previous last property.
  $raw = (Get-Content $arbPath -Raw -Encoding UTF8).TrimEnd()
  $lastBrace = $raw.LastIndexOf('}')
  $head = $raw.Substring(0, $lastBrace).TrimEnd()
  if (-not $head.EndsWith(',')) { $head = $head + ',' }
  $newContent = $head + "`n" + ($toAdd -join ",`n") + "`n}`n"

  [System.IO.File]::WriteAllText($arbPath, $newContent, $utf8NoBom)
  Write-Output "${locale}: added $($toAdd.Count) keys"
}
