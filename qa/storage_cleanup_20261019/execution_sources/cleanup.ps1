param([string]$TaskRoot='D:\CodexEvidence\shuihu\storage_cleanup_20261019')
$ErrorActionPreference='Stop'
$planPath=Join-Path $TaskRoot 'plan.json.gz'
$stream=[IO.Compression.GzipStream]::new([IO.File]::OpenRead($planPath),[IO.Compression.CompressionMode]::Decompress)
$reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
try {$plan=$reader.ReadToEnd() | ConvertFrom-Json} finally {$reader.Dispose()}
$project='D:\AI项目\水浒\开发工程'
$evidence='D:\CodexEvidence\shuihu'
$active=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'godot|chrome|msedge' -and ($_.CommandLine -like "*$project*" -or $_.CommandLine -like "*$evidence*")})
if($active.Count -gt 0){throw 'Project browser/engine is active; no deletion started.'}
# Validate every absolute filename, reparse ancestry, hash and exclusive access before mutation.
foreach($row in $plan.targets){
 $path=[IO.Path]::GetFullPath([string]$row.path)
 if($path -cne [string]$row.path){throw "Noncanonical path: $path"}
 if(-not ($path.StartsWith($project+'\.godot\',[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($evidence+'\',[StringComparison]::OrdinalIgnoreCase))){throw "Outside allowlist: $path"}
 $item=Get-Item -LiteralPath $path -Force
 if($item.PSIsContainer -or $item.Length -ne $row.bytes){throw "Changed target: $path"}
 for($ancestor=$item; $null -ne $ancestor; $ancestor=if($ancestor -is [IO.FileInfo]){$ancestor.Directory}else{$ancestor.Parent}){
  if(($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse path: $path"}
 }
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $row.sha256){throw "Hash changed: $path"}
 if($row.retained_copy){if((Get-FileHash -LiteralPath $row.retained_copy -Algorithm SHA256).Hash.ToLowerInvariant() -ne $row.sha256){throw "Retained copy changed: $path"}}
 $probe=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$probe.Dispose()
}
$journal=Join-Path $TaskRoot 'deleted.jsonl'
if(Test-Path -LiteralPath $journal){throw 'Deletion journal exists; inspect before rerun.'}
$writer=[IO.StreamWriter]::new($journal,$false,[Text.UTF8Encoding]::new($false))
$count=0;$bytes=[long]0
try {
 foreach($row in $plan.targets){
  Remove-Item -LiteralPath $row.path -Force -ErrorAction Stop
  $writer.WriteLine(($row | ConvertTo-Json -Compress));$writer.Flush()
  $count++;$bytes+=[long]$row.bytes
 }
} finally {$writer.Dispose()}
[pscustomobject]@{deleted_files=$count;logical_bytes=$bytes;C_free=(Get-PSDrive C).Free;D_free=(Get-PSDrive D).Free} | ConvertTo-Json
