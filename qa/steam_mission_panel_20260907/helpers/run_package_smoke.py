"""Run the actual embedded-PCK EXE with isolated user data, never the source tree."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import os
import re
import subprocess

QA = Path(__file__).resolve().parent / "smoke"
QA.mkdir(exist_ok=True)
EXE = Path(os.environ['LIANGSHAN_TEST_EXE'])
DATA = Path(os.environ.get('LIANGSHAN_TEST_DATA', str(QA / 'package_user_data')))
CASES = [(f'level{i}', {'SMOKE_TEST':'1', 'LEVEL':str(i)}, f'[smoke] level{i}') for i in range(1,9)]
CASES += [('defense', {'SMOKE_TEST':'1','SKIRMISH':'1','DEFENSE_HARD_FIX_TEST':'1'}, '[defense_hard_fix]'),
          ('cleanup', {'SMOKE_TEST':'1','SKIRMISH':'1','FINAL_CLEANUP_TEST':'1'}, '[final_cleanup]'),
          ('main_menu', {}, '')]

def run(case):
    name, extra, marker = case
    env = os.environ.copy()
    for key in ('SMOKE_TEST','LEVEL','SKIRMISH','SKIRMISH_AI','SCREENSHOT_DIR','DEFENSE_HARD_FIX_TEST','FINAL_CLEANUP_TEST'):
        env.pop(key, None)
    env.update(extra)
    env['APPDATA'] = str(DATA / name)
    command = [str(EXE),'--headless','--max-fps','60','--quit-after','180','--log-file',str(QA / (name+'.godot.log'))]
    result = subprocess.run(command,cwd=str(EXE.parent),env=env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    output = result.stdout.decode('utf8','replace') + result.stderr.decode('utf8','replace')
    (QA / (name+'.console.log')).write_text(output,encoding='utf8')
    errors = re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$', output, re.M)
    line = next((line for line in output.splitlines() if marker and marker in line),'')
    passed = result.returncode == 0 and not errors and (not marker or bool(line))
    if name in ('defense','cleanup'):
        passed = passed and 'ALL=true' in line
    record = {'name':name,'command':command,'environment_overrides':extra,'exit_code':result.returncode,'errors':errors,'marker':line,'passed':passed}
    print(json.dumps({'name':name,'passed':passed,'exit_code':result.returncode,'marker':line},ensure_ascii=False),flush=True)
    return record

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        rows = list(pool.map(run, CASES))
    report = {'executable':str(EXE),'size_bytes':EXE.stat().st_size,'sha256':hashlib.sha256(EXE.read_bytes()).hexdigest(),
              'passed':all(row['passed'] for row in rows),'cases':rows,
              'scope':'Automated exported-package startup and embedded selftests, not full campaign or 30-wave human play.'}
    (QA / 'package_smoke.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    raise SystemExit(0 if report['passed'] else 1)
