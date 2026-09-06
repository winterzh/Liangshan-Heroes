"""Promote the successful spell-flow adapter; preserve the failed run and R1."""
from pathlib import Path
import hashlib
import json
import ast

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scratchpad/run_cast_flow_r1'
TARGET = ROOT / 'scratchpad/run_cast_flow_production_qa'
MODULE = ROOT / 'scripts/run_cast_flow_state.gd'
def sha(raw): return hashlib.sha256(raw).hexdigest()
receipt = json.loads((SOURCE / 'runs/20260906T205452854069Z/receipt.json').read_bytes())
assert receipt['complete'] and receipt['checks'] == 63 and receipt['lock_released']
assert receipt['source_unchanged'] and receipt['player_unchanged']
pins_raw = (SOURCE / 'pins.json').read_bytes()
assert sha(pins_raw) == '280a53b7c5929974b70575d52a69cbee84d90a7b4f5ec9fcf12c4ca005aa5d60'
pins = json.loads(pins_raw)
for row in pins['runtime_sources']:
    raw = (ROOT / row['path']).read_bytes()
    assert sha(raw) == row['raw_sha256'] and len(raw) == row['bytes']
raw = (ROOT / 'scratchpad/run_cast_flow_resume/cast_flow_state.gd').read_bytes()
assert sha(raw) == '127a230696570b50207fd06a3c4e7a4f33dad7bb24d33a333e4d136343976587'
assert not MODULE.exists() and not TARGET.exists()
MODULE.write_bytes(raw)
TARGET.mkdir()
driver = (SOURCE / 'cast_flow_restore_smoke.gd').read_bytes()
assert sha(driver) == '1cc55020ce467025e5d6ca78ac380ac3d42c07110355a39298c9b87fb94b1a35'
driver = driver.replace(b'res://scratchpad/run_cast_flow_resume/cast_flow_state.gd', b'res://scripts/run_cast_flow_state.gd')
(TARGET / 'cast_flow_restore_smoke.gd').write_bytes(driver)
pins['revision'] = 'formal_resource_path'
for row in pins['runtime_sources']:
    if row['path'] == 'scratchpad/run_cast_flow_resume/cast_flow_state.gd':
        row['path'] = 'scripts/run_cast_flow_state.gd'
    elif row['path'] == 'scratchpad/run_cast_flow_r1/cast_flow_restore_smoke.gd':
        row['path'] = 'scratchpad/run_cast_flow_production_qa/cast_flow_restore_smoke.gd'
    actual = (ROOT / row['path']).read_bytes()
    row.update(raw_sha256=sha(actual), bytes=len(actual))
newpins = (json.dumps(pins, ensure_ascii=False, indent=2) + '\n').encode()
(TARGET / 'pins.json').write_bytes(newpins)
runner = (SOURCE / 'run_smoke.py').read_bytes()
assert sha(runner) == 'de4eb2797d1a638dc39d9bbce9022741fb6f387a2c564940102c522d71fa6a29'
runner = runner.replace(b'res://scratchpad/run_cast_flow_r1/', b'res://scratchpad/run_cast_flow_production_qa/')
runner = runner.replace(sha(pins_raw).encode(), sha(newpins).encode())
ast.parse(runner.decode())
(TARGET / 'run_smoke.py').write_bytes(runner)
with (ROOT / '.gitattributes').open('ab') as stream:
    stream.write(b'\nqa/run_cast_flow_20260907/** -text -whitespace\n')
    stream.write(b'\nscripts/run_cast_flow_state.gd* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
print(json.dumps({'module': sha(raw), 'driver': sha(driver), 'driver_bytes': len(driver), 'pins': sha(newpins), 'runner': sha(runner)}))
