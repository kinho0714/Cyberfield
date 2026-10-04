# Rebuild native Godot Translation resources from the central catalog.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot 'assets/localization/ui_catalog.json') | ConvertFrom-Json
$ptOverrides = @{ COMMON='COMUM'; UNCOMMON='INCOMUM'; RARE='RARO'; MELEE='CORPO A CORPO'; RANGED='À DISTÂNCIA' }
foreach ($locale in @('pt_BR','en')) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('[gd_resource type="Translation" format=3]')
    $lines.Add('')
    $lines.Add('[resource]')
    $lines.Add('locale = "' + $locale + '"')
    $lines.Add('messages = {')
    $pairs = @($catalog.PSObject.Properties | Sort-Object Name | ForEach-Object {
        $key = $_.Name
        $value = if ($locale -eq 'en') { $_.Value } elseif ($ptOverrides.ContainsKey($key)) { $ptOverrides[$key] } else { $key }
        ($key | ConvertTo-Json -Compress) + ': ' + ($value | ConvertTo-Json -Compress)
    })
    $lines.Add(($pairs -join ",`n"))
    $lines.Add('}')
    [IO.File]::WriteAllText((Join-Path $projectRoot "assets/localization/ui.$locale.tres"), ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}
