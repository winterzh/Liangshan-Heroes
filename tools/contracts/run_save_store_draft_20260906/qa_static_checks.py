"""No Godot. AST/catalog checks and isolated fake-child ownership checks only."""
import ast
import datetime
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('private_store_runner', HERE/'run_qa.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Child:
    pid = 424242
    def __init__(self, mode):
        self.mode = mode
        self.returncode = None
        self.waits = 0
        self.kills = 0
    def poll(self):
        return self.returncode
    def wait(self, timeout=None):
        self.waits += 1
        if self.mode == 'keyboard' and self.waits == 1:
            raise KeyboardInterrupt('isolated fake child')
        if self.mode == 'unconfirmed':
            raise subprocess.TimeoutExpired('fake-no-process', timeout)
        if self.returncode is None:
            self.returncode = 0
        return self.returncode
    def kill(self):
        self.kills += 1
        if self.mode != 'unconfirmed':
            self.returncode = -9


def main():
    checks = []
    for name in ['run_qa.py','qa_static_checks.py']:
        ast.parse((HERE/name).read_text(encoding='utf-8'))
        checks.append(name+' Python AST')
    source = runner.sources()
    cases = runner.catalog()
    assert len(cases) == 49
    assert all(item['expected_state'] for item in cases.values())
    assert sum(2 if item['kind'] in ('restart','interrupt') else 1 for item in cases.values()) == 54
    checks += ['pinned unchanged original store', '49 cases have concrete filesystem oracles', '54 process plan, 4 explicit interrupted writers']
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = HERE/'static_stub_runs'/stamp
    out.mkdir(parents=True,exist_ok=False)
    prepared = {'run_root':str(out),'private_project':str(out)}
    manifest_path = out/'fake_manifest.json'
    runner.save(manifest_path, {'fake':True})
    samples = []
    for mode in ['normal','keyboard','unconfirmed']:
        child = Child(mode)
        manifest = {'report':str(out/(mode+'.json')), 'phase':'single'}
        raised = None
        with patch.object(runner,'exclusive',lambda:None), patch.object(runner.subprocess,'Popen',lambda *a,**kw:child):
            try:
                runner.run_process('never-executed.exe',prepared,manifest_path,manifest,15)
            except BaseException as exc:
                raised = type(exc).__name__
        receipt = json.loads((out/(mode+'_process.json')).read_bytes())
        if mode == 'normal':
            assert raised is None and child.kills == 0 and receipt['exit_confirmed'] and runner.ACTIVE is None
        elif mode == 'keyboard':
            assert raised == 'KeyboardInterrupt' and child.kills == 1 and child.waits == 2 and receipt['exit_confirmed'] and runner.ACTIVE is None
        else:
            assert raised == 'RuntimeError' and child.kills == 1 and child.waits == 2 and not receipt['exit_confirmed'] and runner.ACTIVE is child and child.poll() is None
        checks.append('fake child '+mode+' owns/cleans/retains exact handle as expected')
        samples.append({'mode':mode,'exception':raised,'kills':child.kills,'waits':child.waits,'exit_confirmed':receipt['exit_confirmed']})
        runner.ACTIVE = None # Fake Python object only; there is no OS process.
    result = {'passed':True,'scope':'Python/catalog/fake child checks only; no GDScript or OS process validation',
              'checks':checks,'samples':samples,'source':source,'godot_run':False,
              'shared_lock_accessed':False,'real_profile_accessed':False,'stub_outputs':str(out)}
    runner.save(HERE/'qa_static_receipt.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
