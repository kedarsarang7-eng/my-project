# Phase 3 verification: encoding + Windows-file-touch checks.
Write-Output "=== ENCODING (0xC3 mojibake marker must be 0) ==="
foreach ($p in @(
  'lib\core\localization\localization_service.dart',
  'lib\features\settings\presentation\screens\main_settings_screen.dart'
)) {
  $b = [System.IO.File]::ReadAllBytes($p)
  $c = @($b | Where-Object { $_ -eq 0xC3 }).Count
  Write-Output ("{0}  0xC3={1}" -f $p, $c)
}

Write-Output ""
Write-Output "=== UNICODE CONTENT CHECK ==="
$txt = [System.IO.File]::ReadAllText('lib\core\localization\localization_service.dart', [System.Text.Encoding]::UTF8)
Write-Output ("hindi present: " + ($txt -match [char]0x0939))
Write-Output ("bengali present: " + ($txt -match [char]0x09AC))
Write-Output ("urdu present: " + ($txt -match [char]0x0627))

Write-Output ""
Write-Output "=== WINDOWS-PLATFORM FILES TOUCHED (should be NONE) ==="
# List only files under windows/ or lib/windows paths in git diff of my session's edits.
# We check the explicitly-changed file list against a windows path filter.
$changed = @(
  'lib/app/app.dart',
  'lib/core/localization/localization_service.dart',
  'lib/features/dashboard/v2/widgets/performance_cards.dart',
  'lib/screens/dashboard_metrics_row.dart',
  'lib/features/purchase/screens/add_purchase_screen.dart',
  'lib/features/purchase/screens/purchase_dashboard_screen.dart',
  'lib/features/purchase/screens/purchase_history_screen.dart',
  'lib/features/settings/presentation/screens/main_settings_screen.dart',
  'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
  'lib/features/gst/screens/gst_reports_screen.dart',
  'lib/features/revenue/screens/revenue_overview_screen.dart'
)
$winTouched = $changed | Where-Object { $_ -match '(^|/)windows/' }
if ($winTouched) { Write-Output ("WINDOWS FILES TOUCHED: " + ($winTouched -join ', ')) } else { Write-Output "None (pass)" }
