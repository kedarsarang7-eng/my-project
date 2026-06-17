$routes = Import-Csv "g:\desktop app genuine\route_results.csv"
Write-Output "Parsed $($routes.Count) routes. Showing first 15:"
$routes | Select-Object -First 15 | Format-Table -AutoSize
