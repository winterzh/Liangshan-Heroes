"""Record native twenty-pose candidate and actual process-clock preview evidence."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
imp_run,run=map(Path,sys.argv[1:3]);imp=read(imp_run/'receipt.json');r=read(run/'receipt.json')
m=read(ROOT/'assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json')
assert len(m['sources'])==14 and len(m['poses'])==20 and len(m['resources'])==8 and not m['production_qualified']
assert m['states']=={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']}
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed'] and len(imp['dimensions']['checks'])==14
for item in imp['source_files']:
    if item['path'].endswith('.png'):assert sha(ROOT/item['path'])==item['before_sha256']==item['after_sha256']
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert len(r['inputs'])==38 and len(r['captures'])==64 and len(r['preview']['seen'])==20
for item in r['inputs']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/item['path'])
for item in r['captures']:assert sha(run/'project'/item['path'])==item['sha256']
assert sha(run/'walk_preview_v3.py')==r['harness_sha256']
assert sha(run/'project/walk_preview_v3.gd')==r['draw_script_sha256']
sources=read(QA/'shi_qian_walk_sources_passing_v4.json');assert sources['passed'] and len(sources['checks'])>=153
matrix=run/'project/walk_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/'shi_qian_walk_texture_passing_v4.json')
preserve(run/'receipt.json',QA/'shi_qian_walk_cycle_passing_v4.json')
preserve(matrix,QA/'shi_qian_walk_cycle_passing_v4.png')
phases=[next(c for c in r['preview']['captures'] if c['moving'] and c['indexes'][0]==p) for p in range(4)]
review={'schema':1,'character':'shi_qian','result':'twenty_native_poses_rendered_candidate_gait_review',
    'source_checks':len(sources['checks']),'frozen_inputs':len(r['inputs']),'input_drift':0,'matrix_sha256':sha(matrix),'observed_phases':phases,
    'review':'Native 20-pose matrix and actual phases 0/1/2/3 directly viewed',
    'observations':['Watchful masked slim adult identity, soft knees and restrained hip lean retained',
        'Four idle, eight contact and eight separately authored passing poses; idle is not reused as passing',
        'Two native four-view atlases plus twelve full-canvas native singles; no local PNG transformation',
        'Character height metadata .78; no Wang Ying short-stature scaling inherited'],
    'remaining':['Actual Unit movement, stop, reverse, secondary drawing and original campaign still required',
        'NE contact A support clarity, rear boot sole/lift amplitude, exact foot anchors and wardrobe transitions require full movement review',
        'No continuous browser playback acceptance; no production routing/UI qualification'],
    'continuous_gait_qualified':False,'production_qualified':False}
p=QA/'shi_qian_walk_passing_review_v4.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
prompts=[]
for source in m['sources'].values():
    j=read(HERE/f"jobs/{source['job']}.json");assert sha(ROOT/j['request'])==j['request_sha256']
    prompts.append({'path':source['path'],'sha256':source['sha256'],'request':j['request'],
        'request_sha256':j['request_sha256'],'exact_args':read(ROOT/j['request'])})
p=QA/'shi_qian_walk_native_prompt_set_v4.json'
assert read(p)['requests']==prompts or all(a['exact_args']==b['exact_args'] for a,b in zip(read(p)['requests'],prompts))
print(json.dumps({'sources':14,'source_checks':len(sources['checks']),'captures':64,'frozen_inputs':len(r['inputs']),'input_drift':0,'production_qualified':False}))
