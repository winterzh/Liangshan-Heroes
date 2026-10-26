param([string]$TaskRoot='D:\CodexTemp\shuihu-cleanup-20261026')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath('D:\AI项目\水浒\开发工程')
$verification=Get-Content -LiteralPath (Join-Path $TaskRoot 'archive_verification.json') -Raw|ConvertFrom-Json
$prepared=Get-Content -LiteralPath (Join-Path $TaskRoot 'prepare_summary.json') -Raw|ConvertFrom-Json
$restored=Get-Content -LiteralPath (Join-Path $TaskRoot 'restore_actual_verification.json') -Raw|ConvertFrom-Json
$binding=Get-Content -LiteralPath (Join-Path $TaskRoot 'remove_plan_binding.json') -Raw|ConvertFrom-Json
if(-not $verification.all_blob_sha256_passed -or -not $verification.manifest_roundtrip_passed -or -not $restored.verified -or $restored.restored_files -lt 1 -or $prepared.target_files -ne $verification.mapped_files){throw 'Incomplete verification'}
if((Get-FileHash -LiteralPath $verification.archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $verification.archive_sha256 -or $binding.archive_sha256 -ne $verification.archive_sha256 -or $binding.files -ne $verification.mapped_files){throw 'Archive binding mismatch'}
$plan=Join-Path $TaskRoot 'remove_plan.jsonl.gz'
if((Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binding.plan_sha256){throw 'Plan changed'}
$zip=[IO.Compression.ZipFile]::OpenRead([string]$verification.archive)
try{$stream=$zip.GetEntry('manifest.json').Open();try{$sha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()}finally{$stream.Dispose()}}finally{$zip.Dispose()}
if($sha -ne $binding.manifest_sha256){throw 'Manifest binding mismatch'}
$journal=Join-Path $TaskRoot 'removed.jsonl.gz'
if(Test-Path -LiteralPath $journal){throw 'Existing completed/current journal; inspect first'}
$roots=[string[]](Get-Content -LiteralPath (Join-Path $TaskRoot 'candidate_roots.json') -Raw|ConvertFrom-Json)
Add-Type @'
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;
public static class VerifiedArchiveRemoval26 {
 [StructLayout(LayoutKind.Sequential)] public struct Info {public uint Attributes;public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;}
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info i);
 static void Idle(){foreach(var p in Process.GetProcesses()){using(p){try{if(p.ProcessName.StartsWith("Godot",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Godot started; stop cleanup");}catch(ArgumentException){}}}}
 static void SafeParents(string path){for(var d=new DirectoryInfo(path);d!=null;d=d.Parent){if((d.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Reparse ancestor");}}
 static IEnumerable<string> Lines(string path){using(var file=File.OpenRead(path))using(var zip=new GZipStream(file,CompressionMode.Decompress))using(var reader=new StreamReader(zip,Encoding.UTF8)){string line;while((line=reader.ReadLine())!=null)yield return line;}}
 public static string Run(string project,string[] roots,string plan,string journal){
  Idle();var allowed=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach(var rel in roots){var r=Path.GetFullPath(Path.Combine(project,rel));if(!r.StartsWith(project+"\\.godot\\",StringComparison.OrdinalIgnoreCase)||!r.EndsWith("\\project",StringComparison.OrdinalIgnoreCase))throw new IOException("Invalid root");SafeParents(r);allowed.Add(r);}
  long seen=0,removed=0,already=0,bytes=0;var skipped=new ConcurrentBag<object>();var sync=new object();
  using(var file=new FileStream(journal,FileMode.CreateNew,FileAccess.Write,FileShare.Read))using(var zip=new GZipStream(file,CompressionLevel.Fastest))using(var writer=new StreamWriter(zip,new UTF8Encoding(false))){
   Parallel.ForEach(Lines(plan),new ParallelOptions{MaxDegreeOfParallelism=6},line=>{
    var n=Interlocked.Increment(ref seen);if(n%2000==1)Idle();string rel="";
    try{
     using(var doc=JsonDocument.Parse(line)){var row=doc.RootElement;rel=row.GetProperty("path").GetString();var root=Path.GetFullPath(Path.Combine(project,row.GetProperty("root").GetString()));var path=Path.GetFullPath(Path.Combine(project,rel));
      if(!allowed.Contains(root)||!path.StartsWith(root+"\\",StringComparison.OrdinalIgnoreCase))throw new IOException("Outside allowlist");
      if(path.Substring(root.Length+1).Split('\\').Contains(".godot"))throw new IOException("Protected cache subtree");
      SafeParents(Path.GetDirectoryName(path));var expectedBytes=row.GetProperty("bytes").GetInt64();
      if(!File.Exists(path)){Interlocked.Increment(ref already);}
      else{
       var info=new FileInfo(path);if((info.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Reparse file");
       if(info.Length!=expectedBytes||info.LastWriteTimeUtc.Ticks!=row.GetProperty("utc_ticks").GetInt64())throw new IOException("File metadata changed");
       using(var input=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.None,131072,FileOptions.SequentialScan)){
        Info details;if(!GetFileInformationByHandle(input.SafeFileHandle,out details)||details.Links!=1)throw new IOException("Hard link or handle error");
        var digest=Convert.ToHexString(SHA256.HashData(input)).ToLowerInvariant();if(digest!=row.GetProperty("sha256").GetString())throw new IOException("Content changed");
       }
       // Only this verified file is removed; no directory recursion or reparse traversal.
       File.Delete(path);if(File.Exists(path))throw new IOException("File still exists");Interlocked.Increment(ref removed);
      }
      Interlocked.Add(ref bytes,expectedBytes);lock(sync){writer.WriteLine(line);}
     }
    }catch(Exception e){skipped.Add(new{path=rel,reason=e.Message});}
    if(n%20000==0){lock(sync){writer.Flush();Console.WriteLine(JsonSerializer.Serialize(new{seen=n,removed=Interlocked.Read(ref removed),already_absent=Interlocked.Read(ref already),skipped=skipped.Count}));}}
   });
  }
  return JsonSerializer.Serialize(new{seen=seen,removed_files=removed+already,removed_this_pass=removed,already_absent_after_serial_worker=already,removed_bytes=bytes,skipped_files=skipped.Count,skipped=skipped.ToArray()});
 }
}
'@
$result=[VerifiedArchiveRemoval26]::Run($project,$roots,$plan,$journal)
$result|Set-Content -LiteralPath (Join-Path $TaskRoot 'removal_summary.json') -Encoding utf8
$result
