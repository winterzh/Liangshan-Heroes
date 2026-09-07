# QA compositing only. Read original PNGs; write independent review canvases.
# No painted asset generation, recoloring, mirroring, alpha cleanup or production writes.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$candidateRoot = $PSScriptRoot
$projectRoot = Split-Path (Split-Path $candidateRoot -Parent) -Parent
$qaRoot = Join-Path $candidateRoot 'preview'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
$sourceFiles = @()
foreach ($direction in @('se', 'sw', 'ne', 'nw')) {
    $sourceFiles += Join-Path $projectRoot "assets/characters/song_jiang_direction4_20260906/idle_$direction.png"
    $sourceFiles += Join-Path $candidateRoot "source/song_jiang_hurt_${direction}_v1.png"
}
$before = @{}
foreach ($sourceFile in $sourceFiles) {
    $before[$sourceFile] = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
}
$font = [System.Drawing.Font]::new('Arial', 14)
$smallFont = [System.Drawing.Font]::new('Arial', 11)
try {
    foreach ($theme in @('light', 'dark')) {
        $background = if ($theme -eq 'light') { [System.Drawing.Color]::FromArgb(250,249,244) } else { [System.Drawing.Color]::FromArgb(23,32,39) }
        $ink = if ($theme -eq 'light') { [System.Drawing.Brushes]::Black } else { [System.Drawing.Brushes]::White }
        $bitmap = [System.Drawing.Bitmap]::new(1360, 820, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear($background)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawString("Song Jiang - original-alpha QA - $theme", $font, $ink, 20, 14)
            $graphics.DrawString('Top: existing idle   Bottom: generated hurt V1   Shared scale 0.23; no runtime anchoring or acceptance.', $smallFont, $ink, 20, 42)
            $directions = @('se', 'sw', 'ne', 'nw')
            for ($col = 0; $col -lt 4; $col++) {
                for ($row = 0; $row -lt 2; $row++) {
                    $sourceFile = $sourceFiles[$col * 2 + $row]
                    $src = [System.Drawing.Image]::FromFile($sourceFile)
                    try {
                        $width = [single]($src.Width * 0.23)
                        $height = [single]($src.Height * 0.23)
                        $left = [single]($col * 340 + (340 - $width) / 2)
                        $top = [single](78 + $row * 368 + (326 - $height))
                        $graphics.DrawImage($src, $left, $top, $width, $height)
                        $caption = $directions[$col].ToUpper() + $(if ($row -eq 0) { ' idle reference' } else { ' hurt candidate V1' })
                        $graphics.DrawString($caption, $smallFont, $ink, ($col * 340 + 18), (80 + $row * 368 + 327))
                    } finally { $src.Dispose() }
                }
            }
            $graphics.DrawString('QA canvas only. Original source bytes and production files remain unchanged.', $smallFont, $ink, 20, 790)
            $outPath = Join-Path $qaRoot "hurt_v1_${theme}.png"
            if (Test-Path -LiteralPath $outPath) { throw "QA output exists; use a new review version: $outPath" }
            $bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
} finally {
    $font.Dispose()
    $smallFont.Dispose()
}
$matches = foreach ($sourceFile in $sourceFiles) {
    $after = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
    [pscustomobject]@{ path=$sourceFile; sha256=$after.ToLower(); unchanged=($before[$sourceFile] -eq $after) }
}
if (@($matches | Where-Object { -not $_.unchanged }).Count -ne 0) { throw 'Source changed during review rendering' }
[pscustomobject]@{ original_files=$matches; shared_scale=0.23; original_bytes_unchanged=$true; qa_only=$true } | ConvertTo-Json -Depth 6
