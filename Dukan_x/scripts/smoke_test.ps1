# Smoke test script for Veg Billing app
# - Runs dependency fetch
# - Runs analyzer
# - Optionally attempts a quick run on an available device (user confirms)

Write-Host "Running smoke tests..."

cd "$PSScriptRoot/.."

Write-Host "1) Running flutter pub get"
flutter pub get

Write-Host "2) Running flutter analyze"
flutter analyze

# If a device is available, we can attempt a short run (optional)
$devices = flutter devices --machine | Out-String
if ($devices -and $devices -notmatch 'No devices') {
    Write-Host "Devices available. To run the app on first device for 10s, uncomment the lines below and run this script with elevated permissions."
    # Example (commented):
    # Start-Process flutter -ArgumentList 'run -d <deviceId> --verbose' -NoNewWindow
    # Start-Sleep -Seconds 10
    # Stop-Process -Name flutter -ErrorAction SilentlyContinue
} else {
    Write-Host "No devices available or running in CI; skipping run step."
}

Write-Host "Smoke tests completed. Review analyzer output above for issues."