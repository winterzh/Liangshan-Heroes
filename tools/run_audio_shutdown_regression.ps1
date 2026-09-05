param(
    [string]$Godot = ''
)

$ErrorActionPreference = 'Stop'
$Godot = & (Join-Path $PSScriptRoot 'resolve_godot.ps1') -GodotPath $Godot
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputDir = Join-Path $projectRoot 'qa\audio_shutdown_20260902'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable missing: $Godot"
}
if (@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'Refusing to start while another Godot process is running.'
}

$specs = @(
    @{ name = 'fast'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'menu'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'battle'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'android'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'window'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'sfx'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-exit-case]' },
    @{ name = 'transition'; script = 'res://tools/audio_shutdown_regression_test.gd'; marker = '[audio-transition-result]' },
    @{ name = 'direct_quit_fallback'; script = 'res://tools/campaign_core_test.gd'; marker = '[core-result]' }
)

$results = @()
try {
    foreach ($spec in $specs) {
        $logName = if ($spec.name -eq 'direct_quit_fallback') { 'campaign_core_verbose.log' } else { $spec.name + '_verbose.log' }
        $logPath = Join-Path $outputDir $logName
        if ($spec.name -eq 'direct_quit_fallback') {
            Remove-Item Env:AUDIO_EXIT_CASE -ErrorAction SilentlyContinue
        } else {
            $env:AUDIO_EXIT_CASE = $spec.name
        }
        # Godot writes diagnostics to stderr even on successful runs. Capture them in
        # the per-case log and judge their content below instead of letting PowerShell
        # turn one stderr line into a terminating NativeCommandError.
        $savedErrorPreference = $ErrorActionPreference
        $savedNativePreference = $PSNativeCommandUseErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $PSNativeCommandUseErrorActionPreference = $false
            & $Godot --headless --path $projectRoot --verbose --script $spec.script *> $logPath
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorPreference
            $PSNativeCommandUseErrorActionPreference = $savedNativePreference
        }
        $logText = Get-Content -LiteralPath $logPath -Raw
        $resultMatch = Get-Content -LiteralPath $logPath |
            Where-Object { $_.Contains($spec.marker) } |
            Select-Object -Last 1
        $resultLine = if ($null -eq $resultMatch) { '' } else { [string]$resultMatch }
        $row = [ordered]@{
            name = $spec.name
            exit_code = $exitCode
            result = $resultLine
            log = $logPath
            log_sha256 = (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash.ToLowerInvariant()
            audio_stream_leaks = ([regex]::Matches($logText, 'Leaked instance: AudioStream')).Count
            any_leaked_instances = ([regex]::Matches($logText, 'Leaked instance:')).Count
            objectdb_warnings = ([regex]::Matches($logText, 'ObjectDB instances leaked')).Count
            orphan_master = ([regex]::Matches($logText, 'Orphan StringName: Master')).Count
            any_orphan_string_names = ([regex]::Matches($logText, 'Orphan StringName:')).Count
            script_errors = ([regex]::Matches($logText, 'SCRIPT ERROR|Parse Error')).Count
        }
        $row.passed = $row.exit_code -eq 0 -and $row.result -match '"passed":true' `
            -and $row.any_leaked_instances -eq 0 -and $row.objectdb_warnings -eq 0 `
            -and $row.any_orphan_string_names -eq 0 -and $row.script_errors -eq 0
        $results += [pscustomobject]$row
    }
} finally {
    Remove-Item Env:AUDIO_EXIT_CASE -ErrorAction SilentlyContinue
}

$remaining = @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue | Select-Object Id, ProcessName)
$summary = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    passed = ($results | Where-Object { -not $_.passed }).Count -eq 0 -and $remaining.Count -eq 0
    cases = $results
    godot_processes_after = $remaining
}
$summaryPath = Join-Path $outputDir 'runner_summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output (ConvertTo-Json ([ordered]@{
    passed = $summary.passed
    cases = $results.Count
    summary = $summaryPath
    summary_sha256 = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
}) -Compress)
if (-not $summary.passed) {
    exit 1
}
