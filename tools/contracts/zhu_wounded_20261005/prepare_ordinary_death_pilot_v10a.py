"""Keep failed v10 exact; obtain shadow evidence from the actual loaded node."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    gd_parent=HERE/'ordinary_death_pilot_v10.gd';py_parent=HERE/'run_ordinary_death_pilot_v10.py'
    gd=gd_parent.read_text(encoding='utf-8').replace('ordinary_death_pilot_v10','ordinary_death_pilot_v10a')
    gd=gd.replace('const Shadow := preload("res://scripts/world_shadow.gd")','const SHADOW_NODE := "WorldShadowBatch"')
    gd=gd.replace('String(Shadow.BATCH_NODE_NAME)','SHADOW_NODE')
    gd=gd.replace('Shadow.enabled() and is_instance_valid(shadow)','is_instance_valid(shadow)')
    gd=gd.replace('Shadow.batch_summary(b)','shadow.summary() if is_instance_valid(shadow) else {"exists":false}')
    gd=gd.replace('\tcheck(Shadow.enabled(),"normal production shadow renderer enabled")\n','')
    assert 'Shadow.' not in gd and 'preload("res://scripts/world_shadow.gd")' not in gd
    py=py_parent.read_text(encoding='utf-8').replace('ordinary_death_pilot_v10','ordinary_death_pilot_v10a')
    for name,text in [('ordinary_death_pilot_v10a.gd',gd),('run_ordinary_death_pilot_v10a.py',py)]:
        p=HERE/name;assert not p.exists();p.write_bytes(text.encode('utf-8'))
    p=ROOT/'qa/zhu_wounded_20261005/ordinary_death_pilot_preparation_v10a.json';assert not p.exists()
    p.write_bytes((json.dumps({'parents':[{'path':x.relative_to(ROOT).as_posix(),'sha256':sha(x)} for x in [gd_parent,py_parent]],
          'failed_run':'E:/ChatGPT/qa-ordinary-posture-20261006/ordinary_death_pilot_v10_5101dfd0',
          'correction':'No early WorldShadow preload; get actual WorldShadowBatch node after original Battle startup and directly inspect retention/summary/pruning.',
          'production_scripts_changed':False,'scope':'Preserves failed v10 producer/run; v10a compile/runtime pending.'},indent=2)+'\n').encode('utf-8'))
    print('Prepared v10a sibling; failed v10 untouched.')

if __name__=='__main__':main()
