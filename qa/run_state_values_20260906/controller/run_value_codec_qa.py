"""Run the three-file value codec QA in a new private project and owned engine process."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scratchpad/run_state_value_codec'
FILES = ('value_codec.gd', 'qa_driver.gd', 'project.godot')
LOCK = ROOT / '.godot/redraw_rejection_source.lock'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())


def idle():
    code = "@(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -like '*Godot*.exe' } | ForEach-Object { [int]$_.ProcessId }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell', '-NoProfile', '-Command', code], text=True, timeout=20).strip()
    assert not (json.loads(raw) if raw else []), 'Godot slot occupied'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--accept-codec-sha256', required=True)
    args = parser.parse_args()
    exe = Path(args.godot).resolve()
    assert exe.is_file() and not re.search(r'[._-]console\.exe$', exe.name, re.I)
    authored = {name: (SOURCE / name).read_bytes() for name in FILES}
    pins = {name: sha(raw) for name, raw in authored.items()}
    assert pins['value_codec.gd'] == args.accept_codec_sha256
    config = authored['project.godot'].decode()
    assert '[autoload]' not in config and 'custom_user_dir' not in config
    names = re.findall(r'^config/name=("[^\n]+")\s*$', config, re.M)
    assert len(names) == 1
    project_name = json.loads(names[0])
    assert not any(ch in project_name for ch in '<>:"/\\|?*')
    idle()
    assert not LOCK.exists()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = SOURCE / 'runs' / stamp
    project = out / 'project'
    project.mkdir(parents=True, exist_ok=False)
    for name, raw in authored.items():
        (project / name).write_bytes(raw)
    profile = out / 'private_profile'
    for name in ('roaming', 'local', 'temp'):
        (profile / name).mkdir(parents=True)
    user = profile / 'roaming/Godot/app_userdata' / project_name
    user.mkdir(parents=True)
    result = {'complete': False, 'source_raw_sha256': pins, 'private_project': str(project),
              'expected_user_directory': str(user), 'engine_sha256': sha(exe.read_bytes()),
              'lock_released': False, 'godot_run': False}
    save(out / 'preparation.json', result)
    token = str(os.getpid()) + '|' + str(out)
    with LOCK.open('x', encoding='utf-8') as handle:
        handle.write(token)
    child = None
    try:
        env = os.environ.copy()
        for key in list(env):
            if key.startswith(('GODOT_', 'POLISH_', 'VALUE_CODEC_', 'STORE_QA_', 'PERF_')):
                env.pop(key)
        report_path = project / 'qa_report.json'
        env.update(APPDATA=str(profile / 'roaming'), LOCALAPPDATA=str(profile / 'local'),
                   TEMP=str(profile / 'temp'), TMP=str(profile / 'temp'), VALUE_CODEC_QA_OUT=str(report_path))
        idle()
        assert LOCK.read_text() == token
        with (out / 'process.log').open('xb') as log:
            child = subprocess.Popen([str(exe), '--headless', '--path', str(project),
                                      '--script', 'res://qa_driver.gd'], cwd=project, env=env,
                                     stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            result.update(godot_run=True, process_id=child.pid)
            try:
                result['exit_code'] = child.wait(timeout=120)
            except BaseException:
                child.kill()
                result['exit_code'] = child.wait(timeout=30)
                raise
        log = (out / 'process.log').read_text(encoding='utf-8', errors='replace')
        result['engine_diagnostics'] = bool(re.search(r'SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b|Unicode parsing error|Parse Error', log, re.M))
        assert result['exit_code'] == 0 and not result['engine_diagnostics'], 'Engine exit/log failure'
        raw_report = report_path.read_bytes()
        report = json.loads(raw_report)
        (out / 'report.json').write_bytes(raw_report)
        assert report['passed'] and report['checks'] and not report['failures']
        assert report['check_count'] == len(report['checks']) and all(row['passed'] for row in report['checks'])
        assert report['process_id'] == child.pid and report['source_raw_sha256'] == pins
        assert Path(report['actual_user_dir']).resolve() == user.resolve()
        result.update(complete=True, checks=report['check_count'], report_sha256=sha(raw_report))
    except BaseException as error:
        result['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        result['exit_confirmed'] = child is None or child.poll() is not None
        try:
            idle()
            assert result['exit_confirmed'] and LOCK.read_text() == token
            assert all((SOURCE / name).read_bytes() == raw and (project / name).read_bytes() == raw for name, raw in authored.items())
            result['source_unchanged'] = True
            LOCK.unlink()
            result['lock_released'] = True
        except BaseException as error:
            result.update(complete=False, final_guard_error=str(error))
        save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), 'complete': result['complete'], 'checks': result.get('checks'), 'lock_released': result['lock_released']}))


if __name__ == '__main__':
    main()
