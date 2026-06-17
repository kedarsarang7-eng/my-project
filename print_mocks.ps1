$results = Import-Csv "g:\desktop app genuine\audit_results.csv"
$mocks = $results | Where-Object { $_.MockData -eq "True" }
Write-Output "Found $($mocks.Count) screens with mock data:"
$mocks | Select-Object Project, FileName, MockReasons, BusinessTypes | Format-Table -AutoSize
