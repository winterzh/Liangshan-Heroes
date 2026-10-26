import os,json,gzip,subprocess,concurrent.futures,time,shutil
from pathlib import Path
from prepare_duplicates import ROOT,OUT,hash_file

def main():
    start=time.time()
    with gzip.open(OUT/'removed.jsonl.gz','rt',encoding='utf-8') as f:removed=[json.loads(line) for line in f]
    removed_paths={r['path'] for r in removed}
    with gzip.open(OUT/'protected_before.json.gz','rt',encoding='utf-8') as f:protected=json.load(f)
    issues=[]
    def check(row):
        try:
            after=hash_file(row['path'])
            if (after['bytes'],after['sha256'])!=(row['bytes'],row['sha256']):return row['path']+': SHA/size changed'
        except Exception as e:return row['path']+': '+str(e)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for i,result in enumerate(pool.map(check,protected),1):
            if result:issues.append(result)
            if i%15000==0:print(json.dumps({'sha_verified':i,'issues':len(issues),'elapsed_s':round(time.time()-start)}),flush=True)
    with gzip.open(OUT/'inventory_before.json.gz','rt',encoding='utf-8') as f:before=json.load(f)
    old={p:(n,mt) for p,n,mt in before['files'] if not p.startswith('开发工程/.git/') and p.removeprefix('开发工程/') not in removed_paths}
    current={};scan_issues=[];root=Path(before['root'])
    for base,dirs,names in os.walk('\\\\?\\'+str(root),followlinks=False):
        for name in dirs[:]:
            p=os.path.join(base,name)
            if os.stat(p,follow_symlinks=False).st_file_attributes&0x400:dirs.remove(name)
        for name in names:
            p=os.path.join(base,name);s=os.stat(p,follow_symlinks=False)
            if s.st_file_attributes&0x400:continue
            rel=Path(p[4:]).relative_to(root).as_posix()
            if rel.startswith('开发工程/.git/'):continue
            current[rel]=(s.st_size,s.st_mtime_ns)
    for path,meta in old.items():
        if current.get(path)!=meta:scan_issues.append(path)
    unexpected=sorted(set(current)-set(old))
    before_git=json.loads((OUT/'git_before.json').read_text(encoding='utf-8'))
    def git(*args):return subprocess.check_output(['git','-c','core.quotepath=false',*args],cwd=ROOT,stderr=subprocess.DEVNULL).decode('utf-8')
    result={'removed_files':len(removed),'removed_bytes':sum(r['bytes'] for r in removed),'sha_protected_files':len(protected),'sha_issues':issues,'metadata_protected_files':len(old),'metadata_issues':scan_issues,'unexpected_paths':unexpected,'all_targets_absent':all('开发工程/'+p not in current for p in removed_paths),'git_head_unchanged':git('rev-parse','HEAD')==before_git['head'],'git_status_unchanged':git('status','--porcelain=v1','-uall')==before_git['status'],'git_diff_unchanged':git('diff','--binary')==before_git['diff'],'git_index_unchanged':git('diff','--cached','--name-only')==before_git['index'],'main_directory_bytes_before':before['bytes'],'main_directory_bytes_after_excluding_git':sum(v[0] for v in current.values()),'drive_d_free_bytes':shutil.disk_usage(ROOT).free,'elapsed_s':round(time.time()-start)}
    (OUT/'verification_before_docs.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False),flush=True)
    if issues or scan_issues or unexpected or not all(result[k] for k in ['all_targets_absent','git_head_unchanged','git_status_unchanged','git_diff_unchanged','git_index_unchanged']):raise RuntimeError('Protection verification failed')

if __name__=='__main__':main()
