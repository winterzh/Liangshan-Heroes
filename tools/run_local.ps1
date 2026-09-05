[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [ValidateSet('play', 'editor', 'import')]
    [string]$Mode = 'play',
    [switch]$Reimport,
    [string[]]$GodotArgs = @()
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotExecutable = & (Join-Path $PSScriptRoot 'resolve_godot.ps1') -GodotPath $GodotPath
$previousForceImport = $env:LSH_FORCE_IMPORT
try {
    if ($Reimport) { $env:LSH_FORCE_IMPORT = '1' }
    & (Join-Path $PSScriptRoot 'ensure_import_cache.ps1') -ProjectPath $projectRoot -GodotPath $godotExecutable
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    $env:LSH_FORCE_IMPORT = $previousForceImport
}
if ($Mode -eq 'import') { exit 0 }
$arguments = @('--path', $projectRoot)
if ($Mode -eq 'editor') { $arguments += '--editor' }
$arguments += $GodotArgs
& $godotExecutable @arguments
exit $LASTEXITCODE
