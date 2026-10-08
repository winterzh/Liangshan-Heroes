"""Serial runtime successor for two pure legacy regressions and normal admission ABC.
Only the two fixed pure regression labels may enable CAMPAIGN_QA.
The existing durable runtime remains immutable and is used by its active batch.
"""
"""Owned serial process and source-freeze support. No suite or native entry point."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

from run_steam_integration_qa import LOCK
from run_workstation_baseline import engines

ERRORS = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)')
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def error_count(log):
    return len(ERRORS.findall(ANSI.sub('', Path(log).read_text(encoding='utf-8', errors='replace'))))

CLEAR_ENV = ['CAMPAIGN_QA', 'LEVEL', 'SKIRMISH', 'SKIRMISH_AI', 'ARENA', 'SCENARIO',
             'CUSTOM_DEFENSE', 'AI_FRIENDLY', 'AI_FRIENDLY_MULT', 'SCALE_ON', 'ENEMY_MULT',
             'HERO_MULT', 'SMOKE_TEST', 'SCREENSHOT_DIR', 'AUTO_MICRO', 'AUTOMICRO',
             'NEWHERO', 'ABILITY_VIS_AUDIT', 'GODOT_USER_HOME', 'LSH_CONTINUE_FLOW_QA',
             'LSH_CONTINUE_FLOW_PROFILE']


def no_links(path):
    path = Path(path)
    for item in [path, *path.parents]:
        if item.exists() or item.is_symlink():
            assert not item.is_symlink() and not getattr(item.lstat(), 'st_file_attributes', 0) & 0x400, str(item)


def sha(path):
    no_links(path)
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    no_links(path)
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_new(path, value):
    path = Path(path)
    no_links(path)
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
        stream.flush()
        os.fsync(stream.fileno())


def inventory(project):
    no_links(project)
    rows = []
    for path in sorted(Path(project).rglob('*')):
        no_links(path)
        if path.is_file() and '.godot' not in path.relative_to(project).parts:
            rows.append({'path': path.relative_to(project).as_posix(), 'bytes': path.stat().st_size, 'sha256': sha(path)})
    return rows


class FrozenProject:
    def __init__(self, project, source_inputs):
        self.project = Path(project)
        self.inputs = source_inputs
        self.before = None
        self.cold = None

    def prepare(self):
        no_links(self.project)
        self.project.mkdir(exist_ok=False)
        bridge = read(self.inputs['base_bridge']['path'])
        assert sha(self.inputs['base_bridge']['path']) == self.inputs['base_bridge']['sha256']
        assert bridge['complete'] and bridge['candidate_identity'] == self.inputs['base_identity']
        base = Path(bridge['candidate_root'])
        for row in self.inputs['base_identity']['files']:
            self._copy(base / row['path'], row['path'], row)
        for row in self.inputs['runtime_and_harness_overlays']:
            self._copy(Path(row['path']), row['runtime_path'], row)
        self.before = inventory(self.project)
        return self.before

    def _copy(self, source, relative, row):
        relative_path = Path(relative)
        assert not relative_path.is_absolute() and not relative_path.drive and not relative_path.root and '..' not in relative_path.parts and relative_path.as_posix() == relative
        no_links(source)
        target = self.project / relative_path
        no_links(target)
        assert target.resolve().is_relative_to(self.project.resolve()) and target.resolve() != self.project.resolve(), 'Source target outside project'
        assert source.stat().st_size == row['bytes'] and sha(source) == row['sha256']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
        assert target.stat().st_size == row['bytes'] and sha(target) == row['sha256']

    def check(self):
        bridge = self.inputs['base_bridge']
        assert sha(bridge['path']) == bridge['sha256'], 'Complete source bridge drift'
        base = Path(read(bridge['path'])['candidate_root'])
        for row in self.inputs['base_identity']['files']:
            path = base / row['path']
            no_links(path)
            assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], 'Base source drift: ' + row['path']
        for row in self.inputs['actual_semantic_Core_Contract']:
            assert sha(row['path']) == row['sha256'], 'Semantic source drift'
        for row in self.inputs['metadata_and_predecessor_reviews']:
            path = Path(row['path'])
            no_links(path)
            assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
        for row in self.inputs['runtime_and_harness_overlays']:
            assert sha(row['path']) == row['sha256']
        current = inventory(self.project)
        if self.cold is not None:
            assert current == self.cold, 'Post-cold complete installed source drift'
        else:
            assert self.before is not None
            actual = {row['path']: row for row in current}
            expected = {row['path']: row for row in self.before}
            assert all(actual.get(name) == row for name, row in expected.items()), 'Original installed bytes changed during import'
            for name in actual.keys() - expected.keys():
                assert name.endswith(('.import', '.uid')) and name.rsplit('.', 1)[0] in expected, 'Non-derived cold import addition'

    def freeze_cold(self):
        self.check()
        self.cold = inventory(self.project)
        return self.cold


class OwnedSerialBatch:
    def __init__(self, run, frozen, engine, engine_sha256, persist, deadline_seconds=21600):
        self.run = Path(run)
        self.frozen = frozen
        self.engine = Path(engine)
        self.engine_sha256 = engine_sha256
        self.persist = persist
        self.deadline = time.monotonic() + deadline_seconds
        self.child = None
        self.locked = False
        self.lease_identity = None
        self.lease_ready = False
        self.steps = []
        self.pids = set()
        self.nonces = set()

    def profile(self, name):
        assert re.fullmatch(r'[a-z0-9_]+', name)
        path = self.run / 'profiles' / name
        no_links(path)
        path.mkdir(parents=True, exist_ok=False)
        for key in ['appdata', 'localappdata', 'temp', 'tmp']:
            (path / key).mkdir()
        return path

    def integrity(self):
        assert time.monotonic() < self.deadline, 'Bounded batch deadline'
        assert sha(self.engine) == self.engine_sha256
        self.frozen.check()

    def release(self):
        if self.locked:
            assert self.child is None or self.child.poll() is not None, 'Owned child still live/unknown; lease retained'
            no_links(LOCK)
            current = LOCK.stat()
            if self.lease_identity is not None:
                assert (current.st_dev, current.st_ino) == self.lease_identity, 'Lease file replaced'
            raw = LOCK.read_text(encoding='utf-8')
            assert raw == str(self.run) or (not self.lease_ready and self.lease_identity is not None and str(self.run).startswith(raw)), 'Lease owner changed'
            LOCK.unlink()
            self.locked = False
            self.lease_identity = None
            self.lease_ready = False

    def idle(self):
        since = None
        notice = 0
        while True:
            assert time.monotonic() < self.deadline, 'Bounded batch deadline'
            no_links(LOCK)
            if engines() or LOCK.exists():
                since = None
            elif since is None:
                since = time.monotonic()
            if time.monotonic() - notice >= 30:
                print('WAIT durable full: continuous idle60', flush=True)
                notice = time.monotonic()
            if since is not None and time.monotonic() - since >= 60:
                self.integrity()
                try:
                    with LOCK.open('x', encoding='utf-8') as stream:
                        self.locked = True
                        acquired = os.fstat(stream.fileno())
                        self.lease_identity = (acquired.st_dev, acquired.st_ino)
                        stream.write(str(self.run))
                        stream.flush()
                        os.fsync(stream.fileno())
                except FileExistsError:
                    since = None
                    continue
                self.lease_ready = True
                if engines():
                    self.release()
                    since = None
                    continue
                return
            time.sleep(2)

    def phase(self, label, profile, arguments, values, validator, timeout_seconds=1800, expected_exit=0):
        assert self.child is None and re.fullmatch(r'[a-z0-9_]+', label)
        profile = Path(profile)
        no_links(profile)
        assert profile.resolve().is_relative_to((self.run / 'profiles').resolve())
        output = self.run / 'steps' / label
        no_links(output)
        log = output / 'native.log'
        nonce = uuid.uuid4().hex
        assert nonce not in self.nonces
        self.nonces.add(nonce)
        command = [str(self.engine), '--path', str(self.frozen.project), *arguments]
        step = {'label': label, 'case': label, 'command': command, 'profile': str(profile), 'output': str(output), 'nonce': nonce,
                'expected_exit': expected_exit, 'complete': False, 'process_terminal': False, 'CAMPAIGN_QA_enabled': label in {'json_boundary', 'owned_slot_retry'}}
        self.steps.append(step)
        started = time.monotonic()
        notice = 0
        try:
            self.idle()
            started = time.monotonic()
            output.mkdir(parents=True, exist_ok=False)
            if callable(values):
                values = values(output, nonce)
            assert isinstance(values, dict) and all(isinstance(k, str) and isinstance(v, str) for k, v in values.items())
            assert set(k.upper() for k in values).isdisjoint({'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'CAMPAIGN_QA', 'STEAM_DISABLED', 'GODOT_USER_HOME', 'LSH_CONTINUE_FLOW_QA', 'LSH_CONTINUE_FLOW_PROFILE'})
            env = os.environ.copy()
            for key in list(env):
                if key.upper() in CLEAR_ENV or key.upper().startswith(('LSH_', 'ART_', 'DAMING_', 'V25_')) or key.upper().endswith(('_TEST', '_QA', '_QA_MANIFEST', '_AUDIT')):
                    env.pop(key)
            env.update({key: str(profile / key.lower()) for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']})
            env.update(STEAM_DISABLED='1', CAMPAIGN_QA='1' if label in {'json_boundary', 'owned_slot_retry'} else '')
            env.update(values)
            step['environment_overrides'] = {key: env[key] for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'STEAM_DISABLED', *values]}
            self.persist()
            assert not engines()
            with log.open('xb') as stream:
                step['native_started_ns'] = time.monotonic_ns()
                self.child = subprocess.Popen(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                              creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                step['pid'] = self.child.pid
                assert self.child.pid not in self.pids, 'Native PID reused'
                self.pids.add(self.child.pid)
                self.persist()
                while self.child.poll() is None:
                    assert time.monotonic() < self.deadline and time.monotonic() - started < timeout_seconds
                    assert not (engines() - {self.child.pid}), 'Foreign engine after owned child start'
                    assert error_count(log) == 0, 'Native engine error'
                    if time.monotonic() - notice >= 25:
                        print('RUNNING ' + label + ' ' + str(round(time.monotonic() - started)) + 's', flush=True)
                        notice = time.monotonic()
                    time.sleep(.2)
                self.child.wait(timeout=30)
            step.update(native_finished_ns=time.monotonic_ns(), exit_code=self.child.returncode, process_terminal=True, log_sha256=sha(log),
                        engine_errors=error_count(log))
            assert self.child.returncode == expected_exit and not step['engine_errors']
            validator(step, output, nonce)
            self.integrity()
            self.child = None
            self.release()
            step['complete'] = True
            self.persist()
            return step
        except BaseException as error:
            step['failure'] = repr(error)
            step['complete'] = False
            try:
                if self.child is not None:
                    if self.child.poll() is None:
                        self.child.kill()
                    self.child.wait(timeout=30)
                    step.update(exit_code=self.child.returncode, process_terminal=True)
                    step.update(log_sha256=sha(log), engine_errors=error_count(log))
            except BaseException as cleanup:
                step.setdefault('cleanup_failures', []).append(repr(cleanup))
            finally:
                if self.child is not None:
                    try:
                        result = self.child.poll()
                        if result is not None:
                            step.update(exit_code=result, process_terminal=True)
                            self.child = None
                        else:
                            step['process_terminal'] = False
                            step['owned_child_retained'] = True
                    except BaseException as cleanup:
                        step['process_terminal'] = False
                        step['owned_child_retained'] = True
                        step.setdefault('cleanup_failures', []).append(repr(cleanup))
                try:
                    self.release()
                except BaseException as cleanup:
                    step.setdefault('cleanup_failures', []).append(repr(cleanup))
                try:
                    self.persist()
                except BaseException as cleanup:
                    step.setdefault('cleanup_failures', []).append(repr(cleanup))
            raise
