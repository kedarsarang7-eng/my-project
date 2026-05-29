$mods = @('book_store','clinic','clothing','computer_shop','decoration_catering','hardware','jewellery','mobile_shop','petrol_pump','pharmacy','restaurant','school_erp','vegetables_broker','academic_coaching','auto_parts')
foreach ($m in $mods) {
  $p = "g:\desktop app genuine\Dukan_x\lib\features\$m\presentation\screens"
  if (Test-Path $p) {
    Write-Output "=== $m (presentation/screens) ==="
    Get-ChildItem $p -Filter '*.dart' | Select-Object -ExpandProperty Name | ForEach-Object { Write-Output "  $_" }
  }
  $p2 = "g:\desktop app genuine\Dukan_x\lib\features\$m\screens"
  if (Test-Path $p2) {
    Write-Output "=== $m (screens) ==="
    Get-ChildItem $p2 -Filter '*.dart' | Select-Object -ExpandProperty Name | ForEach-Object { Write-Output "  $_" }
  }
}
