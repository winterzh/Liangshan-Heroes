"""Run the focused Godot scene with isolated user data and an exclusive lock."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--lock', required=True, type=Path,
                        help='Shared engine lock used by this workstation')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = root / '.godot/squad-qa'
    profile = out / 'profile'
    env = os.environ.copy()
    for key in list(env):
        if key.startswith('LSH_') or key.endswith(('_QA', '_TEST', '_AUDIT')) or key in (
                'LEVEL', 'SKIRMISH', 'SKIRMISH_AI', 'ARENA', 'CUSTOM_DEFENSE',
                'AUTO_MICRO', 'AUTOMICRO'):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        dest = profile / key.lower()
        dest.mkdir(parents=True, exist_ok=True)
        env[key] = str(dest)
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='1', LSH_LANGUAGE='zh_CN',
               LSH_SQUAD_PROFILE=str(profile), LSH_SQUAD_REPORT=str(out / 'report.json'))
    token = str(out)
    with args.lock.open('x', encoding='utf-8') as handle:
        handle.write(token)
    receipt = {'scope': 'fixtures and Level component only'}
    try:
        # Remove stale output only after owning the lock.
        (out / 'report.json').unlink(missing_ok=True)
        started = time.monotonic()
        with (out / 'squad.log').open('wb') as log:
            child = subprocess.Popen(
                [str(args.godot.resolve()), '--headless', '--path', str(root),
                 'res://tools/campaign_squad_orders_qa.tscn'],
                cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            try:
                code = child.wait(timeout=60)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
                receipt['timeout'] = True
                raise
        errors = [line for line in (out / 'squad.log').read_text(encoding='utf-8').splitlines()
                  if line.startswith(('SCRIPT ERROR:', 'ERROR:'))]
        report = json.loads((out / 'report.json').read_text(encoding='utf-8'))
        receipt.update(exit_code=code, errors=errors, seconds=round(time.monotonic() - started, 2),
                       passed=code == 0 and not errors and report.get('passed') is True)
        print(json.dumps(receipt, ensure_ascii=False))
        return 0 if receipt['passed'] else 1
    finally:
        (out / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding='utf-8')
        if args.lock.exists() and args.lock.read_text(encoding='utf-8') == token:
            args.lock.unlink()


if __name__ == '__main__':
    raise SystemExit(main())
