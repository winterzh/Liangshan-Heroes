"""Adapt the reviewed lifecycle runner to the frozen spell-flow fixture."""
from pathlib import Path
import hashlib
import json
import re
import ast

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'scratchpad/run_meteor_wards_resume/run_smoke.py'
TARGET = ROOT / 'scratchpad/run_cast_flow_resume'
raw = BASE.read_bytes()
assert hashlib.sha256(raw).hexdigest() == 'a7940cd1424d2c73add96b9c7d47ac69dd76b9aa72ed790c9d48c4b9c7ba029b'
pins_raw = (TARGET / 'pins.json').read_bytes()
pins = json.loads(pins_raw)
for row in pins['runtime_sources']:
    data = (ROOT / row['path']).read_bytes()
    assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['raw_sha256']
driver = (TARGET / 'cast_flow_restore_smoke.gd').read_text(encoding='utf-8')
cases = driver[driver.index('\tvar battle_script:'):driver.index('\nfunc _record_with_payload')]
required = sorted(set(re.findall(r'(?:_check|_ok)\("([^"\n]+)"', cases)))
text = raw.decode('utf-8').replace('\r\n', '\n')
text = text.replace('run_meteor_wards_resume', 'run_cast_flow_resume')
text = text.replace('meteor_wards_restore_smoke.gd', 'cast_flow_restore_smoke.gd')
text = text.replace('meteor-wards-restore', 'cast-flow-restore')
text = text.replace('Real meteor and ward restore smoke', 'Real walk, windup and channel restore smoke')
start = text.index('    names = ')
end = text.index('    runner_sha = ', start)
text = text[:start] + f'''    pins_raw = (HERE / 'pins.json').read_bytes()
    util.need(util.hashlib.sha256(pins_raw).hexdigest() == '{hashlib.sha256(pins_raw).hexdigest()}', 'Cast pins drift')
    pins = util.json_value(pins_raw)
    hashes = {{row['path']: row['raw_sha256'] for row in pins['runtime_sources']}}
    util.need(all(util.file_sha(ROOT / name) == digest for name, digest in hashes.items()), 'Pinned cast source drift')
    entry = 'cast_flow_restore_smoke.gd'
''' + text[end:]
marker = "        util.need(util.file_sha(out / 'manifest.json') == manifest_sha, 'Manifest drift')"
assert text.count(marker) == 1
addition = f'''        util.need(report.get('check_count') == len(checks) and report.get('failed_count') == 0, 'Count mismatch')
        labels = [row.get('label') for row in checks]
        util.need(all(isinstance(label, str) and label for label in labels) and len(labels) == len(set(labels)), 'Check label mismatch')
        required = {required!r}
        required += ['source before ' + name for name in hashes] + ['source after ' + name for name in hashes]
        util.need(set(required).issubset(labels), 'Required spell-flow checks missing')
'''
text = text.replace(marker, addition + marker)
ast.parse(text)
(TARGET / 'run_smoke.py').write_bytes(text.encode('utf-8'))
print(json.dumps({'runner_sha256': hashlib.sha256(text.encode()).hexdigest(), 'pins_sha256': hashlib.sha256(pins_raw).hexdigest(), 'required_cases': len(required)}))
