param([string]$Path)
$b = [System.IO.File]::ReadAllBytes($Path)
$c = @($b | Where-Object { $_ -eq 0xC3 }).Count
"$Path 0xC3=$c"
