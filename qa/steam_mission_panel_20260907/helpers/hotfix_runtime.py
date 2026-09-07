"""One owner, sequential child handles, private profiles; no public credentials."""
from pathlib import Path
import contextlib, hashlib, json, os, runpy, subprocess, time

BASE = Path(__file__).resolve().parent
BEFORE = None
AFTER = None
ACTIVE = None
PROCESSES = []

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def save(path, value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def private_env(label, prior=None):
    env = dict(os.environ if prior is None else prior)
    folder = Path(os.environ['HOTFIX_PROFILE']) / label
    for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
        target = folder/key.lower()
        target.mkdir(parents=True,exist_ok=True)
        env[key] = str(target)
    return env

def run_child(command, **kwargs):
    global ACTIVE
    if BEFORE is None or AFTER is None:
        raise RuntimeError('Run through run_guarded.py; standalone helper execution is forbidden')
    BEFORE()
    if ACTIVE is not None and ACTIVE.poll() is None:
        raise RuntimeError('Previous child still running')
    timeout = kwargs.pop('timeout', 900)
    check = kwargs.pop('check', False)
    capture = kwargs.pop('capture_output', False)
    payload = kwargs.pop('input', None)
    if capture:
        kwargs['stdout'], kwargs['stderr'] = subprocess.PIPE, subprocess.PIPE
    if payload is not None: kwargs['stdin'] = subprocess.PIPE
    kwargs.setdefault('creationflags', subprocess.CREATE_NO_WINDOW)
    env = kwargs.get('env')
    if env is None: raise RuntimeError('Every native child needs an explicit private environment')
    profile = Path(os.environ['HOTFIX_PROFILE']).resolve()
    for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
        Path(env[key]).resolve().relative_to(profile)
    started = time.monotonic()
    process = None
    record = {'command':list(map(str,command)), 'child_started':False, 'child_exit_confirmed':False}
    try:
        process = subprocess.Popen(command, **kwargs)
        ACTIVE = process
        record.update(child_started=True,pid=process.pid)
        stdout, stderr = process.communicate(input=payload,timeout=timeout)
        record['exit_code'] = process.returncode
        if check and process.returncode:
            raise subprocess.CalledProcessError(process.returncode,command,stdout,stderr)
        return subprocess.CompletedProcess(command,process.returncode,stdout,stderr)
    except BaseException as error:
        record['exception'] = type(error).__name__+': '+str(error)
        raise
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=30)
            record.update(child_exit_confirmed=process.poll() is not None,exit_code=process.returncode)
            if record['child_exit_confirmed']: ACTIVE = None
        record['seconds'] = round(time.monotonic()-started,3)
        PROCESSES.append(record)
        save(BASE/'child_processes.json',PROCESSES)
        AFTER()

def run_smoke(path, exe, env):
    # Restore historical cases, but run them sequentially in this interpreter.
    # Each actual release EXE is owned by run_child, not by a Python grandchild.
    text = Path(path).read_text(encoding='utf8')
    text = text.replace('subprocess.run(', 'run_child(')
    text = text.replace("env['APPDATA'] = str(DATA / name)", "env = private_env('smoke_'+name,env)")
    namespace = {'__file__':str(path),'__name__':'frozen_smoke_helper',
                 'run_child':run_child,'private_env':private_env}
    saved = os.environ.copy()
    try:
        os.environ.update(env)
        os.environ.update(LIANGSHAN_TEST_EXE=str(exe), LIANGSHAN_TEST_DATA=str(Path(os.environ['HOTFIX_PROFILE'])/'smoke'))
        exec(compile(text,str(path),'exec'),namespace)
        rows = [namespace['run'](case) for case in namespace['CASES']]
        report = {'executable':str(exe),'size_bytes':exe.stat().st_size,'sha256':sha(exe),
                  'passed':all(row['passed'] for row in rows),'cases':rows,
                  'sequential':True,'scope':'Actual exported EXE startup and embedded selftests, not full campaign.'}
        save(BASE/'smoke/package_smoke.json',report)
        if not report['passed']: raise RuntimeError('Actual EXE smoke failed')
    finally:
        os.environ.clear()
        os.environ.update(saved)

def helper(name):
    runpy.run_path(str(BASE/name),run_name='hotfix_helper')
