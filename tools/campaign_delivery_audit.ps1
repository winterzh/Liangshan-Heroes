param(
    [string]$EvidenceName = '_archive\campaign_history\campaign_rework_20260831_173850'
)
$ErrorActionPreference = 'Stop'
$campaignRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$campaignParent = Split-Path -Parent $campaignRoot
$campaignEvidence = Join-Path $campaignParent $EvidenceName
$campaignOutput = Join-Path $campaignRoot 'qa\campaign_delivery'
$null = New-Item -ItemType Directory -Path $campaignOutput -Force

# Read-only baseline comparison. No original file is restored, deleted, or moved.
$baselineEntries = Get-Content -LiteralPath (Join-Path $campaignEvidence 'baseline_manifest.json') -Raw | ConvertFrom-Json
$missingFiles = @()
$changedFiles = @()
$unchangedCount = 0
$originalAssetCount = 0
$originalAssetsChanged = @()
$backupMissing = @()
$backupChanged = @()
foreach ($entry in $baselineEntries) {
    $backupPath = Join-Path (Join-Path $campaignEvidence 'baseline') $entry.path
    if (!(Test-Path -LiteralPath $backupPath -PathType Leaf)) { $backupMissing += $entry.path }
    elseif ((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $entry.sha256) { $backupChanged += $entry.path }
    $currentPath = Join-Path $campaignRoot $entry.path
    if (!(Test-Path -LiteralPath $currentPath -PathType Leaf)) {
        $missingFiles += $entry.path
        continue
    }
    $currentHash = (Get-FileHash -LiteralPath $currentPath -Algorithm SHA256).Hash
    $same = $currentHash -eq $entry.sha256
    if ($same) { $unchangedCount++ } else { $changedFiles += $entry.path }
    if ($entry.path.StartsWith('assets\')) {
        $originalAssetCount++
        if (!$same) { $originalAssetsChanged += $entry.path }
    }
}

function Read-LogRecords([string]$Path, [string]$Prefix) {
    $records = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line.StartsWith($Prefix)) {
            $records += $line.Substring($Prefix.Length).Trim() | ConvertFrom-Json
        }
    }
    return $records
}

$early = @(Read-LogRecords (Join-Path $campaignEvidence 'early-content2-final.log') '[early-result]')
$earlyLosses = @(Read-LogRecords (Join-Path $campaignEvidence 'early-content2-final.log') '[early-negative]')
$later = @(Read-LogRecords (Join-Path $campaignEvidence 'later-content2-final.log') '[later-result]')
$finale = @(Read-LogRecords (Join-Path $campaignEvidence 'finale-content2-final.log') '[finale-result]')
$core = @(Read-LogRecords (Join-Path $campaignEvidence 'core-content2-final.log') '[core-result]')
$modes = @(Read-LogRecords (Join-Path $campaignEvidence 'modes-content2-final.log') '[runtime-result]')
$allEight = $early.Count -eq 4 -and $later.Count -eq 3 -and @($finale | Where-Object { $_.case -eq 'victory' -and $_.passed }).Count -eq 1
$allEight = $allEight -and @($early + $later | Where-Object { !$_.passed }).Count -eq 0
$corePassLines = @(Get-Content -LiteralPath (Join-Path $campaignEvidence 'core-content2-final.log') | Where-Object { $_.StartsWith('[core] PASS ') }).Count
$modePassLines = @(Get-Content -LiteralPath (Join-Path $campaignEvidence 'modes-content2-final.log') | Where-Object { $_.StartsWith('[runtime-check] PASS ') }).Count

$assetContract = Get-Content -LiteralPath (Join-Path $campaignRoot 'assets\campaign\contract_qa.json') -Raw | ConvertFrom-Json
$motionContract = Get-Content -LiteralPath (Join-Path $campaignRoot 'assets\campaign\motion_contract_qa.json') -Raw | ConvertFrom-Json
$edges = Get-Content -LiteralPath (Join-Path $campaignRoot 'qa\campaign_edges\fixtures.json') -Raw | ConvertFrom-Json
$huang = Get-Content -LiteralPath (Join-Path $campaignRoot 'qa\campaign_huangnigang\tactics_v1.json') -Raw | ConvertFrom-Json
$cargo = Get-Content -LiteralPath (Join-Path $campaignRoot 'qa\campaign_huangnigang\cargo_v1.json') -Raw | ConvertFrom-Json
$storyVisuals = Get-Content -LiteralPath (Join-Path $campaignRoot 'qa\campaign_story_visual\report.json') -Raw | ConvertFrom-Json
$daming = @(Read-LogRecords (Join-Path $campaignRoot 'qa\campaign_later\infiltration_daming_v3_verified.log') '[daming-v3-result]')

