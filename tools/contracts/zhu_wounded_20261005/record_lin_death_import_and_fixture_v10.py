"""Preserve native import and failed early-preload evidence without qualifying death."""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
EXTERNAL=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    native_path=EXTERNAL/'texture_bootstrap_lin_chong_death_v10_f45362bd/receipt.json';native=read(native_path)
    assert native['complete'] and native['lock_released'] and native['dimensions']['passed']
    checks=native['dimensions']['checks'];assert len(checks)==1 and checks[0]['width']==checks[0]['height']==1254
    for row in native['source_files']:
        assert sha(ROOT/row['path'])==row['after_sha256']
        if not row['path'].endswith('.import'):assert row['before_sha256']==row['after_sha256']
    target=QA/'lin_sw_death_native_texture_v10.json';assert not target.exists();shutil.copy2(native_path,target);assert sha(target)==sha(native_path)
    failed_path=EXTERNAL/'ordinary_death_pilot_v10_5101dfd0/receipt.json';failed=read(failed_path)
    assert not failed['complete'] and failed['lock_released'] and 'Identifier not found: Art' in failed['failure']['message']
    for row in failed['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    dump(QA/'ordinary_death_pilot_rejected_v10.json',{
        'qualified':False,'failed_receipt':str(failed_path),'failed_receipt_sha256':sha(failed_path),
        'failure':failed['failure'],'steps':failed['steps'],'harnesses':failed['harnesses'],'lock_released':True,
        'correction':'Sibling v10a removes early WorldShadow preload and inspects the actual loaded WorldShadowBatch node after original Battle startup.',
        'production_scripts_changed':False,'death_viewports_captured':0,
        'scope':'Failed fixture compilation; no actual death or production qualification. Exact failed producer/project/logs retained.'})
    text='2026-10-07复验入口修正：林冲SW第二版原生导入/1254×1254尺寸回读已通过，PNG字节不变；收据lin_sw_death_native_texture_v10.json。v10影子夹具因提前preload触发Art依赖编译错误，未取得死亡画面；失败源码/批保留，ordinary_death_pilot_rejected_v10.json记录原因。改用run_ordinary_death_pilot_v10a.py（其余参数同前）；它从原关卡实际WorldShadowBatch取保留/释放证据，生产脚本未改。v9未执行；v10已失败，不能再称待验证成功候选。v10a资格依新收据，目前新death未默认接入。\n\n'
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '2026-10-07复验入口修正：' not in old;p.write_bytes((text+old).encode('utf-8'))
    print(json.dumps({'native_dimensions_verified':True,'failed_v10_preserved':True,'production_changed':False,'v10a_pending':True}))

if __name__=='__main__':main()
