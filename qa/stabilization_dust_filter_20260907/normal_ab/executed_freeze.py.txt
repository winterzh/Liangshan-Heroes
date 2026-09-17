import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DATA = ROOT / 'scratchpad/stabilization_dust_filter_20260907'
BASELINE = ROOT / '.godot/stabilization_performance/20260907T053341Z_cd6e93a0'
DATA_RUN = ROOT / '.godot/stabilization_performance/dust_data_20260907T071006Z_c95a6641'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
data_receipt = json.loads((DATA_RUN/'receipt.json').read_text(encoding='utf-8'))
assert data_receipt['complete'] and data_receipt['check_count'] == 4038
record = {'schema':1,'source_head':'c0285f91d4131e7631707fa59903d4b61fd460bb',
          'baseline_receipt_sha256':digest(BASELINE/'receipt.json'),
          'data_freeze_sha256':digest(DATA/'freeze.json'),
          'data_receipt_sha256':digest(DATA_RUN/'receipt.json'),
          'candidate_sha256':digest(DATA/'candidate/scripts/unit.gd'),
          'guard_sha256':digest(ROOT/'tools/run_stabilization_performance.py'),
          'inputs':{name:digest(HERE/name) for name in ('run.py','freeze.py','PLAN.md')},
          'order':['A','B','A','B','A','B'],'seconds':60,'pressure_seconds':10,
          'normal_ab_run':False}
raw = (json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
(HERE/'freeze.json').write_bytes(raw)
print(json.dumps({'freeze_sha256':hashlib.sha256(raw).hexdigest(),'normal_ab_run':False}))
