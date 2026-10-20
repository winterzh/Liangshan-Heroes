param([string]$TaskRoot='D:\CodexEvidence\shuihu\storage_cleanup_20261020')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath('D:\AI项目\水浒\开发工程')
$base=$project+'\.godot\'
$zipStream=[IO.Compression.GzipStream]::new([IO.File]::OpenRead((Join-Path $TaskRoot 'plan.json.gz')),[IO.Compression.CompressionMode]::Decompress)
$reader=[IO.StreamReader]::new($zipStream,[Text.Encoding]::UTF8)
try{$plan=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
if(Test-Path -LiteralPath (Join-Path $TaskRoot 'deleted.jsonl')){throw 'Journal exists; inspect before repeating.'}
function Assert-Idle {
 if(@(Get-CimInstance Win32_Process|Where-Object {$_.Name -like 'Godot*'}).Count -gt 0){throw 'Godot is active; stop this cleanup without controlling it.'}
}
Assert-Idle
Add-Type @'
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public static class CacheLinkCheck20 {
 [StructLayout(LayoutKind.Sequential)] public struct FileInfo {public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;}
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool GetFileInformationByHandle(SafeFileHandle file,out FileInfo info);
 public static uint Links(SafeFileHandle file){FileInfo info;if(!GetFileInformationByHandle(file,out info))throw new System.ComponentModel.Win32Exception();return info.Links;}
}
'@
$allowed=@($plan.allowed_cache_roots|ForEach-Object {[IO.Path]::GetFullPath([string]$_)})
foreach($root in $allowed){if(-not $root.StartsWith($base,[StringComparison]::OrdinalIgnoreCase) -or -not $root.EndsWith('\project\.godot\imported',[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid cache root'}}
function Check-File([string]$path,[long]$expectedSize,[string]$expectedHash){
 $full=[IO.Path]::GetFullPath($path)
 if($full -cne $path){throw "Noncanonical path: $path"}
 $item=Get-Item -LiteralPath $full -Force
 if($item.PSIsContainer -or $item.Length -ne $expectedSize){throw "Changed file: $full"}
 for($a=$item;$null -ne $a;$a=if($a -is [IO.FileInfo]){$a.Directory}else{$a.Parent}){if(($a.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse ancestor: $full"}}
 $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
 try{
  if([CacheLinkCheck20]::Links($stream.SafeFileHandle) -ne 1){throw "Hard linked file: $full"}
  $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
  if($digest -ne $expectedHash){throw "SHA changed: $full"}
 }finally{$stream.Dispose()}
}
$targetPaths=@{};foreach($row in $plan.targets){$targetPaths[[string]$row.path]=$true}
$keeperChecked=@{}
foreach($row in $plan.targets){
 $path=[IO.Path]::GetFullPath([string]$row.path)
 $matched=@($allowed|Where-Object {$path.StartsWith($_+'\',[StringComparison]::OrdinalIgnoreCase)})
 if($matched.Count -ne 1){throw "Outside exact allowlist: $path"}
 $keeper=[IO.Path]::GetFullPath([string]$row.retained_copy)
 if($targetPaths.ContainsKey($keeper)){throw 'Keeper is a deletion target'}
 $keeperAllowed=$keeper.StartsWith($base+'imported\',[StringComparison]::OrdinalIgnoreCase) -or @($allowed|Where-Object {$keeper.StartsWith($_+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 1
 if(-not $keeperAllowed){throw 'Keeper outside cache scope'}
 Check-File $path ([long]$row.bytes) ([string]$row.sha256)
 if(-not $keeperChecked.ContainsKey($keeper)){Check-File $keeper ([long]$row.bytes) ([string]$row.sha256);$keeperChecked[$keeper]=$true}
}
Assert-Idle
$writer=[IO.StreamWriter]::new((Join-Path $TaskRoot 'deleted.jsonl'),$false,[Text.UTF8Encoding]::new($false))
$count=0;$bytes=[long]0
try{
 foreach($row in $plan.targets){
  if($count % 100 -eq 0){Assert-Idle}
  Remove-Item -LiteralPath ([string]$row.path) -Force -ErrorAction Stop
  $writer.WriteLine(($row|ConvertTo-Json -Compress));$writer.Flush();$count++;$bytes+=[long]$row.bytes
 }
}finally{$writer.Dispose()}
[pscustomobject]@{deleted_files=$count;logical_bytes=$bytes}|ConvertTo-Json
