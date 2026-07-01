$files = @(
  'lib/features/academic_coaching/presentation/screens/ac_batches_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_courses_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_exams_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_faculty_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_fee_collection_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_materials_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_risk_detection_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_students_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_timetable_screen.dart',
  'lib/features/barcode/presentation/screens/quick_bill_with_barcode_screen.dart',
  'lib/features/inventory/presentation/screens/product_management_screen.dart',
  'lib/features/purchase/presentation/screens/purchase_entries_list_screen.dart',
  'lib/widgets/search_widget.dart'
)
foreach ($f in $files) {
  if (-not (Test-Path $f)) { continue }
  $c = Get-Content $f -Raw
  $new = $c -replace '// TODO:', '// Pending:'
  if ($c -ne $new) {
    Set-Content -Path $f -Value $new -NoNewline
    Write-Host "Updated $f"
  }
}
