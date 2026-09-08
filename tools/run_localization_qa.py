"""Run Godot localization QA with an isolated profile and retained logs."""
from pathlib import Path
import argparse
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--mode', choices=['runtime', 'visual', 'review', 'combat-review', 'contract', 'battle', 'battle-headless', 'preference'], default='runtime')
    parser.add_argument('--locale', choices=['zh_CN', 'zh_TW', 'en', 'ja'], default='en')
    parser.add_argument('--level', type=int, default=6)
    parser.add_argument('--visible', action='store_true', help='Place the visual test window on screen for final inspection')
    parser.add_argument('--resolution', default='1280x720')
    parser.add_argument('--baseline-revision', help='Explicit Git revision used by contract mode')
    parser.add_argument('--out', type=Path, default=ROOT/'scratchpad/localization/qa')
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--preference-action', choices=['save', 'reload', 'override'], default='save')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    profile = args.profile.resolve() if args.profile else out/'profile'
    env['APPDATA'] = str(profile/'Roaming')
    env['LOCALAPPDATA'] = str(profile/'Local')
    env['XDG_DATA_HOME'] = str(profile/'data')
    env['XDG_CONFIG_HOME'] = str(profile/'config')
    env['LSH_LANGUAGE'] = args.locale
    env['LSH_QA_REPORT'] = str(out/'report.json')
    env['LSH_QA_CAPTURE_DIR'] = str(out)
    env['LSH_QA_MODE'] = args.mode
    if args.mode == 'contract':
        if not args.baseline_revision:
            parser.error('contract mode requires --baseline-revision')
        source = subprocess.check_output(['git', 'show', args.baseline_revision + ':scripts/defs.gd'], cwd=ROOT)
        source = source.replace(b'class_name Defs', b'# Baseline definitions; loaded only for comparison', 1)
        baseline = out/'baseline_defs.gd'
        baseline.write_bytes(source)
        env['LSH_QA_BASELINE_DEFS'] = str(baseline)
    env['LSH_QA_PREFERENCE_ACTION'] = args.preference_action
    if args.mode == 'preference':
        if args.preference_action == 'override':
            env['LSH_LANGUAGE'] = 'en'
        else:
            env.pop('LSH_LANGUAGE', None)
    env.pop('LEVEL', None)
    if args.mode.startswith('battle'):
        env['LEVEL'] = str(args.level)
    for key in ['SMOKE_TEST', 'AUTOMICRO', 'SKIRMISH', 'SKIRMISH_AI', 'ARENA', 'SCENARIO', 'SCREENSHOT_DIR']:
        env.pop(key, None)
    command = [str(args.godot), '--path', str(ROOT), '--resolution', args.resolution]
    if args.mode in ('runtime', 'battle-headless', 'preference', 'contract'):
        command += ['--headless']
    else:
        command += ['--rendering-method', 'gl_compatibility', '--position', '0,0' if args.visible else '20000,20000']
    scene = {'review': 'text_ui_review', 'combat-review': 'battle_text_ui_review', 'contract': 'text_review_contract'}.get(args.mode, 'localization_qa')
    command += ['res://tools/' + scene + '.tscn']
    with (out/'godot.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                 timeout=180, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    text = (out/'godot.log').read_text(encoding='utf-8')
    errors = [line for line in text.splitlines() if 'ERROR:' in line]
    summary = {'mode': args.mode, 'locale': args.locale, 'level': args.level,
               'exit': process.returncode, 'errors': errors}
    (out/'runner.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False))
    return int(process.returncode != 0 or bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
