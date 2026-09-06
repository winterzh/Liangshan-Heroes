"""Promote the reviewed Level adapter and prepare an equivalent formal-path probe."""
from pathlib import Path
import hashlib
import json
import ast

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scratchpad/run_defense_level_state'
TARGET = ROOT / 'scratchpad/run_defense_level_production_qa'
EXPECTED = {
    'level_state.gd': '5cb83ac01cddcdab0865434caa5e0de5ec8e5d1f28a746c657dc745e7ca4aa91',
    'driver.gd': '21436a70e49a565e7a216d0e7b6b74760b8787d832af5c565980ae3ebd750fa7',
    'run_smoke.py': 'e55e2a5dc33d85df7c05153367e103fc8806222bf17534d4a0605958d3145405',
    'pins.json': '51137d8e81a0f1e2cd9078959b12f19e3537ce4362d5ed86fb2ae9b1932d58a4',
}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

raws = {name: (SOURCE / name).read_bytes() for name in EXPECTED}
assert all(sha(raws[name]) == digest for name, digest in EXPECTED.items())
receipt = json.loads((SOURCE / 'runs/20260906T203250821538Z/receipt.json').read_bytes())
assert receipt['complete'] and receipt['checks'] == 253 and receipt['lock_released']
assert receipt['source_unchanged'] and receipt['player_unchanged']
pins = json.loads(raws['pins.json'])
assert all(sha((ROOT / row['path']).read_bytes()) == row['raw_sha256'] for row in pins['runtime_sources'])
module = ROOT / 'scripts/run_defense_level_state.gd'
assert not module.exists() and not TARGET.exists()
module.write_bytes(raws['level_state.gd'])
TARGET.mkdir()
driver = raws['driver.gd'].replace(b'res://scratchpad/run_defense_level_state/level_state.gd',
                                  b'res://scripts/run_defense_level_state.gd')
assert driver != raws['driver.gd']
(TARGET / 'driver.gd').write_bytes(driver)
for row in pins['runtime_sources']:
    if row['path'] == 'scratchpad/run_defense_level_state/driver.gd':
        row.update(path='scratchpad/run_defense_level_production_qa/driver.gd', raw_sha256=sha(driver))
    elif row['path'] == 'scratchpad/run_defense_level_state/level_state.gd':
        row.update(path='scripts/run_defense_level_state.gd', raw_sha256=sha(raws['level_state.gd']))
pins_raw = (json.dumps(pins, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
(TARGET / 'pins.json').write_bytes(pins_raw)
runner = raws['run_smoke.py'].replace(b'scratchpad/run_defense_level_state/',
                                     b'scratchpad/run_defense_level_production_qa/')
runner = runner.replace(b"'scratchpad/run_defense_level_production_qa/level_state.gd'",
                        b"'scripts/run_defense_level_state.gd'")
runner = runner.replace(EXPECTED['pins.json'].encode(), sha(pins_raw).encode())
ast.parse(runner.decode())
(TARGET / 'run_smoke.py').write_bytes(runner)
attrs = ROOT / '.gitattributes'
with attrs.open('ab') as stream:
    stream.write(b'\nqa/run_defense_level_20260907/** -text -whitespace\n')
    stream.write(b'\nscripts/run_defense_level_state.gd* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
print(json.dumps({'module': sha(module.read_bytes()), 'driver': sha(driver), 'runner': sha(runner), 'pins': sha(pins_raw)}))
