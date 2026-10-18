"""Preserve source lineage, rejected variants and exact native preview evidence."""
from pathlib import Path
import hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
selection=json.loads((Q/'candidate_selection.json').read_text());sources=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text());assert sha(Q/row['file'])==row['sha256']
    row['selected']=row['key'] in ['contact_a_v2','passing_a_v1','contact_b_v2','passing_b_v1']
    row['directly_viewed']=True;row['rejection']=selection['rejected'].get(row['key'])
    sources.append(row)
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','original_count':len(sources),'selected_walk_original_count':4,'reused_idle':'qa/wu_yong_hand_contact_20261018/native_originals/idle_rear_grip_v2.png','canon':selection['canon'],'sources':sources,'local_png_pixel_writes':False,'production_adopted':False})
P=Path(json.loads((E/'latest.json').read_text())['receipt']).parent;receipt=json.loads((P/'receipt.json').read_text());assert receipt['complete'] and receipt['native_checks']==68
out=Q/'actual_preview';out.mkdir();archive=[]
for src in sorted(P.iterdir()):
    if not src.is_file() or src.name=='preview.gd.uid':continue
    dst=out/(src.name+'.txt' if src.name.endswith('.gd') else src.name);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
    archive.append({'original':str(src),'archive':dst.relative_to(Q).as_posix(),'sha256':sha(dst),'bytes':dst.stat().st_size})
save(Q/'preview_archive_index.json',archive)
save(Q/'preview_review.json',{'directly_viewed':['compare_se.png','compare_sw.png','compare_ne.png','compare_nw.png'],'not_yet_directly_viewed':['grid_se.png','grid_sw.png','grid_ne.png','grid_nw.png'],'native_checks':68,'native_check_scope':'12 textures x 5 native size/SHA/RGBA/corners checks, plus 8 capture checks. Not 68 gameplay scenarios.','observations':['Four selected new walk originals have visible opposite contact legs and narrower passing phases in all four directions.','Rear far fists no longer rest visibly on the lower back; forward hidden arm remains anatomically plausible but hidden hands cannot be measured.','Near grip registration is stable in enlarged details; front palm centres estimated with 5 source-pixel uncertainty.','One directional body reference and fixed cart transform are shared across all phases; no per-phase body scaling or PNG edits.','Idle-to-motion and temporal foot-ground continuity still require actual Unit and continuous observation.'],'candidate_visually_ready_for_native_unit':True,'whole_gait_accepted':False,'physical_hidden_hand_contact_measured':False,'production_adopted':False})
print(json.dumps({'sources':len(sources),'selected_walk':4,'native_checks':68,'archived_preview_files':len(archive)}))
