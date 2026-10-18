from pathlib import Path
import collections,hashlib,json,shutil,subprocess
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;Q=R/'qa/tribute_cart_wheel_unit_20261018'
P=E/'game_iteration2/20261018_123317_09efa112/evidence'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
d=read(P/'receipt.json');report=read(P/'visual/report.json')
assert d['complete'] and d['lock_released'] and not report['failures'] and len(report['checks'])>=1686
assert len(d['pack_chain'])==12 and d['screenshots']==144
for key in ['source_changes','private_source_changes','source_owner_changes']:assert not d[key]
old=read(R/'qa/ground_attack_range_20261018/native/report.json')
oldnames=collections.Counter(x['name'] for x in old['checks']);names=collections.Counter(x['name'] for x in report['checks'])
assert not oldnames-names
oldrefs=read(R/'qa/ground_attack_range_20261018/native/texture_references.json');refs=read(P/'texture_references.json')
assert len(oldrefs)==176 and len(refs)==179 and all(refs[k]==v for k,v in oldrefs.items())
for p in sorted(P.iterdir()):
    if p.is_file() and p.suffix in ['.json','.log']:copy(p,Q/'actual_native'/p.name)
copy(P/'visual/report.json',Q/'actual_native/report.json')
copy(R/'tools/run_ruan_xiaoqi_layered_20261018.py',Q/'actual_native/actual_runner.py')
save(Q/'actual_native/screenshots.json',report['screenshots'])
save(Q/'retained_checks.json',{'old':len(old['checks']),'current':len(report['checks']),'added':sum((names-oldnames).values()),'removed':list((oldnames-names).elements()),'retained_native_textures':176,'new_native_textures':3,'previous_native_texture_drift':[]})
direct=read(E/'independent_phase_direct_review.json')
index={x['path']:x for x in report['screenshots']}
for name in direct['directly_viewed']:
    assert name in index and sha(P/'visual'/name)==index[name]['sha256']
save(Q/'actual_native/direct_review.json',direct)
for name in ['wheel_actual_se_phase_a.png','wheel_actual_se_phase_b.png','actual_push_walk_nw.png','wheel_actual_stopped_sw.png','range_1280_se_ground.png','parked_attack_ne.png']:
    copy(P/'visual'/name,Q/'screenshots'/name)
canonical={x['path']:x['sha256'] for x in d['generated_identity']['identity']['files']}
uid='scripts/tribute_cart_wheel_visual.gd.uid';private_uid=Path(d['project'])/uid
assert sha(private_uid)==canonical[uid]
before=sha(R/uid)
if before!=canonical[uid]:copy(private_uid,R/uid)
save(Q/'uid_binding.json',{'path':uid,'before_sha256':before,'tested_canonical_sha256':canonical[uid],'current_sha256':sha(R/uid),'binding':'Exact generated UID of successful actual private import; helper code and textures bind by path. No successful private source mutation.'})
oldinv=read(R/'qa/ground_attack_range_20261018/runtime_inventory.json')
paths={x['path'] for x in oldinv}|{'scripts/run_unit_state.gd','scripts/tribute_cart_wheel_visual.gd',uid}
paths|={p.relative_to(R).as_posix() for p in (R/'assets/characters/tribute_cart_wheel_runtime_20261018').iterdir() if p.is_file()}
assert len(paths)==80
frozen={x['path']:x['sha256'] for x in d['source_files']}
inventory=[]
for name in sorted(paths):
    actual=canonical.get(name) if name.endswith('.uid') else frozen.get(name)
    assert sha(R/name)==actual,(name,sha(R/name),actual)
    inventory.append({'path':name,'sha256':actual})
save(Q/'runtime_inventory.json',inventory)
protected_changes=[]
for file in ['protected_preflight.json','unrelated_before.json']:
    rows=read(R/'qa/ruan_xiaoqi_walk_grips_20261018/preservation'/file)
    changes=[dict(x,after_sha256=sha(R/x['path'])) for x in rows if sha(R/x['path'])!=x['sha256']]
    if file=='protected_preflight.json':
        assert [x['path'] for x in changes]==['scripts/run_unit_state.gd']
        protected_changes=changes
        save(Q/'protected_next.json',[{'path':x['path'],'sha256':sha(R/x['path'])} for x in rows])
    else:assert not changes
save(Q/'preservation_closeout.json',{'protected16_intentional_changes':protected_changes,'protected_unchanged':15,'unrelated81_changes':[],'runtime_inventory_files':80,'original_gait_and_dust':read(E/'independent_phase_source_invariants.json'),'intent':'Explicit new omitted visual angle classification/reset; no saved wire field/schema changed. Historical16 snapshot remains unchanged; protected_next pins this one intentional codec delta.'})
for name in ['independent_phase_candidate.json','independent_phase_source_invariants.json']:copy(E/name,Q/name)
copy(Path(__file__),Q/'collect_independent_phase.py')
copy(E/'apply_independent_phase.py',Q/'apply_independent_phase.py')
copy(E/'apply_wheel_game_qa.py',Q/'apply_wheel_game_qa.py')
copy(E/'wheel_game_qa_additions.gd.txt',Q/'wheel_game_qa_additions.gd.txt')
copy(Q/'candidate_unit.patch',Q/'shared_phase_superseded/candidate_unit.patch')
(Q/'candidate_unit.patch').write_bytes(subprocess.check_output(['git','diff','--','scripts/unit.gd'],cwd=R))
archives=[]
for folder in ['game_iteration1/20261018_122624_db897455/evidence','game_iteration2/20261018_123317_09efa112/evidence']:
    path=E/folder/'prior_inputs_non_git.zip';archives.append({'path':str(path),'bytes':path.stat().st_size,'sha256':sha(path)})
save(Q/'external_archives.json',{'retained_zip':archives,'restore':'Exact retained commit1a378937 plus corresponding committed restore mapping and external ZIP into a fresh private directory. Existing source owner and previous packs unchanged. Current private compilation project contains the latest candidate; it is not the old project in place.'})
save(Q/'native_gate.json',{'state':'complete_independent_wheel_unit','checks':len(report['checks']),'screenshots':144,'original1621_retained':True,'new_native_textures':3,'old176_native_textures_unchanged':True,'pack_chain':12,'receipt':'actual_native/receipt.json','runtime_adopted':True,'steam_updated':False,'source_sha256':d['generated_identity']['identity']['source_sha256'],'canonical_files':d['generated_identity']['identity']['file_count'],'frozen_files':len(d['source_files']),'pack_sha256':d['pack_sha256'],'new_patch_bytes':d['pack_bytes'],'scope':'Only actual chapter16 Ruan7 separated cart. Original body gait/dust block exact. One omitted visual wheel angle, reset0 on explicit Unit assignment; no saved payload field. Others6/ground-cart final phase/cloth/7 carts11 loads/all-art/save/performance/Steam remain open.'})
print(json.dumps({'collected':True,'checks':len(report['checks']),'screenshots':144,'runtime_inventory':80,'pack_chain':12},ensure_ascii=False))
