param([string]$TaskRoot='D:\CodexTemp\shuihu-cleanup-20261026')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath('D:\AI项目\水浒\开发工程')
$roots=@(Get-Content -LiteralPath (Join-Path $TaskRoot 'candidate_roots.json') -Raw | ConvertFrom-Json)
$verification=Get-Content -LiteralPath (Join-Path $TaskRoot 'archive_verification.json') -Raw | ConvertFrom-Json
$prepared=Get-Content -LiteralPath (Join-Path $TaskRoot 'prepare_summary.json') -Raw | ConvertFrom-Json
if($prepared.target_files -ne $verification.mapped_files -or $prepared.protected_files -lt 1){throw 'Protection snapshot is incomplete'}
$restore=Get-Content -LiteralPath (Join-Path $TaskRoot 'restore_actual_verification.json') -Raw | ConvertFrom-Json
if(-not $verification.all_blob_sha256_passed -or -not $verification.manifest_roundtrip_passed -or -not $restore.verified -or $restore.restored_files -le 0){throw 'Archive or actual restoration is not verified'}
if((Get-FileHash -LiteralPath $verification.archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $verification.archive_sha256){throw 'Archive changed'}
$binding=Get-Content -LiteralPath (Join-Path $TaskRoot 'remove_plan_binding.json') -Raw | ConvertFrom-Json
if($binding.archive_sha256 -ne $verification.archive_sha256 -or $binding.files -ne $verification.mapped_files){throw 'Plan archive binding differs'}
if((Get-FileHash -LiteralPath (Join-Path $TaskRoot 'remove_plan.jsonl.gz') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binding.plan_sha256){throw 'Removal plan changed'}
$zip=[IO.Compression.ZipFile]::OpenRead([string]$verification.archive)
try{$manifestStream=$zip.GetEntry('manifest.json').Open();try{$manifestSHA=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($manifestStream)).ToLowerInvariant()}finally{$manifestStream.Dispose()}}finally{$zip.Dispose()}
if($manifestSHA -ne $binding.manifest_sha256){throw 'Plan is not bound to archive manifest'}
if(Test-Path -LiteralPath (Join-Path $TaskRoot 'removed.jsonl.gz')){throw 'Removal journal exists; inspect before resuming'}
function Assert-Idle {
 if(@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -like 'Godot*'}).Count -gt 0){throw 'Godot is running; leave it alone and stop cleanup'}
}
Assert-Idle
$allowed=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$checkedParents=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($rel in $roots){
 $full=[IO.Path]::GetFullPath((Join-Path $project $rel))
 if(-not $full.StartsWith($project+'\.godot\',[StringComparison]::OrdinalIgnoreCase) -or -not $full.EndsWith('\project',[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid root'}
 for($d=[IO.DirectoryInfo]::new($full);$null -ne $d;$d=$d.Parent){if(($d.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse ancestor: $full"}}
 $null=$allowed.Add($full)
}
Add-Type @'
using System;using System.Runtime.InteropServices;using Microsoft.Win32.SafeHandles;
public static class ArchiveLinkCheck26 {
 [StructLayout(LayoutKind.Sequential)] public struct Info {public uint Attributes;public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;}
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info i);
 public static uint Links(SafeFileHandle h){Info i;if(!GetFileInformationByHandle(h,out i))throw new System.ComponentModel.Win32Exception();return i.Links;}
}
'@
$inputStream=[IO.Compression.GzipStream]::new([IO.File]::OpenRead((Join-Path $TaskRoot 'remove_plan.jsonl.gz')),[IO.Compression.CompressionMode]::Decompress)
$reader=[IO.StreamReader]::new($inputStream,[Text.Encoding]::UTF8)
$outputStream=[IO.Compression.GzipStream]::new([IO.File]::Create((Join-Path $TaskRoot 'removed.jsonl.gz')),[IO.Compression.CompressionLevel]::Fastest)
$writer=[IO.StreamWriter]::new($outputStream,[Text.UTF8Encoding]::new($false))
$skipped=[Collections.Generic.List[object]]::new()
$count=0;$bytes=[long]0;$seen=0
try {
 while($null -ne ($line=$reader.ReadLine())){
  $row=$line|ConvertFrom-Json
  $seen++
  if($seen % 2000 -eq 1){Assert-Idle}
  try{
   $full=[IO.Path]::GetFullPath((Join-Path $project ([string]$row.path)))
   $root=[IO.Path]::GetFullPath((Join-Path $project ([string]$row.root)))
   if(-not $allowed.Contains($root) -or -not $full.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Outside allowlist'}
   $tail=$full.Substring($root.Length+1)
   if($tail.Split('\') -contains '.godot'){throw 'Protected cache subtree'}
   $item=[IO.FileInfo]::new($full)
   if(-not $item.Exists -or $item.Length -ne [long]$row.bytes -or $item.LastWriteTimeUtc.Ticks -ne [long]$row.utc_ticks){throw 'Missing or changed file'}
   if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse file'}
   for($d=$item.Directory;$null -ne $d;$d=$d.Parent){
    if($checkedParents.Contains($d.FullName)){break}
    if(($d.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse ancestor'}
    $null=$checkedParents.Add($d.FullName)
   }
   $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
   try{
    if([ArchiveLinkCheck26]::Links($stream.SafeFileHandle) -ne 1){throw 'Hard-linked file'}
    $sha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
    if($sha -ne [string]$row.sha256){throw 'Content changed'}
   }finally{$stream.Dispose()}
   Remove-Item -LiteralPath $full -Force -ErrorAction Stop
   $writer.WriteLine($line)
   $count++;$bytes += [long]$row.bytes
  }catch{
   $skipped.Add([pscustomobject]@{path=[string]$row.path;reason=$_.Exception.Message})
  }
  if($seen % 20000 -eq 0){$writer.Flush();[pscustomobject]@{seen=$seen;removed=$count;skipped=$skipped.Count}|ConvertTo-Json -Compress}
 }
}finally{$reader.Dispose();$writer.Dispose()}
$result=[pscustomobject]@{seen=$seen;removed_files=$count;removed_bytes=$bytes;skipped_files=$skipped.Count;skipped=$skipped}
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $TaskRoot 'removal_summary.json') -Encoding utf8
$result|Select-Object seen,removed_files,removed_bytes,skipped_files|ConvertTo-Json
