param([string]$TaskRoot='D:\CodexTemp\shuihu-cleanup-20261026-round2')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath('D:\AI项目\水浒\开发工程')
$binding=Get-Content -LiteralPath (Join-Path $TaskRoot 'plan_binding.json') -Raw|ConvertFrom-Json
$recovery=Get-Content -LiteralPath (Join-Path $TaskRoot 'actual_restore_verification.json') -Raw|ConvertFrom-Json
if(-not $binding.all_git_blob_sha256_verified -or -not $recovery.verified -or $recovery.restored_files -lt 1){throw 'Recovery proof incomplete'}
if((git -C $project rev-parse HEAD).Trim() -ne $binding.git_head){throw 'Git HEAD changed'}
$plan=Join-Path $TaskRoot 'plan.jsonl.gz';$keepers=Join-Path $TaskRoot 'keepers.json.gz'
if((Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binding.plan_sha256 -or (Get-FileHash -LiteralPath $keepers -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binding.keepers_sha256){throw 'Plan or keeper proof changed'}
$journal=Join-Path $TaskRoot 'removed.jsonl.gz'
if(Test-Path -LiteralPath $journal){throw 'Journal exists; inspect before resume'}
$roots=[string[]](Get-Content -LiteralPath (Join-Path $TaskRoot 'candidate_roots.json') -Raw|ConvertFrom-Json)
Add-Type @'
using System;using System.IO;using System.IO.Compression;using System.Collections.Generic;using System.Collections.Concurrent;using System.Diagnostics;using System.Linq;using System.Runtime.InteropServices;using System.Security.Cryptography;using System.Text;using System.Text.Json;using System.Threading;using System.Threading.Tasks;using Microsoft.Win32.SafeHandles;
public static class VerifiedDuplicateRemoval26 {
 [StructLayout(LayoutKind.Sequential)] public struct Info {public uint Attributes;public System.Runtime.InteropServices.ComTypes.FILETIME Creation,Access,Write;public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow;}
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info i);
 static void Idle(){foreach(var p in Process.GetProcesses()){using(p){try{if(p.ProcessName.StartsWith("Godot",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Godot started; stop cleanup");}catch(ArgumentException){}}}}
 static void SafeParents(string path){for(var d=new DirectoryInfo(path);d!=null;d=d.Parent){if((d.Attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("Reparse ancestor");}}
 static IEnumerable<string> Lines(string path){using(var file=File.OpenRead(path))using(var zip=new GZipStream(file,CompressionMode.Decompress))using(var reader=new StreamReader(zip,Encoding.UTF8)){string line;while((line=reader.ReadLine())!=null)yield return line;}}
 static void CheckFile(string path,long size,long ticks,string sha,bool requireSingleLink){
  SafeParents(Path.GetDirectoryName(path));var info=new FileInfo(path);
  if(!info.Exists||(info.Attributes&FileAttributes.ReparsePoint)!=0||info.Length!=size||info.LastWriteTimeUtc.Ticks!=ticks)throw new IOException("File missing or metadata changed");
  using(var input=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.None,131072,FileOptions.SequentialScan)){
   Info details;if(!GetFileInformationByHandle(input.SafeFileHandle,out details)||(requireSingleLink&&details.Links!=1))throw new IOException("Hard link or handle error");
   if(Convert.ToHexString(SHA256.HashData(input)).ToLowerInvariant()!=sha)throw new IOException("Content changed");
  }
 }
 public static string Run(string project,string[] roots,string plan,string keeperFile,string journal){
  Idle();var allowed=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach(var rel in roots){var r=Path.GetFullPath(Path.Combine(project,rel));if(!r.StartsWith(project+"\\.godot\\",StringComparison.OrdinalIgnoreCase)||!r.EndsWith("\\project",StringComparison.OrdinalIgnoreCase))throw new IOException("Invalid root");SafeParents(r);allowed.Add(r);}
  var keeperProof=new Dictionary<string,Tuple<long,long,string>>(StringComparer.OrdinalIgnoreCase);
  using(var file=File.OpenRead(keeperFile))using(var gz=new GZipStream(file,CompressionMode.Decompress))using(var doc=JsonDocument.Parse(gz)){
   foreach(var row in doc.RootElement.EnumerateArray()){
    var path=Path.GetFullPath(Path.Combine(project,row.GetProperty("path").GetString()));
    if(!path.StartsWith(project+"\\",StringComparison.OrdinalIgnoreCase)||allowed.Any(r=>path.StartsWith(r+"\\",StringComparison.OrdinalIgnoreCase)))throw new IOException("Keeper outside retained source scope");
    long size=row.GetProperty("bytes").GetInt64(),ticks=row.GetProperty("utc_ticks").GetInt64();string sha=row.GetProperty("sha256").GetString();
    if(sha!=row.GetProperty("git_blob_sha256").GetString())throw new IOException("Git bytes mismatch");
    CheckFile(path,size,ticks,sha,false);keeperProof.Add(path,Tuple.Create(size,ticks,sha));
   }
  }
  Idle();long seen=0,removed=0,bytes=0;var skipped=new ConcurrentBag<object>();var sync=new object();
  using(var file=new FileStream(journal,FileMode.CreateNew,FileAccess.Write,FileShare.Read))using(var gz=new GZipStream(file,CompressionLevel.Fastest))using(var writer=new StreamWriter(gz,new UTF8Encoding(false))){
   Parallel.ForEach(Lines(plan),new ParallelOptions{MaxDegreeOfParallelism=6},line=>{
    var n=Interlocked.Increment(ref seen);if(n%2000==1)Idle();string rel="";
    try{using(var doc=JsonDocument.Parse(line)){
     var row=doc.RootElement;rel=row.GetProperty("path").GetString();var root=Path.GetFullPath(Path.Combine(project,row.GetProperty("root").GetString()));var path=Path.GetFullPath(Path.Combine(project,rel));
     if(!allowed.Contains(root)||!path.StartsWith(root+"\\",StringComparison.OrdinalIgnoreCase)||path.Substring(root.Length+1).Split('\\').Contains(".godot"))throw new IOException("Outside exact noncache allowlist");
     var keeper=Path.GetFullPath(Path.Combine(project,row.GetProperty("retained_copy").GetString()));var proof=keeperProof[keeper];
     var k=new FileInfo(keeper);if(!k.Exists||k.Length!=proof.Item1||k.LastWriteTimeUtc.Ticks!=proof.Item2||proof.Item3!=row.GetProperty("sha256").GetString())throw new IOException("Keeper changed");
     long size=row.GetProperty("bytes").GetInt64();CheckFile(path,size,row.GetProperty("utc_ticks").GetInt64(),row.GetProperty("sha256").GetString(),true);
     File.Delete(path);if(File.Exists(path))throw new IOException("File still exists");Interlocked.Increment(ref removed);Interlocked.Add(ref bytes,size);lock(sync){writer.WriteLine(line);}
    }}catch(Exception e){skipped.Add(new{path=rel,reason=e.Message});}
    if(n%5000==0){lock(sync){writer.Flush();Console.WriteLine(JsonSerializer.Serialize(new{seen=n,removed=Interlocked.Read(ref removed),skipped=skipped.Count}));}}
   });
  }
  return JsonSerializer.Serialize(new{seen=seen,removed_files=removed,removed_bytes=bytes,skipped_files=skipped.Count,skipped=skipped.ToArray(),verified_keepers=keeperProof.Count});
 }
}
'@
$result=[VerifiedDuplicateRemoval26]::Run($project,$roots,$plan,$keepers,$journal)
$result|Set-Content -LiteralPath (Join-Path $TaskRoot 'removal_summary.json') -Encoding utf8
$result
