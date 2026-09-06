from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
source = root / 'scratchpad/run_state_value_codec/value_codec.gd'
target = root / 'scripts/run_state_value_codec.gd'
run = root / 'scratchpad/run_state_value_codec/runs/20260906T143634734025Z'
receipt = json.loads((run / 'receipt.json').read_bytes())
raw = source.read_bytes()
expected = 'c8c4a58d1e68e22abb9f8b1abcb1a9cc1dbaa486e51ea5174dd16984aaa35d15'
assert hashlib.sha256(raw).hexdigest() == expected
assert receipt['complete'] and receipt['checks'] == 341 and not receipt['engine_diagnostics']
assert receipt['exit_confirmed'] and receipt['lock_released'] and receipt['source_unchanged']
assert receipt['source_raw_sha256']['value_codec.gd'] == expected
assert not target.exists()
with target.open('xb') as stream:
    stream.write(raw)
assert target.read_bytes() == raw
result = {'source': source.relative_to(root).as_posix(), 'production_module': target.relative_to(root).as_posix(),
          'raw_sha256': expected, 'bytes': len(raw), 'tested_run': run.relative_to(root).as_posix(),
          'checks': 341, 'copied_exact_tested_bytes': True, 'autoload_added': False,
          'battle_adapter_implemented': False, 'continue_ui_implemented': False}
(root / 'scratchpad/run_state_value_codec/promotion_receipt.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
