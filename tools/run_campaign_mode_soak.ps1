[CmdletBinding()]
param(
    [Parameter()]
    [string]$GodotPath = 'C:\Users\rsb\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe',

    [Parameter()]
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [Parameter()]
    [string]$OutputDirectory = '',

    [Parameter()]
    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 1800,

    [Parameter()]
    [ValidateRange(2, 30)]
    [double]$DwellSeconds = 6,

    [Parameter()]
    [switch]$AllowShort
)

$ErrorActionPreference = 'Stop'
$reportName = 'campaign_mode_soak.json'
$logName = 'godot_console.log'
$readmeName = 'README.md'
$minimumAcceptanceSeconds = 1800

function Set-ProcessEnvironment {
    param([string]$Name, [AllowNull()][string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
}

function Get-NumberOrZero {
    param($Value)
    if ($null -eq $Value) { return [double]0 }
    return [double]$Value
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot console executable not found: $GodotPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'project.godot') -PathType Leaf)) {
    throw "project.godot not found under: $ProjectPath"
}
if ($DurationSeconds -lt $minimumAcceptanceSeconds -and -not $AllowShort) {
    throw "A release acceptance run requires at least $minimumAcceptanceSeconds seconds. Use -AllowShort only for harness debugging; it cannot pass acceptance."
}

# Do not contaminate process, GPU, frame-time or exit-warning evidence with a
# second editor/test instance. The new console process is launched only after
# this zero-process gate passes.
$existingGodot = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'Godot*'
})
if ($existingGodot.Count -gt 0) {
    $owners = ($existingGodot | ForEach-Object { '{0}(PID {1})' -f $_.ProcessName, $_.Id }) -join ', '
    throw "Close all Godot processes before the exclusive soak run: $owners"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputDirectory = Join-Path $ProjectPath ("qa\campaign_mode_soak_$stamp")
} elseif (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectPath $OutputDirectory
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$reportPath = Join-Path $OutputDirectory $reportName
$logPath = Join-Path $OutputDirectory $logName
$readmePath = Join-Path $OutputDirectory $readmeName
$environmentNames = @('CAMPAIGN_SOAK_OUT', 'CAMPAIGN_SOAK_SECONDS', 'CAMPAIGN_SOAK_DWELL_SECONDS')
$oldEnvironment = @{}
foreach ($name in $environmentNames) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

$engineExitCode = -1
try {
    Set-ProcessEnvironment 'CAMPAIGN_SOAK_OUT' $OutputDirectory
    Set-ProcessEnvironment 'CAMPAIGN_SOAK_SECONDS' ([string]$DurationSeconds)
    Set-ProcessEnvironment 'CAMPAIGN_SOAK_DWELL_SECONDS' ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $DwellSeconds))
    $arguments = @(
        '--path', $ProjectPath,
        '--rendering-method', 'forward_plus',
        '--rendering-driver', 'vulkan',
        '--script', 'res://tools/campaign_mode_soak_test.gd'
    )
    Write-Host "Starting exclusive Vulkan soak. Output: $OutputDirectory"
    & $GodotPath @arguments 2>&1 | Tee-Object -FilePath $logPath
    $engineExitCode = $LASTEXITCODE
} finally {
    foreach ($name in $environmentNames) {
        Set-ProcessEnvironment $name $oldEnvironment[$name]
    }
}

$logLines = @(Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue)
$warningPattern = '(?i)(WARNING:|ERROR:|SCRIPT ERROR|Parse Error|orphan node|instances leaked at exit|RID allocations|TextureStorage|RenderingServer.+destroyed)'
$warningLines = @($logLines | Where-Object { $_ -match $warningPattern } | Select-Object -Unique)

if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
} else {
    $report = [pscustomobject]@{
        passed = $false
        runtime_checks_passed = $false
        acceptance_eligible = ($DurationSeconds -ge $minimumAcceptanceSeconds)
        failures = @('Godot process did not write campaign_mode_soak.json')
    }
}

$processExit = [ordered]@{
    exit_code = $engineExitCode
    warnings_count = $warningLines.Count
    warning_lines = $warningLines
    console_log = $logPath
    post_processed_at = (Get-Date).ToString('s')
}
$report | Add-Member -NotePropertyName process_exit -NotePropertyValue $processExit -Force
$report | Add-Member -NotePropertyName exit_warning_status -NotePropertyValue $(
    if ($warningLines.Count -eq 0) { 'no matched exit warning' } else { 'matched exit warning; inspect process_exit.warning_lines' }
) -Force

$runtimePassed = [bool]$report.runtime_checks_passed -and $engineExitCode -eq 0 -and $warningLines.Count -eq 0
$fullAcceptance = $runtimePassed -and [bool]$report.acceptance_eligible -and [bool]$report.passed
$report | Add-Member -NotePropertyName passed -NotePropertyValue $fullAcceptance -Force
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$json = $report | ConvertTo-Json -Depth 100
[IO.File]::WriteAllText($reportPath, $json + [Environment]::NewLine, $utf8NoBom)

$actualSeconds = Get-NumberOrZero $report.actual_seconds
$transitionCount = [int](Get-NumberOrZero $report.transition_count)
$maxP95 = Get-NumberOrZero $report.performance.max_minute_p95_ms
$maxP99 = Get-NumberOrZero $report.performance.max_minute_p99_ms
$saveUnchanged = [bool]$report.campaign_save.unchanged
$renderer = if ($null -ne $report.renderer) {
    '{0}; {1}; {2}' -f $report.renderer.adapter, $report.renderer.api, $report.renderer.method
} else { 'report unavailable' }
$resultText = if ($fullAcceptance) {
    'PASS：30 分钟稳定性验收完成。'
} elseif ($AllowShort -and $runtimePassed) {
    '仅调试：工具检查通过，但运行时长不足 30 分钟，不能作为验收结果。'
} else {
    'FAIL：请检查 campaign_mode_soak.json 和 godot_console.log。'
}
$readme = @"
# 模式切换稳定性结果

$resultText

- 要求/实际时长：$DurationSeconds 秒 / $([Math]::Round($actualSeconds, 3)) 秒
- 渲染器：$renderer
- 路线：战役 level1 → 竞技场 → 遭遇战 → AI 对战 → 自定义据守 → 战役 level5
- 场景切换次数：$transitionCount
- 各分钟最高 P95/P99：$([Math]::Round($maxP95, 3)) ms / $([Math]::Round($maxP99, 3)) ms
- campaign.cfg 字节未变：$saveUnchanged
- 进程退出码/匹配到的警告数：$engineExitCode / $($warningLines.Count)
- JSON: $reportPath
- 控制台日志：$logPath

本结果只覆盖真实渲染、模式切换、资源释放和性能；不代表真人试玩、节奏或平衡结论。
"@
[IO.File]::WriteAllText($readmePath, $readme.Trim() + [Environment]::NewLine, $utf8NoBom)

Write-Host $resultText
Write-Host "Report: $reportPath"
Write-Host "README: $readmePath"
if ($fullAcceptance) {
    exit 0
}
if ($AllowShort -and $runtimePassed) {
    exit 0
}
if ($engineExitCode -ne 0) {
    exit $engineExitCode
}
exit 1
