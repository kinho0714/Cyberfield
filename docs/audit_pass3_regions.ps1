# Audit actual runtime rectangles without modifying images. Run from project root.
Add-Type -AssemblyName System.Drawing
$assetPaths = @{
    STRUCTURE='assets/environment/casa_jhon/assets/structural/casa_jhon_structural_base_stage0_v1.png'
    DOMESTIC='assets/environment/casa_jhon/assets/props/casa_jhon_props_domestic_stage0_v1.png'
    WORKSHOP='assets/environment/casa_jhon/assets/props/casa_jhon_props_workshop_stage0_v1.png'
    CITY_STRUCTURE='assets/environment/cidade_baixa/structural/structural/cidade_baixa_structural_tileset_v1.png'
    CITY_PROPS='assets/environment/cidade_baixa/props/cidade_baixa_props_v1.png'
    CITY_GAMEPLAY='assets/environment/cidade_baixa/gameplay/cidade_baixa_gameplay_interactives_v1.png'
}
$regions = @()
$house = [IO.File]::ReadAllText((Join-Path (Get-Location) 'scene/casa_jhon_presentation.gd'))
foreach ($match in [regex]::Matches($house, '_prop\((STRUCTURE|DOMESTIC|WORKSHOP), Rect2\((\d+), (\d+), (\d+), (\d+)\)')) {
    $regions += [PSCustomObject]@{atlas=$match.Groups[1].Value;x=[int]$match.Groups[2].Value;y=[int]$match.Groups[3].Value;width=[int]$match.Groups[4].Value;height=[int]$match.Groups[5].Value;class='B';purpose='house_prop'}
}
foreach ($rect in @(@(0,0,51,61),@(107,0,50,61),@(218,0,69,24))) {
    $regions += [PSCustomObject]@{atlas='STRUCTURE';x=$rect[0];y=$rect[1];width=$rect[2];height=$rect[3];class='A';purpose='house_tile'}
}
$regions += [PSCustomObject]@{atlas='STRUCTURE';x=258;y=69;width=12;height=70;class='B';purpose='house_column'}
$city = [IO.File]::ReadAllText((Join-Path (Get-Location) 'scene/biomes/lower_city/lower_city_presentation.gd'))
foreach ($match in [regex]::Matches($city, '"([a-z_0-9]+)": Rect2\((\d+), (\d+), (\d+), (\d+)\)')) {
    $id=$match.Groups[1].Value
    $atlas=if ($id -like 'biome_exit*') {'CITY_GAMEPLAY'} elseif ($id -like 'crate*' -or $id -like 'container*') {'CITY_PROPS'} else {'CITY_STRUCTURE'}
    $regions += [PSCustomObject]@{atlas=$atlas;x=[int]$match.Groups[2].Value;y=[int]$match.Groups[3].Value;width=[int]$match.Groups[4].Value;height=[int]$match.Groups[5].Value;class='B';purpose=$id}
}
foreach ($rect in @(@(229,16,29,35),@(390,229,52,49),@(458,229,44,44))) {
    $regions += [PSCustomObject]@{atlas='CITY_PROPS';x=$rect[0];y=$rect[1];width=$rect[2];height=$rect[3];class='B';purpose='city_prop'}
}
foreach ($rect in @(@(29,132,133,18),@(674,256,20,60),@(23,459,145,41),@(159,73,66,45))) {
    $regions += [PSCustomObject]@{atlas='CITY_STRUCTURE';x=$rect[0];y=$rect[1];width=$rect[2];height=$rect[3];class='B';purpose='city_architecture'}
}
$results = foreach ($region in $regions | Sort-Object atlas,x,y,width,height -Unique) {
    $bitmap=[Drawing.Bitmap]::new((Join-Path (Get-Location) $assetPaths[$region.atlas]))
    if ($region.x+$region.width -gt $bitmap.Width -or $region.y+$region.height -gt $bitmap.Height) { throw "Out-of-bounds region: $($region | ConvertTo-Json -Compress)" }
    $zero=0; $partial=0; $opaqueLight=0; $minX=$region.width; $minY=$region.height; $maxX=-1; $maxY=-1
    for ($y=0; $y -lt $region.height; $y++) { for ($x=0; $x -lt $region.width; $x++) {
        $pixel=$bitmap.GetPixel($region.x+$x,$region.y+$y)
        if ($pixel.A -eq 0) {$zero++; continue}
        if ($pixel.A -lt 255) {$partial++}
        if ($pixel.A -eq 255 -and $pixel.R -ge 150 -and $pixel.G -ge 150 -and $pixel.B -ge 150) {$opaqueLight++}
        $minX=[Math]::Min($minX,$x); $minY=[Math]::Min($minY,$y); $maxX=[Math]::Max($maxX,$x); $maxY=[Math]::Max($maxY,$y)
    } }
    $bitmap.Dispose()
    [PSCustomObject]@{path=$assetPaths[$region.atlas];purpose=$region.purpose;region=@($region.x,$region.y,$region.width,$region.height);classification=$region.class;transparent=$zero;partialAlpha=$partial;opaqueLightPixels=$opaqueLight;nontransparentBoundsLocal=@($minX,$minY,($maxX+1),($maxY+1))}
}
$results | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 docs/pass3_region_metrics.json
Write-Output "Audited $($results.Count) distinct runtime rectangles; all in bounds."
