# Reference extraction only: lossless rectangular crop, no drawing or mirroring.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$refRoot = Join-Path $PSScriptRoot 'references'
New-Item -ItemType Directory -Path $refRoot -Force | Out-Null
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sourcePath = Join-Path $root 'assets/characters/song_jiang_direction4_20260906/walk_atlas.png'
$before = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$image = [System.Drawing.Bitmap]::FromFile($sourcePath)
$items = @()
try {
    foreach ($spec in @(@('ne',0,560,700,639), @('nw',700,560,612,639))) {
        $out = Join-Path $refRoot ('walk_a_' + $spec[0] + '_reference_crop.png')
        if (Test-Path -LiteralPath $out) { throw "Output exists: $out" }
        $rect = [System.Drawing.Rectangle]::new($spec[1],$spec[2],$spec[3],$spec[4])
        $crop = $image.Clone($rect, $image.PixelFormat)
        try { $crop.Save($out,[System.Drawing.Imaging.ImageFormat]::Png) } finally { $crop.Dispose() }
        $items += [pscustomobject]@{path=$out;rectangle=@($spec[1],$spec[2],$spec[3],$spec[4]);sha256=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLower()}
    }
} finally { $image.Dispose() }
$after=(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if ($before -ne $after) { throw 'Reference atlas changed' }
[pscustomobject]@{source=$sourcePath;source_sha256=$after.ToLower();unchanged=$true;operation='rectangular crop only; no flip or painting';crops=$items} | ConvertTo-Json -Depth 5
