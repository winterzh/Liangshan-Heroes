"""Precise owned scope, raw index-byte checks and protected-file audit."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019')
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
S=Q/'front_sources_sync_scope.json';mode=sys.argv[1]
if mode=='prepare':
    tracked={'docs/WORKLOG.md','docs/SOURCE_SETUP.md','docs/ART_FULL_20260915.md','docs/DIRECTORY_INDEX.md','docs/GONGSUN_SHENG_MOUNTED_SOURCES_20261018.md',Q.relative_to(R).as_posix()+'/README.md'}
    actual={p for p in git('diff','--name-only','-z').decode().split('\0') if p};assert actual==tracked
    assert not git('diff','--cached','--name-only').strip()
    assert git('remote','get-url','origin').decode().strip()=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('branch','--show-current').decode().strip()=='codex/classic30-closeout-20260924'
    added={p for p in git('ls-files','--others','--exclude-standard','-z','--',Q.relative_to(R).as_posix()).decode().split('\0') if p}
    rows=[]
    for name in sorted(tracked|added):
        p=R/name;assert p.is_file() and not p.is_symlink() and p.stat().st_size<25*1024*1024
        assert p.suffix.lower() not in ['.exe','.dll','.pck','.zip','.7z','.key','.pem']
        assert not set(p.relative_to(R).parts)&{'.godot','.git','profile','profiles'}
        raw=p.read_bytes()
        if p.suffix.lower()!='.png':assert not re.search(rb'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|AKIA[A-Z0-9]{16}',raw),name
        rows.append({'path':name,'bytes':len(raw),'sha256':sha(p)})
    with S.open('x',encoding='utf-8') as f:f.write(json.dumps({'head_before':git('rev-parse','HEAD').decode().strip(),'target':'refs/heads/codex/sync-20260905-stable','files':rows,'scope_file_added_separately':S.relative_to(R).as_posix(),'protected_untracked_excluded':81},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'files':len(rows)+1,'bytes':sum(x['bytes'] for x in rows),'largest':max(x['bytes'] for x in rows)}))
elif mode=='stage':
    data=json.loads(S.read_text());assert git('rev-parse','HEAD').decode().strip()==data['head_before']
    assert all(sha(R/x['path'])==x['sha256'] for x in data['files'])
    paths=[x['path'] for x in data['files']]+[S.relative_to(R).as_posix()]
    p=E/'front_sources_sync_paths.nul'
    with p.open('xb') as f:f.write(b'\0'.join(x.encode() for x in paths)+b'\0')
    subprocess.run(['git','add','--pathspec-from-file='+str(p),'--pathspec-file-nul'],cwd=R,check=True)
    print('STAGED',len(paths))
elif mode=='audit':
    data=json.loads(S.read_text());rows=data['files']+[{'path':S.relative_to(R).as_posix(),'sha256':sha(S)}]
    staged={p for p in git('diff','--cached','--name-only','-z').decode().split('\0') if p};assert staged=={x['path'] for x in rows}
    exact=0
    for x in rows:
        assert sha(R/x['path'])==x['sha256']
        if x['path'].startswith('qa/'):
            assert hashlib.sha256(git('show',':'+x['path'])).hexdigest()==x['sha256'],x['path'];exact+=1
    for name in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
        protected=json.loads((R/name).read_text());assert all(sha(R/x['path'])==x['sha256'] and x['path'] not in staged for x in protected)
    print(json.dumps({'exact_QA_index_bytes':exact,'staged_files':len(staged),'runtime_unchanged':True,'unrelated_untracked':81}))
else:raise ValueError(mode)
