# Scans lib/ for Dart files containing invalid-UTF8 / non-ASCII high bytes that
# can crash the analyzer's source reader (FormatException: Unexpected extension byte).
$root = "lib"
$bad = @()
Get-ChildItem -Path $root -Recurse -Filter *.dart | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $i = 0
    $n = $bytes.Length
    $invalid = $false
    while ($i -lt $n) {
        $b = $bytes[$i]
        if ($b -lt 0x80) { $i++; continue }
        # Determine UTF-8 sequence length
        if (($b -band 0xE0) -eq 0xC0) { $len = 2 }
        elseif (($b -band 0xF0) -eq 0xE0) { $len = 3 }
        elseif (($b -band 0xF8) -eq 0xF0) { $len = 4 }
        else { $invalid = $true; break }
        if ($i + $len -gt $n) { $invalid = $true; break }
        $ok = $true
        for ($k = 1; $k -lt $len; $k++) {
            if (($bytes[$i + $k] -band 0xC0) -ne 0x80) { $ok = $false; break }
        }
        if (-not $ok) { $invalid = $true; break }
        $i += $len
    }
    if ($invalid) {
        $bad += [PSCustomObject]@{ File = $_.FullName; Offset = $i; Byte = ("0x{0:X2}" -f $bytes[$i]) }
    }
}
if ($bad.Count -eq 0) {
    Write-Output "CLEAN: no invalid-UTF8 Dart files found under lib/"
} else {
    Write-Output ("FOUND " + $bad.Count + " invalid-UTF8 file(s):")
    $bad | ForEach-Object { Write-Output ("  " + $_.File + "  offset=" + $_.Offset + " byte=" + $_.Byte) }
}
