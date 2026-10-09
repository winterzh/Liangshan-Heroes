"""Prepare whole active-skill phase/effect verification for a reviewed guard draw delta."""
from pathlib import Path
import ast,hashlib,json
ROOT=Path(__file__).resolve().parents[3];H=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    src=H/'ordinary_skill_clearance_v16b.gd';text=src.read_text(encoding='utf-8').replace('ordinary_skill_clearance_v16b','ordinary_guard_readability_v17')
    p=H/'ordinary_guard_readability_v17.gd';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    src=H/'run_ordinary_skill_clearance_v16b.py';text=src.read_text(encoding='utf-8').replace('ordinary_skill_clearance_v16b','ordinary_guard_readability_v17')
    old="assert old['complete'] and old['lock_released'] and old['covered_default_routes_verified'] and old['private_runtime_patches']==0\n    assert old['root_input_drift']==old['private_input_drift']==0\n    assert Path(old['source_root']).resolve()==ROOT\n    inputs=old['source_files']+old['candidate_inputs']+old['new_inputs'];assert all(sha(ROOT/r['path'])==r['sha256'] for r in inputs)"
    new="""assert old['complete'] and old['lock_released'] and old['private_runtime_patches']==0
    assert old['root_input_drift']==old['private_input_drift']==0 and old['result']['passed'] and old['result']['checks']==761
    assert Path(old['source_root']).resolve()==ROOT and len(old['result']['screenshots'])==112
    patch=read(ROOT/'qa/zhu_wounded_20261005/lin_guard_readability_patch_v17.json')
    assert patch['applied'] and not patch['production_qualified'] and patch['baseline_receipt_sha256']==sha(rp)
    original=old['source_files'];changed=[row['path'] for row in original if sha(ROOT/row['path'])!=row['sha256']]
    assert changed==['scripts/battle.gd'],changed
    row=next(row for row in original if row['path']=='scripts/battle.gd')
    assert row['sha256']==patch['before_sha256'] and sha(ROOT/'scripts/battle.gd')==patch['after_sha256']
    inputs=[dict(row,sha256=sha(ROOT/row['path'])) for row in original]"""
    assert old in text;text=text.replace(old,new)
    text=text.replace("'private_runtime_patches':0,'steps':[]", "'private_runtime_patches':0,'production_source_delta':changed,'steps':[]")
    text=text.replace('Frozen current production mid/late skill phases and three desktop viewport sizes.','Current guard draw-only delta; whole normal-clock skill phase/effect/source qualification.')
    ast.parse(text);p=H/'run_ordinary_guard_readability_v17.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'prepared':True,'expected_captures':112,'allowed_production_delta':['scripts/battle.gd'],'executed':False,'runner_sha256':sha(p)}))
if __name__=='__main__':main()
