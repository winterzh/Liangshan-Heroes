import os, json, gzip, hashlib, subprocess, shutil, concurrent.futures, time
from pathlib import Path
from prepare_archive import ROOT, OUT, digest

def main():
    start=time.time()
    removed=[]
    with gzip.open(OUT/'removed.jsonl.gz','rt',encoding='utf-8') as f:
        removed=[json.loads(line) for line in f]
    still_present=[row['path'] for row in removed if os.path.lexists('\\\\?\\'+str(ROOT/row['path']))]
    if still_present:
        raise RuntimeError('Deleted paths reappeared: '+str(still_present[:3]))
    with gzip.open(OUT/'protected_before.jsonl.gz','rt',encoding='utf-8') as f:
        protected=[json.loads(line) for line in f]
    def compare(before):
        try:
            after=digest(before['path'])
            if (before['bytes'],before['sha256']) != (after['bytes'],after['sha256']):
                return {'path':before['path'],'reason':'size_or_sha_changed'}
        except Exception as e:
            return {'path':before['path'],'reason':str(e)}
    issues=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for i,result in enumerate(pool.map(compare,protected),1):
            if result: issues.append(result)
            if i%50000==0:print(json.dumps({'protected_verified':i,'issues':len(issues),'elapsed_s':round(time.time()-start)}),flush=True)
    before=json.loads((OUT/'git_before.json').read_text(encoding='utf-8'))
    def git(*args):return subprocess.check_output(['git','-c','core.quotepath=false',*args],cwd=ROOT,stderr=subprocess.DEVNULL).decode('utf-8')
    status_same=git('status','--porcelain=v1','-uall')==before['status']
    diff_same=git('diff','--binary')==before['diff']
    index_same=git('diff','--cached','--name-only')==before['index']
    head_same=git('rev-parse','HEAD')==before['head']
    archive=json.loads((OUT/'archive_verification.json').read_text(encoding='utf-8'))
    with open(archive['archive'],'rb') as f:archive_same=hashlib.file_digest(f,'sha256').hexdigest()==archive['archive_sha256']
    summary={'protected_files':len(protected),'protected_issues':issues,'removed_files':len(removed),
             'removed_bytes':sum(r['bytes'] for r in removed),'removed_paths_absent':not still_present,
             'git_status_unchanged':status_same,'git_working_diff_unchanged':diff_same,'git_index_unchanged':index_same,
             'git_head_unchanged_before_documentation':head_same,'archive_sha_unchanged':archive_same,
             'free_bytes_after_cleanup':shutil.disk_usage(ROOT).free,'elapsed_s':round(time.time()-start)}
    (OUT/'verification_before_docs.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False),flush=True)
    if issues or not all([status_same,diff_same,index_same,head_same,archive_same]):raise RuntimeError('Protection verification failed')

if __name__=='__main__':main()
