"""Preserve executed Wu producers; derive Lin import and real-motion adapters."""
from pathlib import Path
import json,hashlib,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];H=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
parents=[];derived=[]
parent=H/'texture_bootstrap_wu_gait_v5.py';p=parent.read_text(encoding='utf-8')
p=p.replace("'wu_song_gait_v5'","'lin_chong_gait_v5'").replace('idle_spacing_v4.png.import','idle_spacing2_v4.png.import')
p=re.sub(r"'producer_parent_sha256':'[0-9a-f]{64}'", "'producer_parent_sha256':'"+sha(parent)+"'",p)
dest=H/'texture_bootstrap_lin_gait_v5.py';assert not dest.exists();compile(p,str(dest),'exec');dest.write_bytes(p.encode('utf-8'))
parents.append({'path':parent.relative_to(ROOT).as_posix(),'sha256':sha(parent)});derived.append({'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest)})
parent=H/'ordinary_gait_motion_comparison_v5.gd';g=parent.read_text(encoding='utf-8')
g=g.replace('var config: Dictionary = JSON.parse_string', 'assert(Engine.time_scale==1.0)\n\tvar config: Dictionary = JSON.parse_string')
g=g.replace('"samples":samples,"key":selected_key,','"samples":samples,"key":selected_key,"engine_time_scale":Engine.time_scale,')
dest=H/'ordinary_lin_gait_motion_comparison_v5.gd';assert not dest.exists();dest.write_bytes(g.encode('utf-8'))
parents.append({'path':parent.relative_to(ROOT).as_posix(),'sha256':sha(parent)});derived.append({'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest)})
parent=H/'ordinary_gait_motion_comparison_v5.py';p=parent.read_text(encoding='utf-8')
p=p.replace('texture_bootstrap_wu_song_gait_v5_run.json','texture_bootstrap_lin_chong_gait_v5_run.json')
p=p.replace('ordinary_gait_motion_comparison_v5.gd','ordinary_lin_gait_motion_comparison_v5.gd')
p=p.replace('ordinary_gait_motion_comparison_v5.py','ordinary_lin_gait_motion_comparison_v5.py')
p=p.replace("len(result['checks'])==96", "result['engine_time_scale']==1.0 and len(result['checks'])==96")
dest=H/'ordinary_lin_gait_motion_comparison_v5.py';assert not dest.exists();compile(p,str(dest),'exec');dest.write_bytes(p.encode('utf-8'))
parents.append({'path':parent.relative_to(ROOT).as_posix(),'sha256':sha(parent)});derived.append({'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest)})
receipt=ROOT/'qa/zhu_wounded_20261005/lin_gait_motion_producer_parents_v5.json';assert not receipt.exists()
receipt.write_bytes((json.dumps({'parents':parents,'derived':derived,'prior_producers_unchanged':True,'scope':'New Lin adapters; generic real Unit actor retained unchanged'},indent=2)+'\n').encode('utf-8'))
print(json.dumps({'new_harnesses':len(derived),'expected_checks':96,'prior_producers_unchanged':True}))
