$results = Import-Csv "g:\desktop app genuine\endpoint_results.csv"
$unmapped = $results | Where-Object { $_.Status -eq "No serverless handler mapping" }
Write-Output "Found $($unmapped.Count) unmapped endpoints:"
$unmapped | Select-Object Method, Path, OperationId | Format-Table -AutoSize
