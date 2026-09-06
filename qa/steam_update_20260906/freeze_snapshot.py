"""Freeze committed Windows runtime inputs for a Steam test update; no upload.

This does not relax or claim passage of the repository's commercial release gate.
Frozen bytes come from Git objects, not uncommitted or ignored working files.
"""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, shutil, subprocess

COMMIT = '954ffde683e79fe90656e5acba78692bc5de67b8'
BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
CORE = {'project.godot', 'export_presets.cfg', 'icon.png', 'icon.png.import', 'icon.ico'}
RUNTIME = ('assets/anim/', 'assets/campaign/anim/', 'assets/campaign/objects/',
           'assets/campaign/portraits/', 'assets/campaign/environment/', 'assets/vfx/',
           'assets/characters/')

def sha(b): return hashlib.sha256(b).hexdigest()
def allowed(p):
    q = PurePosixPath(p)
    if p in CORE: return True
    if p.startswith('scripts/'):
        return q.suffix in {'.gd', '.gdshader', '.uid'}
    if p.startswith('scenes/'): return q.suffix == '.tscn'
    if q.parent == PurePosixPath('assets'):
        return '_raw' not in q.name and (p.endswith('.png') or p.endswith('.png.import'))
    if p.startswith('assets/ui/'):
        return '/atlases/' not in p and (p.endswith('.png') or p.endswith('.png.import'))
    if p.startswith(RUNTIME):
        return (p.endswith('.png') or p.endswith('.png.import') or p.endswith('.tres')) and '_raw' not in q.name
    return False

def inventory():
    result = subprocess.check_output(['git','ls-tree','-rz','--full-tree',COMMIT],cwd=ROOT)
    rows=[]
    for item in result.split(b'\0'):
        if not item: continue
        info,name=item.split(b'\t',1); mode,kind,oid=info.decode().split(); p=name.decode('utf8')
        if allowed(p):
            assert mode in ('100644','100755') and kind=='blob',p
            rows.append({'path':p,'git_blob':oid})
    paths={r['path'] for r in rows}
    for p in paths:
        if p.endswith('.png'): assert p+'.import' in paths,p
    assert sum(p.endswith('.tres') and PurePosixPath(p).name.startswith(('song_jiang_','lin_chong_')) for p in paths)==36
    return sorted(rows,key=lambda r:r['path'])

def freeze():
    target=BASE/'source'; project=BASE/'project'
    assert not target.exists() and not project.exists(),'Refusing to overwrite prior snapshot'
    target.mkdir(parents=True)
    rows=inventory()
    process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    for row in rows:
        process.stdin.write((row['git_blob']+'\n').encode()); process.stdin.flush()
        header=process.stdout.readline().decode().strip().split()
        assert header[0]==row['git_blob'] and header[1]=='blob',header
        size=int(header[2]); data=process.stdout.read(size); assert process.stdout.read(1)==b'\n'
        assert len(data)==size
        output=target/row['path']; output.parent.mkdir(parents=True,exist_ok=True); output.write_bytes(data)
        row.update(size_bytes=size,sha256=sha(data))
    process.stdin.close(); assert process.wait()==0
    tree=sha('\n'.join(f"{r['path']}\0{r['size_bytes']}\0{r['sha256']}" for r in rows).encode())
    receipt={'schema':1,'kind':'steam_windows_update_committed_runtime_snapshot','source_commit':COMMIT,
             'source_tree_sha256':tree,'file_count':len(rows),'size_bytes':sum(r['size_bytes'] for r in rows),
             'source':str(target),'project':str(project),'files':rows,
             'scope':'Windows test/update snapshot. Does not alter or assert passage of commercial art/readiness gates.',
             'excludes':['tools','qa','docs','raw/source art','generation drafts','credentials','player data','Godot cache'],
             'additional_runtime_inputs':['assets/anim/*.tres','assets/characters/*','assets/ui current icons and splash'],
             'known_environment_fallbacks':'Existing missing optional environment entries retain runtime fallback; no replacement assets fabricated.'}
    (BASE/'source_manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    shutil.copytree(target,project)
    print(json.dumps({k:v for k,v in receipt.items() if k!='files'},ensure_ascii=False,indent=2))

def verify():
    d=json.loads((BASE/'source_manifest.json').read_text(encoding='utf8'))
    differences=[]; importer_changes=[]
    for r in d['files']:
        assert sha((BASE/'source'/r['path']).read_bytes())==r['sha256'],r['path']
        p=BASE/'project'/r['path']
        actual=sha(p.read_bytes()) if p.is_file() else None
        if actual!=r['sha256']:
            row={'path':r['path'],'source_sha256':r['sha256'],'imported_sha256':actual}
            (importer_changes if r['path'].endswith('.png.import') else differences).append(row)
    expected={r['path'] for r in d['files']}
    extras=[p.relative_to(BASE/'project').as_posix() for p in (BASE/'project').rglob('*') if p.is_file() and '.godot' not in p.relative_to(BASE/'project').parts and p.relative_to(BASE/'project').as_posix() not in expected]
    forbidden=[p for p in extras if not p.endswith('.uid')]
    report={'passed':not differences and not forbidden,'source_commit':COMMIT,'file_count':len(d['files']),
            'immutable_source_verified':True,'production_differences':differences,'importer_sidecar_changes':importer_changes,
            'generated_uids':extras,'forbidden_extra_files':forbidden}
    (BASE/'source_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report,ensure_ascii=False,indent=2)); assert report['passed']

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['freeze','verify']);args=parser.parse_args()
    freeze() if args.mode=='freeze' else verify()
