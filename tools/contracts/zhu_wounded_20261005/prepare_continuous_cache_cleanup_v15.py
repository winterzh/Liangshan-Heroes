"""Prepare exact duplicate-cache cleanup for the rejected v15/v15a QA batches."""
from pathlib import Path
import ast,hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    src=HERE/'cleanup_failed_death_imports_v14.py';text=src.read_text(encoding='utf-8')
    old="assert keeper['complete'] and keeper['lock_released'] and keeper['covered_default_routes_verified'] and keeper['private_runtime_patches']==0\nassert keeper['root_input_drift']==keeper['private_input_drift']==0 and set(keeper['results'])=={'combat','death'}\nassert all(row['passed'] for row in keeper['results'].values())"
    new="assert keeper['complete'] and keeper['lock_released'] and keeper['private_runtime_patches']==0\nassert keeper['root_input_drift']==keeper['private_input_drift']==0\nassert keeper['result']['passed'] and keeper['result']['checks']==441 and len(keeper['result']['screenshots'])==70\nparent=read(Path(keeper['from_receipt']));assert parent['complete'] and parent['covered_default_routes_verified'] and parent['private_runtime_patches']==0"
    assert old in text;text=text.replace(old,new)
    text=text.replace("review['production_receipt_sha256']","review['receipt_sha256']")
    text=text.replace("failed_names=['ordinary_death_pilot_v10_5101dfd0']","failed_names=['ordinary_continuous_gait_v15_84f1500f','ordinary_continuous_gait_v15a_b3766d7b']")
    old="assert not receipt['complete'] and receipt['lock_released'] and Path(receipt['source_root']).resolve()==ROOT"
    new="""assert receipt['lock_released'] and Path(receipt['source_root']).resolve()==ROOT
 if name=='ordinary_continuous_gait_v15_84f1500f':assert not receipt['complete']
 else:
  rejected=read(ROOT/'qa/zhu_wounded_20261005/ordinary_continuous_gait_visual_review_v15a.json')
  assert receipt['complete'] and not rejected['passed'] and rejected['receipt_sha256']==sha(run/'receipt.json')"""
    assert old in text;text=text.replace(old,new)
    text=text.replace("keeper['source_files']+keeper['candidate_inputs']+keeper['new_inputs']","keeper['source_files']")
    text=text.replace("for result in keeper['results'].values():","for result in [keeper['result']]:")
    text=text.replace('Only the named failed v10 death QA imported cache;','Only the named rejected v15 and v15a continuous QA imported caches;')
    ast.parse(text);p=HERE/'cleanup_rejected_continuous_imports_v15.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'prepared':True,'parent_sha256':sha(src),'producer_sha256':sha(p),'executed':False,'targets':2}))
if __name__=='__main__':main()