$runtimeManifest = @()
foreach ($folder in @('scripts', 'scenes', 'assets\campaign\anim', 'assets\campaign\objects', 'assets\campaign\portraits')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $campaignRoot $folder) -File -Recurse) {
        if ($file.Extension -notin @('.gd', '.gdshader', '.tscn', '.tres', '.png')) { continue }
        $relative = $file.FullName.Substring($campaignRoot.Length + 1)
        $runtimeManifest += [ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
}
foreach ($name in @('project.godot', 'README.md')) {
    $runtimeManifest += [ordered]@{ path = $name; sha256 = (Get-FileHash -LiteralPath (Join-Path $campaignRoot $name) -Algorithm SHA256).Hash }
}
$runtimeManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $campaignOutput 'runtime_manifest.json') -Encoding utf8

$receipt = [ordered]@{
    captured_at = (Get-Date).ToString('o')
    scope = 'Baseline integrity and aggregation of named automated evidence; not a new playthrough, human acceptance, visual approval, or release approval.'
    source_root = $campaignRoot
    baseline = [ordered]@{
        entries = $baselineEntries.Count; unchanged = $unchangedCount; changed = $changedFiles
        missing = $missingFiles; original_assets_checked = $originalAssetCount; original_assets_changed = $originalAssetsChanged
        backup_missing = $backupMissing; backup_changed = $backupChanged
    }
    functional = [ordered]@{
        all_eight_chapters_passed = $allEight
        core_checks = $corePassLines; core_passed = ($core.Count -eq 1 -and $core[0].passed)
        early_success = $early; early_failures = $earlyLosses; later_success = $later; finale_cases = $finale
        mode_checks = $modePassLines; modes_passed = ($modes.Count -eq 1 -and $modes[0].passed)
        edge_fixtures = $edges; huangnigang_specialized_passed = $huang.passed
        cargo_visibility_cases = $cargo.cases.Count; cargo_visibility_passed = $cargo.passed
        daming_specialized_checks = $daming[0].checks; daming_specialized_passed = $daming[0].passed
    }
    rendered_event_captures = [ordered]@{ count = $storyVisuals.samples.Count; captured_all_requested = $storyVisuals.captured_all_requested; human_playtest = $false }
    art = [ordered]@{
        generic_contract = $assetContract; motion_contract = $motionContract
        animation_strip_pngs = @(Get-ChildItem -LiteralPath (Join-Path $campaignRoot 'assets\campaign\anim') -Filter '*.png' -File).Count
        object_pngs = @(Get-ChildItem -LiteralPath (Join-Path $campaignRoot 'assets\campaign\objects') -Filter '*.png' -File).Count
        portrait_pngs = @(Get-ChildItem -LiteralPath (Join-Path $campaignRoot 'assets\campaign\portraits') -Filter '*.png' -File).Count
        strips_are_not_all_full_animations = $true
    }
    limitations = @('15-25 minute ordinary chapter content is not met', 'Remaining full animations and placeholder civilians', 'No human playtest', 'No long-duration stability acceptance', 'Existing exit ObjectDB/Texture/RID cleanup warnings retained')
    steam_release_directory_accessed_by_this_audit = $false
    export_or_upload = $false
}
$receipt | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $campaignOutput 'verification_index.json') -Encoding utf8
$passed = $allEight -and $missingFiles.Count -eq 0 -and $originalAssetsChanged.Count -eq 0 -and $receipt.functional.core_passed -and $receipt.functional.modes_passed
$passed = $passed -and $backupMissing.Count -eq 0 -and $backupChanged.Count -eq 0
$passed = $passed -and $earlyLosses.Count -eq 5 -and $finale.Count -eq 6 -and @($earlyLosses + $finale | Where-Object { !$_.passed }).Count -eq 0
$passed = $passed -and $assetContract.passed -and $motionContract.passed -and $edges.passed -and $huang.passed -and $daming[0].passed
$passed = $passed -and $cargo.passed -and $cargo.cases.Count -eq 4 -and $storyVisuals.captured_all_requested -and $storyVisuals.samples.Count -eq 5
[ordered]@{ evidence_aggregation_passed = $passed; baseline_entries = $baselineEntries.Count; backup_missing = $backupMissing.Count; backup_changed = $backupChanged.Count; missing = $missingFiles.Count; changed_original_files = $changedFiles.Count; unchanged_original_assets = $originalAssetCount; all_eight_chapters = $allEight; core_checks = $corePassLines; mode_checks = $modePassLines; output = $campaignOutput } | ConvertTo-Json -Compress
if (!$passed) { exit 1 }
