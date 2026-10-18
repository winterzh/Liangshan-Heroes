"""Archive raw accepted evidence and apply only the exact two qualified files."""
from pathlib import Path
import hashlib,importlib.util,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/wu_yong_layered_full_pack_20261019')
U=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit_v2')
spec=importlib.util.spec_from_file_location('wu_adopt_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py')
identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not (Q/'production_adoption.json').exists()
receipt_path=Path(json.loads((E/'latest.json').read_text())['receipt']);receipt=json.loads(receipt_path.read_text())
assert receipt['complete'] and receipt['identity_checks']==6 and receipt['visual_checks']==174 and receipt['screenshots']==45 and receipt['normal_release_exit_passed']
O=receipt_path.parent;P=Path(receipt['project']);generation=json.loads((U/'generation.json').read_text())
identity.verify_generated(P,generation);assert identity.snapshot(R)==json.loads((U/'root_before.json').read_text())
selected=[]
for name in ['receipt.json','generation.json','expected_identity.json','identity_report.json','full_export.log','compiled_identity.log','compiled_visual.log']:
    selected.append(O/name)
for directory in ['visual','qa']:
    selected.extend(p for p in sorted((O/directory).rglob('*')) if p.is_file())
selected.append(O/'normal_release/normal_release_480_frames.log')
A=Q/'actual_package';A.mkdir();archives=[]
for source in selected:
    rel=source.relative_to(O);target=A/rel
    if target.suffix=='.gd':target=target.with_suffix('.gd.txt')
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target);assert sha(source)==sha(target)
    archives.append({'original':str(source),'archive':target.relative_to(A).as_posix(),'bytes':source.stat().st_size,'sha256':sha(source)})
save(A/'archive_index.json',archives)
for name in ['state.json','stdout.log','stderr.log']:
    source=E/'queue'/name;target=Q/('completed_queue_'+name);shutil.copyfile(source,target);assert sha(source)==sha(target)
candidate=json.loads((R/'qa/wu_yong_push_gait_20261018/integration_candidate.json').read_text())
before=json.loads((R/'qa/chao_gai_layered_full_pack_20261018/runtime_after_adoption.json').read_text())
assert all(sha(R/x['path'])==x['sha256'] for x in before)
for rel in ['qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    assert all(sha(R/x['path'])==x['sha256'] for x in json.loads((R/rel).read_text()))
for row in candidate['files']:
    name=row['path'];assert sha(R/name)==row['before_sha256'];assert sha(P/name)==row['candidate_sha256']
for row in candidate['files']:
    shutil.copyfile(P/row['path'],R/row['path']);assert sha(R/row['path'])==row['candidate_sha256']
old={x['path']:x['sha256'] for x in before};changed=sorted(p for p in old if sha(R/p)!=old[p])
assert changed==['scripts/campaign_art.gd','scripts/unit.gd']
paths=set(old)
paths.update(p.relative_to(R).as_posix() for p in (R/'assets/characters/wu_yong_layered_20261018').iterdir() if p.is_file())
paths.update(p.relative_to(R).as_posix() for p in (R/'assets/anim').glob('wu_yong_layered_20261018_*.tres'))
paths.add('assets/direction4/level1_wu_yong_layered_20261018.json');assert len(paths)==129
save(Q/'runtime_after_adoption.json',[{'path':p,'sha256':sha(R/p),'bytes':(R/p).stat().st_size} for p in sorted(paths)])
after=identity.snapshot(R);private={x['path']:x['sha256'] for x in generation['identity']['files']}
assert all(private[x['path']]==x['sha256'] for x in after['files'])
save(Q/'root_private_source_relation.json',{'root_source_sha256':after['source_sha256'],'root_files':len(after['files']),'qualified_private_source_sha256':generation['identity']['source_sha256'],'qualified_private_files':len(private),'common_changed':[],'private_only':sorted(set(private)-{x['path'] for x in after['files']}),'scope':'All common canonical input bytes match. Private native dependencies and import/UID descriptors remain private; not an assertion of identical root/private input inventories.'})
save(Q/'production_adoption.json',{'adopted':True,'files':candidate['files'],'qualification_receipt':str(receipt_path),'qualification_receipt_sha256':sha(receipt_path),'checks':{'source_unit':144,'package_identity':6,'package_art':174},'package_screenshots':45,'package_directly_viewed':25,'source_unit_directly_viewed':33,'root_common_input_match':True,'runtime_baseline_files':129,'full_goal_complete':False,'steam_published':False,'main_merged':False,'scope':'Wu Yong loaded actor/cart art routing only, exact two tested source files. Existing chapter/attributes/portrait/combat fallback unchanged. Continuous gait, hidden hand contact, wheel animation, wine/save/full-chapter/performance/human/Steam acceptance remain open.'})
print(json.dumps({'adopted':True,'files':changed,'baseline':len(paths),'archived':len(archives)}))
