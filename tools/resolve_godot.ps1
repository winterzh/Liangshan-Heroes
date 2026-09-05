[CmdletBinding()]
param([string]$GodotPath = '')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = $env:GODOT_PATH
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $localConfig = Join-Path $projectRoot 'godot.local.txt'
    if (Test-Path -LiteralPath $localConfig -PathType Leaf) {
        $GodotPath = (Get-Content -LiteralPath $localConfig -Raw -Encoding UTF8).Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    foreach ($commandName in @('godot', 'godot4', 'Godot_v4.6.3-stable_win64_console', 'Godot_v4.6.3-stable_win64')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            $GodotPath = $command.Source
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    throw 'Godot 4.6.3 not found. Pass -GodotPath, set GODOT_PATH, or put the executable path in godot.local.txt at the project root.'
}
if (-not [IO.Path]::IsPathRooted($GodotPath)) {
    $GodotPath = Join-Path $projectRoot $GodotPath
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$consolePath = Join-Path (Split-Path -Parent $GodotPath) ([IO.Path]::GetFileNameWithoutExtension($GodotPath) + '_console.exe')
if (Test-Path -LiteralPath $consolePath -PathType Leaf) {
    $GodotPath = $consolePath
}
$versionOutput = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or ($versionOutput -join "`n").Trim() -notmatch '^4\.6\.3\.') {
    throw "Godot 4.6.3 is required. Reported version: $versionOutput"
}
Write-Output $GodotPath
