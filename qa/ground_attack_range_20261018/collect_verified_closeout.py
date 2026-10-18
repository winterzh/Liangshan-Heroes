import collections
import hashlib
import json
import pathlib
import shutil

R = pathlib.Path('D:/AI项目/水浒/开发工程')
E = pathlib.Path('D:/CodexEvidence/shuihu/ground_attack_range_20261018')
M = pathlib.Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_20261018')
Q = R / 'qa/ground_attack_range_20261018'
G = R / 'qa/gongsun_sheng_mounted_sources_20261018'
N = E / 'iteration4/native/20261018_120302_6f08b921/evidence'

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def copy(p, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(p, target)
    assert sha(p) == sha(target)
def collect_native(src, dst, visual=False):
    for p in sorted(src.iterdir()):
        if p.is_file() and p.suffix in ('.json', '.log'):
            copy(p, dst/p.name)
    if visual: copy(src/'visual/report.json', dst/'report.json')

d = read(N/'receipt.json'); report = read(N/'visual/report.json')
assert d['complete'] and d['checks'] == 1621 and d['screenshots'] == 132
assert not report['failures'] and all(c['passed'] for c in report['checks'])
old = read(R/'qa/ruan_xiaoqi_walk_grips_20261018/game_native/report.json')
old_checks = collections.Counter(c['name'] for c in old['checks'])
new_checks = collections.Counter(c['name'] for c in report['checks'])
assert not (old_checks-new_checks), old_checks-new_checks
for k in ('source_changes','private_source_changes','source_owner_changes'): assert d[k] == []
assert d['lock_released'] and len(d['pack_chain']) == 10
collect_native(N, Q/'native', visual=True)
write(Q/'native/screenshots.json', report['screenshots'])
copy(pathlib.Path(__file__), Q/'collect_verified_closeout.py')
copy(R/'tools/run_ruan_xiaoqi_layered_20261018.py', Q/'native/actual_runner.py')
write(Q/'retained_checks.json', {'previous':len(old['checks']), 'current':len(report['checks']), 'added':sum((new_checks-old_checks).values()), 'removed':list((old_checks-new_checks).elements()), 'comparison':'Check-name multiset including duplicate cardinalities; all actual current checks passed.'})
direct = ['range_1280_se_ground.png','range_1280_se_top_negative.png','range_1280_sw_ground.png','range_1280_ne_ground.png','range_1280_nw_ground.png','range_960_se_ground.png','range_1920_se_ground.png']
shot_index = {s['path']:s for s in report['screenshots']}
for name in direct: assert sha(N/'visual'/name) == shot_index[name]['sha256']
write(Q/'native/direct_review.json', {'directly_viewed': [shot_index[n] for n in direct], 'finding':'Projected attack ellipse stays below carrier/cart/rear actor. Deliberately top-layer negative visibly crosses face/cart.', 'open':['960 high-zoom mission HUD covers cart','close actor labels overlap','1920 view shows outside map edge','capture FPS is not performance acceptance'], 'review':'Direct image inspection performed before collection; no fresh visual acceptance claimed by this collector.'})
for name in direct[:2]+['range_1280_nw_ground.png']:
    copy(N/'visual'/name, Q/'screenshots'/name)
for tag, path in [('iteration2',E/'iteration2/native/20261018_112949_e920d575/evidence'), ('iteration3',E/'iteration3/native/20261018_113757_08d3e3ff/evidence')]:
    collect_native(path, Q/'history'/tag, visual=(tag=='iteration3'))
for rel in ['failed_parse_source_archive/restore.json','failed_parse2_source_archive/restore.json','restored_after_parse_failure.json','restored_iteration2_after_parse_failure.json','iteration4_candidate.json']:
    copy(E/rel, Q/'history'/rel)
pre = E/'preflight_iteration4/20261018_120154_7ed1a106'
collect_native(pre, Q/'preflight_iteration4')
copy(pre/'lifecycle_probe.gd', Q/'preflight_iteration4/lifecycle_probe.gd.txt')
archive_paths = [N/'prior_inputs_non_git.zip', E/'failed_parse_source_archive/changed_inputs.zip', E/'failed_parse2_source_archive/changed_inputs.zip']
write(Q/'external_archives.json', {'retained_outside_git':[{'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)} for p in archive_paths], 'restore':'Use corresponding committed restore manifests and exact Git blobs plus external ZIP. Do not copy a historical full project over shared current sources. PCKs remain at paths in native/pack_chain.json.'})
old_inventory = read(R/'qa/ruan_xiaoqi_walk_grips_20261018/runtime_inventory.json')
paths = {i['path'] for i in old_inventory} | {'scripts/battle.gd','scripts/ground_range_visual.gd','scripts/ground_range_visual.gd.uid'}
frozen = {i['path']:i['sha256'] for i in d['source_files']}
canonical = {i['path']:i['sha256'] for i in d['generated_identity']['identity']['files']}
inventory = []
for rel in sorted(paths):
    h = sha(R/rel)
    actual = canonical.get(rel) if rel == 'scripts/ground_range_visual.gd.uid' else frozen.get(rel)
    assert actual == h, (rel, h, actual)
    inventory.append({'path':rel,'sha256':h})
assert len(inventory) == 70
write(Q/'runtime_inventory.json', inventory)
preserved = {}
for name in ['protected_preflight.json','unrelated_before.json']:
    p = R/'qa/ruan_xiaoqi_walk_grips_20261018/preservation'/name
    data = read(p)
    rows = data if isinstance(data,list) else data.get('files',data.get('snapshot',[]))
    assert isinstance(rows,list), name
    for row in rows: assert sha(R/row['path']) == row['sha256'], row['path']
    preserved[name] = {'files':len(rows),'changes':[],'basis':str(p.relative_to(R)),'basis_sha256':sha(p)}
write(Q/'preservation_closeout.json', preserved)
write(Q/'native_gate.json', {'state':'complete','receipt':'native/receipt.json','checks':1621,'screenshots':132,'original_1576_retained':True,'runtime_source_sha256':d['generated_identity']['identity']['source_sha256'],'canonical_files':6974,'frozen_files':6982,'pack_chain':10,'new_patch_sha256':d['pack_sha256'],'new_patch_bytes':d['pack_bytes'],'runtime_adopted':True,'steam_updated':False,'scope':'Only selected attack-range ordering; original radius, projection, stroke and gameplay rules preserved. Not full campaign/save/performance/all-art acceptance. Shared engine complete; no rerun of this completed directory.'})

for label, stamp in [('first_clipped','20261018_110745_b7091a66'),('native_wide','20261018_114144_5f40b742')]:
    src = M/'native_resources'/stamp
    rec = read(src/'receipt.json')
    assert rec.get('checks') == 99 and rec.get('source_drift') == []
    dst = G/label
    collect_native(src,dst)
    for name in ['preview.gd','project.godot']: copy(src/name,dst/name)
    for p in sorted(src.glob('*.png.import')): copy(p,dst/'import_settings'/p.name)
    rep = read(src/'report.json')
    write(dst/'screenshots.json', [{'path':p.name,'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(src.glob('mounted_candidates_*.png'))])
    if label == 'native_wide':
        for name in ['mounted_candidates_se.png','mounted_candidates_ne.png']: copy(src/name,dst/name)
copy(M/'first_preview_direct_review.json',G/'first_clipped/direct_review.json')
write(G/'native_wide/direct_review.json', {'directly_viewed':['mounted_candidates_se.png','mounted_candidates_sw.png','mounted_candidates_ne.png','mounted_candidates_nw.png'],'finding':'All five columns now fit without head/tail framing clipping; common per-direction scale visibly retains smaller/lower idle body than walk.', 'visual_accepted_for_runtime':False,'open':['idle/walk horse and rider volume continuity','natural four-direction leg phase/anatomy','hand/rein/sword/scabbard continuity','attack/hurt/death and chapter routing'], 'source_135_check_failures_retained':2})
write(G/'native_gate.json', {'state':'resource_preview_complete_visual_continuity_pending','receipt':'native_wide/receipt.json','checks':99,'textures':5,'selected_regions':20,'frozen_files':33,'screenshots':4,'directly_viewed':4,'source_drift':[],'wholecell_source_checks':135,'wholecell_source_failures':2,'runtime_adopted':False,'steam_updated':False,'history':'first_clipped also99 structural checks but comparison framing visually rejected; new1920x720 run is separate. Neither overrides original135 source failures or qualifies actual game mounted character.'})
print(json.dumps({'collected':True,'range_checks':1621,'retained':len(old['checks']),'runtime_inventory':len(inventory),'preservation':preserved,'mounted_native':99},ensure_ascii=False))
