$lines = Get-Content "g:\desktop app genuine\Dukan_x\analyze_wide.txt" -Encoding utf8 | Where-Object { $_ -match '(error|warning|info)\s+-\s+' }

# Rule code frequency
$ruleCounts = @{}
$fileCounts = @{}
$severityCounts = @{ 'error' = 0; 'warning' = 0; 'info' = 0 }

foreach ($l in $lines) {
    # Extract severity
    if ($l -match '^\s+(error|warning|info)\s') {
        $sev = $matches[1]
        if ($severityCounts.ContainsKey($sev)) {
            $severityCounts[$sev] = $severityCounts[$sev] + 1
        }
    }
    
    # Extract rule code (last word after final " - ")
    if ($l -match '-\s+(\S+)\s*$') {
        $rule = $matches[1]
        if ($ruleCounts.ContainsKey($rule)) {
            $ruleCounts[$rule] = $ruleCounts[$rule] + 1
        } else {
            $ruleCounts[$rule] = 1
        }
    }
    
    # Extract file path
    if ($l -match '-\s+(.+?:\d+:\d+)\s+-\s+') {
        $fullPath = $matches[1].Trim()
        $file = ($fullPath -split ':\d+:\d+$')[0]
        if ($fileCounts.ContainsKey($file)) {
            $fileCounts[$file] = $fileCounts[$file] + 1
        } else {
            $fileCounts[$file] = 1
        }
    }
}

Write-Host "=== SEVERITY BREAKDOWN ==="
$severityCounts.GetEnumerator() | Sort-Object Value -Descending | Format-Table Name, Value -AutoSize

Write-Host "`n=== TOP 20 RULE CODES ==="
$ruleCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | Format-Table Name, Value -AutoSize

Write-Host "`n=== TOP 15 FILES BY ISSUE COUNT ==="
$fileCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | Format-Table Name, Value -AutoSize

# Also categorize by bucket
Write-Host "`n=== BUCKET CLASSIFICATION ==="
$bucketA = @('uri_does_not_exist', 'undefined_identifier', 'undefined_method', 'undefined_getter', 'undefined_setter', 'undefined_named_parameter', 'missing_required_argument', 'argument_type_not_assignable', 'return_of_invalid_type', 'invalid_override', 'type_argument_not_matching_bounds', 'wrong_number_of_type_arguments', 'undefined_class', 'mixin_of_non_class', 'undefined_function', 'unchecked_use_of_nullable_value', 'not_enough_positional_arguments', 'extra_positional_arguments', 'body_might_complete_normally', 'dead_code', 'missing_default_value_for_parameter', 'invalid_assignment', 'const_with_non_const', 'creation_of_struct_or_union', 'non_abstract_class_inherits_abstract_member', 'must_be_immutable', 'override_on_non_overriding_member')
$bucketB = @('unused_import', 'unused_local_variable', 'unused_field', 'unused_element', 'unused_element_parameter', 'deprecated_member_use', 'deprecated_member_use_from_same_package', 'unawaited_futures', 'discarded_futures', 'invalid_use_of_protected_member', 'invalid_use_of_visible_for_testing_member', 'unnecessary_import')
$bucketC = @('prefer_const_constructors', 'prefer_const_literals_to_create_immutables', 'prefer_const_declarations', 'avoid_print', 'annotate_overrides', 'unnecessary_null_comparison', 'prefer_final_locals', 'prefer_final_fields', 'unnecessary_this', 'unnecessary_new', 'prefer_is_empty', 'prefer_is_not_empty', 'unnecessary_cast', 'avoid_unnecessary_containers')
$bucketD = @('depend_on_referenced_packages', 'unnecessary_underscores', 'use_null_aware_elements', 'library_private_types_in_public_api', 'no_leading_underscores_for_local_identifiers', 'asset_directory_does_not_exist', 'asset_does_not_exist')

$bA = 0; $bB = 0; $bC = 0; $bD = 0; $bUncat = 0
foreach ($entry in $ruleCounts.GetEnumerator()) {
    $r = $entry.Name
    $c = $entry.Value
    if ($bucketA -contains $r) { $bA += $c }
    elseif ($bucketB -contains $r) { $bB += $c }
    elseif ($bucketC -contains $r) { $bC += $c }
    elseif ($bucketD -contains $r) { $bD += $c }
    else { $bUncat += $c; Write-Host "  Uncategorized: $r ($c)" }
}

Write-Host "Bucket A (Critical Errors): $bA"
Write-Host "Bucket B (High-Impact Warnings): $bB"
Write-Host "Bucket C (Architecture/Quality): $bC"
Write-Host "Bucket D (Style/Informational): $bD"
Write-Host "Uncategorized: $bUncat"
