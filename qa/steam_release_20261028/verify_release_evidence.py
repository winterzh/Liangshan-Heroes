"""Verify archived original bytes and emit the exact release commit whitelist."""
from pathlib import Path
import ast,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(name):return json.loads((HERE/name).read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths=set()
for row in read('evidence_copy_manifest.json')['files']+read('gui_observations.json')['files']:
    p=HERE/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],str(p)
    paths.add(p)
top=['README.md','release_plan.json','candidate_delivery.json','evidence_copy_manifest.json',
 'gui_observations.json','patch_notes_draft.json','announcement_saved_languages_verified.json',
 'steampipe_mapping_prepared.json','upload_pending_readback.json','collect_evidence.py','collect_gui_observations.py',
 'smoke_verified_package.py','run_gui_acceptance.py','prepare_steampipe.py','verify_release_evidence.py']
for name in top:paths.add(HERE/name)
for p in paths:
    assert p.is_file() and p.stat().st_size<20_000_000,str(p)
    assert p.suffix not in ('.exe','.dll','.zip','.pck','.vdf','.cfg') and p.name!='private_profile.json',str(p)
    if p.suffix=='.py':ast.parse(p.read_text(encoding='utf8'),filename=str(p))
    if p.suffix=='.json':json.loads(p.read_bytes())
    if p.suffix=='.log':assert not re.search(r'SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed',p.read_text(encoding='utf8',errors='replace')),str(p)
rows=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(paths)]
manifest={'complete':True,'scope':'release preparation and evidence only; no upload/default claim',
 'files':rows,'file_count':len(rows),'bytes':sum(x['bytes'] for x in rows)}
(HERE/'commit_whitelist.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'complete':True,'files':len(rows),'bytes':manifest['bytes']}))
