"""Refresh the current checkout's class cache with an isolated editor process."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import types

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
base = ROOT / 'scratchpad/run_gameplay_rng_r1/run_qa.py'
raw = base.read_bytes()
assert hashlib.sha256(raw).hexdigest() == '8f9c82100bf8b635abd74f9a79b31335e72df404f30c62f3f490458af3e0e1ad'
util = types.ModuleType('import_util')
util.__file__ = str(base)
exec(compile(raw.decode('utf-8'), str(base), 'exec'), util.__dict__)
guard = util.load_helper(util.GUARD, util.GUARD_SHA, 'import_guard')
safety = util.load_helper(util.HELPER, util.HELPER_SHA, 'import_safety')
safety.ROOT = ROOT
exe = Path(sys.argv[1]).resolve()
util.need(util.file_sha(exe) == util.ENGINE_SHA, 'Unexpected engine')
safety.require_exclusive_godot()
peer_lock = ROOT.parent / '水浒/.godot/redraw_rejection_source.lock'
util.need(not peer_lock.exists() and not util.LOCK.exists(), 'Engine lock occupied')
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
out = HERE / 'imports' / stamp
out.mkdir(parents=True, exist_ok=False)
token = str(os.getpid()) + '|' + str(out)
with util.LOCK.open('x', encoding='utf-8') as stream:
    stream.write(token)
before = guard.source_receipt(ROOT)
imports = {name: (ROOT / name).read_bytes() for name in before['raw_file_sha256'] if name.endswith('.import')}
real_user = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / guard.project_name(ROOT)
players = util.tree(real_user)
util.save(out / 'sources_before.json', before)
util.save(out / 'players_before.json', players)
profile = out / 'private_profile'
user = profile / 'appdata/Godot/app_userdata' / guard.project_name(ROOT)
user.mkdir(parents=True)
(profile / 'localappdata').mkdir()
(profile / 'temp').mkdir()
env, controls = guard.environment(before, out, profile, user)
env.update(TEMP=str(profile / 'temp'), TMP=str(profile / 'temp'))
command = [str(exe), '--headless', '--editor', '--path', str(ROOT), '--import', '--quit']
result = dict(complete=False, command=command, head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), engine_sha256=util.ENGINE_SHA, controls=controls)
process = None
try:
    with (out / 'import.log').open('xb') as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        safety.ACTIVE_GODOT_PROCESS = process
        started = time.monotonic()
        while process.poll() is None:
            util.need(time.monotonic() - started < 180, 'Editor import timed out')
            time.sleep(0.1)
    util.need(process.returncode == 0, 'Editor import failed')
    result['complete'] = True
except BaseException as error:
    result['error'] = type(error).__name__ + ': ' + str(error)
finally:
    if process is not None:
        if process.poll() is None:
            process.kill()
        process.wait(timeout=30)
        result.update(child_pid=process.pid, exit_code=process.returncode, child_exit_confirmed=process.poll() is not None)
        safety.ACTIVE_GODOT_PROCESS = None
    after = guard.source_receipt(ROOT)
    old, new = before['raw_file_sha256'], after['raw_file_sha256']
    added = sorted(set(new) - set(old))
    changed = sorted(name for name in old.keys() & new.keys() if old[name] != new[name])
    valid = set(old) <= set(new) and all(name.endswith('.gd.uid') and name[:-4] in old and re.fullmatch(rb'uid://[a-z0-9]+\r?\n?', (ROOT / name).read_bytes()) for name in added)
    valid = valid and all(name in imports and (ROOT / name).read_bytes() == imports[name].replace(b'\r\n', b'\n') for name in changed)
    result.update(added_generated_uids=added, normalized_imports=changed, only_reviewed_import_changes=bool(valid), player_unchanged=util.tree(real_user) == players)
    result['complete'] = result['complete'] and valid and result['player_unchanged']
    util.save(out / 'sources_after.json', after)
    util.save(out / 'players_after.json', util.tree(real_user))
    util.need(util.LOCK.read_text(encoding='utf-8') == token, 'Lock owner changed')
    safety.require_exclusive_godot()
    util.LOCK.unlink()
    result['lock_released'] = True
    util.save(out / 'receipt.json', result)
    print(json.dumps(dict(out=str(out), **result), ensure_ascii=False))
sys.exit(0 if result['complete'] else 1)
