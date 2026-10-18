"""Launch an original release EXE from its real runtime directory.

The official release template rejects --path. Use its matching-basename PCK,
without a path override, and retain the actual Popen/command/log/exit evidence.
"""
from pathlib import Path
import hashlib
import subprocess
import time


def run_release_step(exe, runtime, env, output, label, args, timeout, common, running, steps):
    exe, runtime, output = Path(exe), Path(runtime), Path(output)
    assert exe.parent == runtime and exe.with_suffix('.pck').is_file()
    assert '--path' not in args and '--main-pack' not in args
    assert not running(), 'Shared engine appeared before release launch'
    command = [str(exe), '--rendering-method', 'gl_compatibility', *args]
    log_path = output / (label + '.log')
    row = {'case': label, 'command': command, 'cwd': str(runtime), 'passed': False,
           'automatic_matching_pck': str(exe.with_suffix('.pck'))}
    child = None
    reason = None
    started = time.monotonic()
    print('RUN ' + label, flush=True)
    try:
        with log_path.open('xb') as log:
            child = subprocess.Popen(command, cwd=runtime, env=env, stdout=log,
                                     stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            row['pid'] = child.pid
            last_update = started
            while child.poll() is None:
                time.sleep(.5)
                if common.ERROR_LINES.findall(log_path.read_text(encoding='utf-8', errors='replace')):
                    reason = 'script_or_engine_error'
                    break
                if time.monotonic() - started > timeout:
                    reason = 'timeout'
                    break
                if time.monotonic() - last_update >= 25:
                    print('RUNNING ' + label + ' ' + str(round(time.monotonic()-started)) + 's', flush=True)
                    last_update = time.monotonic()
    finally:
        # Only the exact child this helper created may be stopped.
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)
        errors = common.ERROR_LINES.findall(log_path.read_text(encoding='utf-8', errors='replace')) if log_path.exists() else []
        row.update(exit_code=child.returncode if child else None, errors=errors[:30],
                   seconds=round(time.monotonic()-started, 3), stopped_for=reason,
                   log_sha256=hashlib.sha256(log_path.read_bytes()).hexdigest() if log_path.exists() else None)
        row['passed'] = row['exit_code'] == 0 and not errors and reason is None
        steps.append(row)
        print('DONE ' + label + ' ' + str(row['passed']), flush=True)
    if not row['passed']:
        raise RuntimeError('Actual release step failed: ' + label)
