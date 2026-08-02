$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$weaponRoot = Join-Path $repoRoot 'weapon'

foreach ($file in Get-ChildItem -LiteralPath $weaponRoot -Recurse -File -Filter '*.xml') {
    [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw

    if ($xml.SelectSingleNode("//*[@identifier='deep_VCE_none' or @identifier='deep_VCE_yes']")) {
        throw "VCE self-check remains in $($file.FullName)"
    }

    foreach ($item in $xml.SelectNodes('//Item[@Scale]')) {
        $itemScale = [decimal]::Parse($item.GetAttribute('Scale'), [Globalization.CultureInfo]::InvariantCulture)
        foreach ($effect in $item.SelectNodes(".//StatusEffect[contains(@type, 'OnActive') and @Scale]")) {
            $effectScale = [decimal]::Parse($effect.GetAttribute('Scale'), [Globalization.CultureInfo]::InvariantCulture)
            if ($effectScale -eq $itemScale) {
                throw "Redundant OnActive Scale remains in $($file.FullName)"
            }
        }
    }
}

$heldWeapons = Join-Path $repoRoot 'Lua/Scripts/PeachTechnology/AdjustStatvalue/AdjustEquipmentStatvalue-Config/HeldWeapons.lua'
if (Select-String -LiteralPath $heldWeapons -Pattern 'deep_VCE_(none|yes)' -Quiet) {
    throw 'VCE self-check remains in HeldWeapons.lua'
}

Write-Output 'Weapon XML optimization checks passed.'
