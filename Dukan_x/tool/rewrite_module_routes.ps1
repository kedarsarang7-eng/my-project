# Rewrite each lib/modules/<m>/routes/*_routes.dart so its GoRoute entries
# delegate to LegacyRouteRedirect instead of ModulePlaceholderScreen. This
# keeps the existing route paths working through the legacy named-route
# map while the GoRouter migration is pending.

$files = Get-ChildItem -Path 'lib/modules' -Recurse -Filter '*_routes.dart'

foreach ($f in $files) {
  $src = Get-Content $f.FullName -Raw
  if (-not ($src -match 'ModulePlaceholderScreen')) { continue }

  # Replace import.
  $src = $src -replace
    "import '../../../core/module/module_placeholder_screen.dart';",
    "import '../../../core/module/legacy_route_redirect.dart';"

  # Replace builder body. Pattern: ModulePlaceholderScreen(title: 'X', icon: Y)
  # Capture the path from the surrounding GoRoute and reuse it as legacyRoute.
  $src = [System.Text.RegularExpressions.Regex]::Replace(
    $src,
    "GoRoute\(\s*path:\s*'([^']+)'\s*,\s*builder:\s*\(_,\s*_\)\s*=>\s*const\s+ModulePlaceholderScreen\(\s*title:\s*'([^']+)'\s*,\s*icon:\s*([^)]+)\),?\s*\)",
    {
      param($m)
      $path = $m.Groups[1].Value
      $title = $m.Groups[2].Value
      $icon = $m.Groups[3].Value.Trim()
      "GoRoute(path: '$path', builder: (_, _) => const LegacyRouteRedirect(legacyRoute: '$path', title: '$title', icon: $icon))"
    }
  )

  Set-Content -Path $f.FullName -Value $src -NoNewline
  Write-Host "Updated $($f.FullName)"
}
