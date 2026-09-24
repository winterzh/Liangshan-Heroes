"""Run map navigation checks in a fresh private project/profile, without Steam.

Headless functional checks only; concurrent applications invalidate no FPS claim
because this runner collects no performance results.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

from run_steam_integration_qa import ROOT, sources, resolve_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', choices=['before', 'after'], required=True)
    args = parser.parse_args()
    run_id = time.strftime('%Y%m%d_%H%M%S') + '_' + args.label + '_' + uuid.uuid4().hex[:8]
    private = Path('D:/LHWallQA') / run_id
    project = private / 'project'
    output = ROOT / 'qa/stockade_boundary_20260924' / run_id
    project.mkdir(parents=True, exist_ok=False)
    output.mkdir(parents=True, exist_ok=False)
    records = []
    for name in sources() + ['tools/stockade_navigation_qa.gd']:
        raw = (ROOT / name).read_bytes()
        dest = project / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
        records.append({'path': name, 'sha256': hashlib.sha256(raw).hexdigest()})
    if (ROOT / '.godot/imported').is_dir():
        shutil.copytree(ROOT / '.godot/imported', project / '.godot/imported')
    env = os.environ.copy()
    for key in list(env):
        if key.startswith('LSH_') or key.endswith(('_QA', '_TEST', '_AUDIT')):
            env.pop(key)
    for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']:
        folder = private / 'profile' / key.lower()
        folder.mkdir(parents=True)
        env[key] = str(folder)
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='1', STOCKADE_QA_OUTPUT=str(output / 'report.json'))
    engine = str(resolve_godot(None))
    steps = []
    for label, extra in [('import', ['--editor', '--import']),
                         ('navigation', ['--script', 'res://tools/stockade_navigation_qa.gd'])]:
        print('RUN', label, str(output), flush=True)
        with (output / (label + '.log')).open('wb') as log:
            child = subprocess.Popen([engine, '--headless', '--path', str(project)] + extra,
                                     env=env, cwd=project, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                code = child.wait(timeout=180)
            except BaseException:
                child.kill()
                child.wait(timeout=30)
                raise
        steps.append({'name': label, 'exit_code': code})
        if label == 'import' and code:
            break
    unchanged = all(hashlib.sha256((ROOT / row['path']).read_bytes()).hexdigest() == row['sha256']
                    for row in records)
    receipt = {'private_project': str(project), 'label': args.label, 'steps': steps,
               'source_unchanged': unchanged, 'source_files': records,
               'scope': 'Headless functional navigation only; no graphics/performance acceptance.'}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('RESULT', str(output), 'unchanged=', unchanged, 'steps=', steps, flush=True)
    return 0 if unchanged and all(step['exit_code'] == 0 for step in steps) else 1


if __name__ == '__main__':
    raise SystemExit(main())
