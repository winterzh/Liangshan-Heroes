import os,json,gzip,hashlib,subprocess,time,collections,concurrent.futures
from pathlib import Path
ROOT=Path(r'D:\AI项目\水浒\开发工程')
OUT=Path(r'D:\CodexTemp\shuihu-cleanup-20261026-round2')

def git(*args):return subprocess.check_output(['git','-c','core.quotepath=false',*args],cwd=ROOT,stderr=subprocess.DEVNULL)
def hash_file(rel):
    path='\\\\?\\'+str(ROOT/rel);s=os.stat(path,follow_symlinks=False)
    if s.st_file_attributes&0x400:raise RuntimeError('Reparse file: '+rel)
    with open(path,'rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
    t=os.stat(path,follow_symlinks=False)
    if (s.st_size,s.st_mtime_ns,s.st_ino)!=(t.st_size,t.st_mtime_ns,t.st_ino):raise RuntimeError('Changed while hashing: '+rel)
    return {'path':rel,'bytes':s.st_size,'sha256':sha,'mtime_ns':s.st_mtime_ns,'utc_ticks':s.st_mtime_ns//100+621355968000000000,'links':s.st_nlink}
def write_gz(name,data):
    with gzip.open(OUT/name,'wt',encoding='utf-8') as f:json.dump(data,f,ensure_ascii=False,separators=(',',':'))
def sha_file(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    started=time.time();before=json.loads((OUT/'git_before.json').read_text(encoding='utf-8'))
    assert git('rev-parse','HEAD').decode()==before['head'] and not git('diff','--cached','--name-only').strip()
    roots=json.loads((OUT/'candidate_roots.json').read_text(encoding='utf-8'))
    with gzip.open(OUT/'inventory_before.json.gz','rt',encoding='utf-8') as f:inventory=json.load(f)
    source_files=[rel[len('开发工程/'):] for rel,_,_ in inventory['files'] if rel.startswith('开发工程/')]
    candidates=[];cache_paths=[]
    for rel in source_files:
        match=[root for root in roots if rel.startswith(root+'/')]
        if not match:continue
        tail=rel[len(match[0])+1:]
        (cache_paths if '.godot' in tail.split('/') else candidates).append(rel)
    tracked={}
    for record in git('ls-files','--stage','-z').split(b'\0'):
        if not record:continue
        meta,path=record.split(b'\t',1);mode,blob,stage=meta.decode().split()
        if stage!='0':raise RuntimeError('Conflicted index')
        if mode in ('100644','100755'):tracked[path.decode('utf-8')]=blob
    dirty=set(git('diff','--name-only','-z').decode().strip('\0').split('\0'))
    eligible={p:b.decode() if isinstance(b,bytes) else b for p,b in tracked.items() if p not in dirty and
              (p.startswith(('assets/','scripts/','scenes/','native/','vendor/')) or p in ['project.godot','export_presets.cfg','icon.png','icon.png.import','icon.ico','icon.svg','icon.svg.import'])}
    pending=[s[3:] for s in before['status'].splitlines()]
    protected_paths=sorted(set(tracked)|set(cache_paths)|set(pending))
    all_hash_paths=sorted(set(candidates)|set(protected_paths))
    print(json.dumps({'phase':'hash_sources_and_protected','files':len(all_hash_paths),'candidates':len(candidates),'protected':len(protected_paths)}),flush=True)
    hashed={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for i,row in enumerate(pool.map(hash_file,all_hash_paths),1):
            hashed[row['path']]=row
            if i%15000==0:print(json.dumps({'hashed':i,'elapsed_s':round(time.time()-started)}),flush=True)
    byhash=collections.defaultdict(list)
    for rel,blob in eligible.items():byhash[hashed[rel]['sha256']].append((rel,blob))
    possible={}
    for rel in candidates:
        row=hashed[rel]
        if row['links']!=1:raise RuntimeError('Hardlinked candidate: '+rel)
        for keeper,blob in byhash.get(row['sha256'],[]):possible[blob]=keeper
    proc=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    git_hashes={}
    for blob in sorted(possible):
        proc.stdin.write((blob+'\n').encode());proc.stdin.flush();header=proc.stdout.readline().decode().split()
        if len(header)!=3 or header[1]!='blob':raise RuntimeError('Missing Git blob: '+blob)
        remain=int(header[2]);digest=hashlib.sha256();prefix=b''
        while remain:
            block=proc.stdout.read(min(remain,1024*1024))
            if not block:raise RuntimeError('Truncated Git blob')
            if len(prefix)<100:prefix=(prefix+block)[:100]
            digest.update(block);remain-=len(block)
        if proc.stdout.read(1)!=b'\n':raise RuntimeError('Git batch framing')
        if not prefix.startswith(b'version https://git-lfs.github.com/spec/'):
            git_hashes[blob]=digest.hexdigest()
    proc.stdin.close()
    if proc.wait()!=0:raise RuntimeError('git cat-file failed')
    targets=[];keepers={};retained=[]
    for rel in candidates:
        row=hashed[rel];matches=[(p,b) for p,b in byhash.get(row['sha256'],[]) if git_hashes.get(b)==row['sha256']]
        if not matches:retained.append(row);continue
        keeper,blob=matches[0];root=next(root for root in roots if rel.startswith(root+'/'))
        targets.append({**row,'root':root,'retained_copy':keeper,'git_blob':blob,'git_commit':before['head'].strip()})
        keepers[keeper]={**hashed[keeper],'git_blob':blob,'git_blob_sha256':git_hashes[blob]}
    protected=[hashed[p] for p in protected_paths]+retained
    write_gz('protected_before.json.gz',protected);write_gz('retained_unique.json.gz',retained)
    write_gz('keepers.json.gz',list(keepers.values()))
    with gzip.open(OUT/'plan.jsonl.gz','wt',encoding='utf-8') as f:
        for row in targets:f.write(json.dumps(row,ensure_ascii=False,separators=(',',':'))+'\n')
    binding={'plan_sha256':sha_file(OUT/'plan.jsonl.gz'),'keepers_sha256':sha_file(OUT/'keepers.json.gz'),'git_head':before['head'].strip(),'target_files':len(targets),'target_bytes':sum(r['bytes'] for r in targets),'unique_keepers':len(keepers),'all_git_blob_sha256_verified':True,'protected_sha_files':len(protected),'retained_unique_files':len(retained),'retained_unique_bytes':sum(r['bytes'] for r in retained),'candidate_files':len(candidates),'candidate_bytes':sum(hashed[p]['bytes'] for p in candidates),'elapsed_s':round(time.time()-started)}
    (OUT/'plan_binding.json').write_text(json.dumps(binding,indent=2),encoding='utf-8')
    print(json.dumps(binding),flush=True)

if __name__=='__main__':main()
