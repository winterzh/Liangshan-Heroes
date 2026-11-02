[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
$watchScript=Join-Path $PSScriptRoot 'generated_artifact_retention.py'
$pythonCommand=(Get-Command python -ErrorAction Stop).Source
$pythonWindowless=Join-Path (Split-Path $pythonCommand) 'pythonw.exe'
if(-not (Test-Path -LiteralPath $pythonWindowless -PathType Leaf)){throw 'pythonw.exe is required for a hidden watcher'}
if(-not (Test-Path -LiteralPath $watchScript -PathType Leaf)){throw 'Retention watcher is missing'}
$startupDirectory=[Environment]::GetFolderPath('Startup')
if(-not $startupDirectory){throw 'Current-user Startup directory unavailable'}
if(-not (Test-Path -LiteralPath $startupDirectory)){New-Item -ItemType Directory -Path $startupDirectory|Out-Null}
$shortcutPath=Join-Path $startupDirectory 'WaterMarginArtifactRetention.lnk'
$shortcutOwner='Water Margin generated artifact retention (current user)'
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut($shortcutPath)
if((Test-Path -LiteralPath $shortcutPath) -and $shortcut.Description -cne $shortcutOwner){throw 'An unrelated startup entry has the same name'}
$arguments='-X utf8 -B "'+$watchScript+'" --watch'
$shortcut.TargetPath=$pythonWindowless
$shortcut.Arguments=$arguments
$shortcut.WorkingDirectory=$projectRoot
$shortcut.WindowStyle=7
$shortcut.Description=$shortcutOwner
$shortcut.Save()
$stateDirectory=Join-Path $projectRoot '.godot\artifact_retention'
$statePath=Join-Path $stateDirectory 'watcher.json'
$existing=$null
if(Test-Path -LiteralPath $statePath){
    $record=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
    if($record.script -ceq $watchScript){
        $candidate=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$record.pid) -ErrorAction SilentlyContinue
        if($candidate -and $candidate.CommandLine -and $candidate.Name -eq 'pythonw.exe' -and $candidate.CommandLine.Contains($watchScript) -and $candidate.CommandLine.Contains('--watch')){$existing=$candidate}
    }
}
if(-not $existing){
    $process=Start-Process -FilePath $pythonWindowless -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    $watcherProcessId=$process.Id
}else{$watcherProcessId=$existing.ProcessId}
[pscustomobject]@{StartupShortcut=$shortcutPath;Python=$pythonWindowless;Script=$watchScript;ProcessId=$watcherProcessId;IntervalSeconds=60;VisibleWindow=$false}|ConvertTo-Json
