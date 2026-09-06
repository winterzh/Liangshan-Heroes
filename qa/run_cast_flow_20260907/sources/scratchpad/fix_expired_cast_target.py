"""Apply the minimal expired-object guard found by the real spell-flow probe."""
from pathlib import Path
import hashlib
import json
import difflib
import sys
import ast

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scratchpad/run_cast_flow_resume'
TARGET = ROOT / 'scratchpad/run_cast_flow_r1'
BATTLE = ROOT / 'scripts/battle.gd'
EXPECTED = 'd88caffd78a8530a79521262199a7ce116b2d0f5631c16cac136b6fa38552af5'
def sha(raw): return hashlib.sha256(raw).hexdigest()
raw = BATTLE.read_bytes()
assert sha(raw) == EXPECTED
updated = raw
for local, depth in [('pc', 3), ('wc', 2)]:
    indent = b'\t' * depth
    old = indent + f'var tgt = {local}.get("tgt")'.encode() + b'\r\n'
    assert updated.count(old) == 1
    new = old + indent + b'if typeof(tgt) == TYPE_OBJECT and not is_instance_valid(tgt):\r\n'
    new += indent + b'\tcontinue   # A freed Object may compare equal to null; never pass it to a typed cast API.\r\n'
    updated = updated.replace(old, new)
old = b'_do_ability(c, int(pc["slot"]), pc["lp"], pc.get("tgt"))'
assert updated.count(old) == 1
updated = updated.replace(old, b'_do_ability(c, int(pc["slot"]), pc["lp"], tgt)')
if '--apply' not in sys.argv:
    print(json.dumps({'applied': False, 'before': EXPECTED, 'candidate': sha(updated), 'bytes': len(updated)}))
    sys.exit(0)
assert not TARGET.exists()
failed = SOURCE / 'runs/20260906T204913855863Z'
receipt = json.loads((failed / 'receipt.json').read_bytes())
assert not receipt['complete'] and receipt['lock_released'] and receipt['source_unchanged'] and receipt['player_unchanged']
assert 'previously freed' in (failed / 'report.log').read_text(encoding='utf-8')
for name in ['cast_flow_state.gd', 'cast_flow_restore_smoke.gd', 'run_smoke.py', 'pins.json']:
    assert (SOURCE / name).exists()
TARGET.mkdir()
(TARGET / 'before').mkdir()
(TARGET / 'before/battle.gd.txt').write_bytes(raw)
BATTLE.write_bytes(updated)
driver = (SOURCE / 'cast_flow_restore_smoke.gd').read_bytes()
(TARGET / 'cast_flow_restore_smoke.gd').write_bytes(driver)
pins = json.loads((SOURCE / 'pins.json').read_bytes())
pins['revision'] = 'expired_target_production_fix'
for row in pins['runtime_sources']:
    if row['path'] == 'scripts/battle.gd':
        row.update(raw_sha256=sha(updated), bytes=len(updated))
    elif row['path'] == 'scratchpad/run_cast_flow_resume/cast_flow_restore_smoke.gd':
        row.update(path='scratchpad/run_cast_flow_r1/cast_flow_restore_smoke.gd')
    data = (ROOT / row['path']).read_bytes()
    assert sha(data) == row['raw_sha256'] and len(data) == row['bytes']
pins_raw = (json.dumps(pins, ensure_ascii=False, indent=2) + '\n').encode()
(TARGET / 'pins.json').write_bytes(pins_raw)
runner = (SOURCE / 'run_smoke.py').read_bytes()
oldpins = sha((SOURCE / 'pins.json').read_bytes()).encode()
assert runner.count(oldpins) == 1
runner = runner.replace(oldpins, sha(pins_raw).encode())
runner = runner.replace(b'res://scratchpad/run_cast_flow_resume/', b'res://scratchpad/run_cast_flow_r1/')
ast.parse(runner.decode())
(TARGET / 'run_smoke.py').write_bytes(runner)
diff = ''.join(difflib.unified_diff(raw.decode().splitlines(keepends=True), updated.decode().splitlines(keepends=True), 'a/scripts/battle.gd', 'b/scripts/battle.gd'))
(TARGET / 'expired_target.patch').write_bytes(diff.encode())
result = {'applied': True, 'before': EXPECTED, 'after': sha(updated), 'driver': sha(driver),
          'pins': sha(pins_raw), 'runner': sha(runner), 'original_failed_run': str(failed)}
(TARGET / 'application.json').write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode())
print(json.dumps(result))
