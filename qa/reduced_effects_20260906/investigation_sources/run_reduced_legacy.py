"""Root-owned one-off original Settings boot, with byte-exact restoration."""
import datetime, hashlib, json, runpy, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'scratchpad/reduced_effects_v2'
sha=lambda raw: hashlib.sha256(raw).hexdigest()
safe=runpy.run_path(str(ROOT/'scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py'))
safe['require_exclusive_godot']()
common=ROOT/'.godot/redraw_rejection_source.lock'
guard=ROOT/'.godot/reduced_effects_legacy_source.lock'
assert not common.exists() and not guard.exists()
pins=json.loads((HERE/'pins.json').read_bytes())
sources={name:(ROOT/name).read_bytes() for name in pins['candidate_lf_sha256']}
assert {name:sha(raw.replace(b'\r\n',b'\n')) for name,raw in sources.items()}==pins['candidate_lf_sha256']
path=ROOT/'scripts/settings.gd'
candidate=sources['scripts/settings.gd']
legacy=(HERE/'frozen/settings.gd.bin').read_bytes()
assert sha(legacy)==pins['base_raw_sha256']['scripts/settings.gd']
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
out=ROOT/'scratchpad/reduced_effects_application'/('legacy_'+stamp)
out.mkdir(exist_ok=False)
(out/'settings_candidate_before.bin').write_bytes(candidate)
receipt={'source':'scripts/settings.gd','candidate_raw':sha(candidate),'legacy_raw':sha(legacy),'restored':False,'legacy_test_completed':False}
with guard.open('x',encoding='utf-8') as stream: stream.write(str(out)+'\n')
try:
    assert path.read_bytes()==candidate
    path.write_bytes(legacy)
    launch=runpy.run_path(str(HERE/'launch_check.py'))
    old_args=sys.argv
    sys.argv=[str(HERE/'launch_check.py'),'--run','--render','--profile','legacy','--stages','legacy_autoload','--godot',sys.argv[1]]
    try: code=launch['main']()
    finally: sys.argv=old_args
    receipt['legacy_test_completed']=code==0
except BaseException as exc:
    receipt['exception']=type(exc).__name__+': '+str(exc)
    raise
finally:
    try:
        safe['require_exclusive_godot']()
        assert not common.exists(), 'Nested run retained common lock; investigate before restore'
        assert guard.read_text(encoding='utf-8').strip()==str(out)
        assert path.read_bytes()==legacy, 'Settings source changed unexpectedly; do not overwrite'
        assert all((ROOT/name).read_bytes()==raw for name,raw in sources.items() if name!='scripts/settings.gd')
        path.write_bytes(candidate)
        assert all((ROOT/name).read_bytes()==raw for name,raw in sources.items())
        receipt['restored']=True
        guard.unlink()
    except BaseException as exc: receipt['restore_error']=type(exc).__name__+': '+str(exc)
    (out/'restoration_receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
    print(json.dumps({'output':str(out),**receipt}),flush=True)
if not receipt['restored'] or not receipt['legacy_test_completed']: raise SystemExit(2)
