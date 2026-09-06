[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'

$projectRoot = [System.IO.Path]::GetFullPath($ProjectPath)
$markerPath = Join-Path $projectRoot '.godot\import_cache_ready.marker'
$importedPath = Join-Path $projectRoot '.godot\imported'
$assetPath = Join-Path $projectRoot 'assets'
$needsImport = $env:LSH_FORCE_IMPORT -eq '1'

if (-not $needsImport) {
    $needsImport = -not (Test-Path -LiteralPath $markerPath -PathType Leaf) `
        -or -not (Test-Path -LiteralPath $importedPath -PathType Container)
}

if (-not $needsImport) {
    $markerTime = (Get-Item -LiteralPath $markerPath).LastWriteTimeUtc
    $projectFile = Get-Item -LiteralPath (Join-Path $projectRoot 'project.godot')
    if ($projectFile.LastWriteTimeUtc -gt $markerTime) {
        $needsImport = $true
    }
    elseif (Test-Path -LiteralPath $assetPath) {
        $newerAsset = Get-ChildItem -LiteralPath $assetPath -Recurse -File | Where-Object {
            $_.Extension -ne '.import' -and $_.LastWriteTimeUtc -gt $markerTime
        } | Select-Object -First 1
        $needsImport = $null -ne $newerAsset
    }
}

if (-not $needsImport) {
    $criticalPatterns = @(
        'app_icon_256.png-*.ctex',
        'boot_splash.png-*.ctex',
        'fx_ability_projectiles.png-*.ctex'
    )
    foreach ($pattern in $criticalPatterns) {
        if ($null -eq (Get-ChildItem -LiteralPath $importedPath -Filter $pattern -File | Select-Object -First 1)) {
            $needsImport = $true
            break
        }
    }
}

if (-not $needsImport) {
    Write-Host 'Godot import cache is ready; starting immediately.'
    exit 0
}

Write-Host 'Godot resources changed or the cache is missing; rebuilding once...'
$godotDirectory = Split-Path -Parent $GodotPath
$godotBaseName = [System.IO.Path]::GetFileNameWithoutExtension($GodotPath)
$consoleGodot = Join-Path $godotDirectory ($godotBaseName + '_console.exe')
$importExecutable = $GodotPath
if (Test-Path -LiteralPath $consoleGodot -PathType Leaf) {
    $importExecutable = $consoleGodot
}
& $importExecutable --headless --path $projectRoot --import
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot resource import failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

$markerDirectory = Split-Path -Parent $markerPath
if (-not (Test-Path -LiteralPath $markerDirectory)) {
    New-Item -ItemType Directory -Path $markerDirectory -Force | Out-Null
}
Set-Content -LiteralPath $markerPath -Value ([DateTime]::UtcNow.ToString('o')) -Encoding Ascii
Write-Host 'Godot import cache rebuilt.'
exit 0
