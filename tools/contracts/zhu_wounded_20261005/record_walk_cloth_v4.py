"""Preserve matched Shi Xiu native gait evidence without declaring production success."""
from pathlib import Path
import hashlib, json, shutil, sys
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst),'Preserve previous evidence'
    else:shutil.copyfile(src,dst)
imp_run,preview_run=map(Path,sys.argv[1:3])
imp=read(imp_run/'receipt.json')
assert imp['complete'] and imp['dimensions']['passed'] and imp['lock_released']
assert len(imp['dimensions']['checks'])==6 and all(r['passed'] for r in imp['dimensions']['checks'])
for row in imp['source_files']:
    if row['path'].endswith('.png'):assert row['before_sha256']==row['after_sha256']==sha(ROOT/row['path'])
if '--pending' in sys.argv[3:]:
    assert not (preview_run/'receipt.json').exists(),'Use finalized receipt instead'
    native=read(preview_run/'project/preview_result.json')
    assert native['passed'] and len(native['captures'])==64 and len(native['seen'])==20
    mp=ROOT/'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_v4.json'
    manifest=read(mp)
    paths=set(manifest['resources'])|{mp.relative_to(ROOT).as_posix(),'scripts/unit.gd'}
    for s in manifest['sources'].values():paths.update([s['path'],s['path']+'.import'])
    inputs=[]
    for p in sorted(paths):
        assert sha(ROOT/p)==sha(preview_run/'project'/p)
        inputs.append({'path':p,'sha256':sha(ROOT/p)})
    assert len(inputs)==22
    captures=[{'path':r['capture'],'sha256':sha(preview_run/'project'/r['capture'])} for r in native['captures']]
    matrix=preview_run/'project/walk_matrix_v3.png'
    preserve(imp_run/'receipt.json',QA/'shi_xiu_walk_texture_import_v4.json')
    preserve(matrix,QA/'shi_xiu_walk_cycle_cloth_v4.png')
    pending={'schema':1,'scope':'Native rendered outputs and read-only input audit while final lease-release receipt is pending',
       'render_result':native,'inputs':inputs,'captures':captures,'input_drift':0,'matrix_sha256':sha(matrix),
       'visual_result':'rejected_body_continuity',
       'visual_observations':['Back sash tails and layered hem improved','B remains narrower through shoulders/body than A/idle at normalized height','Head/hands and cloth texture need matched continuity correction'],
       'run':str(preview_run),'final_receipt_pending':True,'continuous_gait_qualified':False,'production_qualified':False}
    (QA/'shi_xiu_walk_cycle_cloth_pending_v4.json').write_text(json.dumps(pending,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'render_outputs_verified':True,'final_receipt_pending':True,'visual_result':'rejected_body_continuity'}))
    sys.exit(0)
preview=read(preview_run/'receipt.json')
assert preview['complete'] and preview['lock_released'] and preview['input_sha_drift']==0
assert len(preview['inputs'])==22 and len(preview['captures'])==64 and len(preview['preview']['seen'])==20
for row in preview['inputs']:assert sha(ROOT/row['path'])==row['sha256']==sha(preview_run/'project'/row['path'])
for row in preview['captures']:assert sha(preview_run/'project'/row['path'])==row['sha256']
sources=read(QA/'shi_xiu_walk_sources_v4.json')
assert len(sources['checks'])==157 and all(row['passed'] for row in sources['checks'])
matrix=preview_run/'project/walk_matrix_v3.png'
assert sha(matrix)==preview['matrix_sha256']
preserve(imp_run/'receipt.json',QA/'shi_xiu_walk_texture_import_v4.json')
preserve(preview_run/'receipt.json',QA/'shi_xiu_walk_cycle_cloth_v4.json')
preserve(matrix,QA/'shi_xiu_walk_cycle_cloth_v4.png')
review={'schema':1,'matrix_sha256':sha(matrix),
    'review':'Direct visual inspection of native sources and matched idle/A/B matrix',
    'result':'rejected_body_continuity',
    'improvements':['Back sash tails removed','Added layered tunic hems reduced','Opposite support legs retained'],
    'remaining':['B body/shoulder silhouette remains visibly narrower than A/idle at normalized height',
      'Head, hands and clothing texture still need consistent identity proportions across phases',
      'Actual continuous video, Unit secondary motion, physics, campaign and UI acceptance not performed'],
    'technical':{'source_checks':157,'resources':8,'native_sources':6,'captures':64,'seen':20,'frozen_inputs':22,'input_drift':0},
    'continuous_gait_qualified':False,'production_qualified':False,'user_approval_claimed':False}
(QA/'shi_xiu_walk_cycle_cloth_v4_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'technical_complete':True,'visual_result':review['result'],'production_qualified':False}))
