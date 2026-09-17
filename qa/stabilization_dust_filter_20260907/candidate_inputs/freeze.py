import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
names = ['prepare.py','prepare_driver.py','driver_template.gd.txt','data_smoke.gd',
         'source_receipt.json','driver_receipt.json','pure_data_review.json','candidate.patch',
         'candidate/scripts/unit.gd','HANDOFF.md','freeze.py','run_data.py']
receipt = json.loads((HERE / 'source_receipt.json').read_text(encoding='utf-8'))
review = json.loads((HERE / 'pure_data_review.json').read_text(encoding='utf-8'))
assert review['passed'] and review['python_model_cases'] == 1007
assert hashlib.sha256((HERE/'candidate/scripts/unit.gd').read_bytes()).hexdigest() == receipt['candidate_sha256']
record = {'status':'frozen_static_and_python_data_only','source_head':receipt['source_head'],
          'candidate_file_count':1,'production_modified':False,'godot_run':False,'normal_ab_run':False,
          'inputs':{name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in names}}
raw = (json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
(HERE/'freeze.json').write_bytes(raw)
print(json.dumps({'freeze_sha256':hashlib.sha256(raw).hexdigest(),'candidate_sha256':receipt['candidate_sha256']}))
