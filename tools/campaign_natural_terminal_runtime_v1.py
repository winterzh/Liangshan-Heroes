"""Owned serial ordinary first/repeat export phase. No CLI or native admission.

Cold import retains the exact inherited phase. This component cannot replace
the future complete producer, ordered report validator or prior-success gate.
"""
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

from campaign_natural_terminal_exports_v1 import NaturalNativeExports
from campaign_original19_debug_faults_v5 import typed_equal
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import OwnedSerialBatch,CLEAR_ENV,no_links,sha,error_count
from run_workstation_baseline import engines

MODES=('first','restart_first','repeat','restart_repeat')
CASES=('normal_first_full_seal','normal_repeat_full')


def actual_handoff(suite,kind):
    path=Path(getattr(suite,kind+'_handoff_path'));no_links(path)
    require(path.resolve().is_relative_to((suite.run/'steps').resolve()), 'Original handoff from current owned steps')
    key=str(path.resolve()).casefold();require(key in suite.evidence_by_path, 'Handoff requires original native publication pin')
    first=suite.evidence_by_path[key];suite.freeze_bytes(path,first['sha256']);value=suite.read_fixed(path)
    require(type(value) is dict and value.get('schema')=='campaign_natural_terminal_handoff_v1'
            and value.get('case')==CASES[0 if kind=='first' else 1]
            and type(value.get('token')) is str and re.fullmatch('[0-9a-f]{32}',value['token']), 'Actual case-bound terminal handoff token')
    return path,first,value


def validate_natural_environment(suite,step,values):
    require(type(values) is dict and all(type(k) is str and type(v) is str for k,v in values.items()), 'Exact string phase environment')
    forbidden={'APPDATA','LOCALAPPDATA','TEMP','TMP','CAMPAIGN_QA','STEAM_DISABLED','GODOT_USER_HOME','LSH_CONTINUE_FLOW_QA','LSH_CONTINUE_FLOW_PROFILE'}
    require({k.upper() for k in values}.isdisjoint(forbidden) and len({k.upper() for k in values})==len(values), 'Protected profile keys without Windows aliases')
    mode=step['mode'];require(mode in MODES, 'Known actual native mode')
    identity=Path(suite.identity_path);no_links(identity)
    require(identity.resolve().is_relative_to(suite.run.resolve()), 'Owned post-cold identity file')
    key=str(identity.resolve()).casefold();require(key in suite.evidence_by_path, 'Identity original first pin required')
    first=suite.evidence_by_path[key];suite.freeze_bytes(identity,first['sha256']);document=suite.read_fixed(identity)
    require(type(document) is dict and set(document)=={'runtime_fields','complete_identity'}
            and typed_equal(document['runtime_fields'],suite.runtime_fields)
            and typed_equal(document['complete_identity'],suite.installed_identity), 'Exact complete original post-cold source identity')
    token='';prior_path=prior_sha=prior_token=''
    if mode.startswith('restart_'):
        _,_,handoff=actual_handoff(suite,mode.removeprefix('restart_'));token=handoff['token']
    if mode=='repeat':
        path,pin,handoff=actual_handoff(suite,'first');prior_path=str(path);prior_sha=pin['sha256'];prior_token=handoff['token']
    expected={'CAMPAIGN_TERMINAL_OUTPUT':step['output'],'CAMPAIGN_TERMINAL_NONCE':step['nonce'],
              'CAMPAIGN_TERMINAL_MODE':mode,'CAMPAIGN_TERMINAL_PROFILE':step['profile'],
              'CAMPAIGN_TERMINAL_TOKEN':token,'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0',
              'CAMPAIGN_TERMINAL_IDENTITY_FILE':str(identity),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':first['sha256'],
              'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':prior_path,'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':prior_sha,
              'CAMPAIGN_TERMINAL_PRIOR_TOKEN':prior_token}
    require(values==expected, 'Exact owned output/profile/nonce/mode and first original handoff before Popen')


class NaturalSerialBatch(OwnedSerialBatch):
    def phase_with_exports(self, suite, mode, source_manifest, label, profile, arguments, values, validator, timeout_seconds=1800, expected_exit=0):
        require(suite.batch is self and mode in MODES and label==mode and expected_exit==0, 'Exact owned natural first/repeat phase')
        require(arguments==['--headless','--script','res://tools/'+Path(source_manifest['candidate']['path']).name]
                and source_manifest['case_ids']==list(CASES) and type(timeout_seconds) is int and 0<timeout_seconds<=1800, 'Fixed reviewed natural probe and bounded phase')
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
        step = {'label': label, 'command': command, 'profile': str(profile), 'output': str(output), 'nonce': nonce,
                'mode':mode, 'expected_exit': expected_exit, 'complete': False, 'process_terminal': False, 'CAMPAIGN_QA_enabled': False}
        self.steps.append(step)
        started = time.monotonic()
        notice = 0
        try:
            self.idle()
            started = time.monotonic()
            output.mkdir(parents=True, exist_ok=False)
            if callable(values):
                values = values(output, nonce)
            validate_natural_environment(suite, step, values)
            assert set(k.upper() for k in values).isdisjoint({'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'CAMPAIGN_QA', 'STEAM_DISABLED', 'GODOT_USER_HOME', 'LSH_CONTINUE_FLOW_QA', 'LSH_CONTINUE_FLOW_PROFILE'})
            env = os.environ.copy()
            for key in list(env):
                if key.upper() in CLEAR_ENV or key.upper().startswith(('LSH_', 'ART_', 'DAMING_', 'V25_')) or key.upper().endswith(('_TEST', '_QA', '_QA_MANIFEST', '_AUDIT')):
                    env.pop(key)
            env.update({key: str(profile / key.lower()) for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']})
            env.update(STEAM_DISABLED='1')
            env.update(values)
            step['environment_overrides'] = {key: env[key] for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'STEAM_DISABLED', *values]}
            self.persist()
            assert not engines()
            with log.open('xb') as stream:
                self.child = subprocess.Popen(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                              creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                step['pid'] = self.child.pid
                assert self.child.pid not in self.pids, 'Native PID reused'
                self.pids.add(self.child.pid)
                self.persist()
                exports=NaturalNativeExports(suite,step)
                while self.child.poll() is None:
                    assert time.monotonic() < self.deadline and time.monotonic() - started < timeout_seconds
                    assert not (engines() - {self.child.pid}), 'Foreign engine after owned child start'
                    assert error_count(log) == 0, 'Native engine error'
                    exports.publish()
                    if time.monotonic() - notice >= 25:
                        print('RUNNING ' + label + ' ' + str(round(time.monotonic() - started)) + 's', flush=True)
                        notice = time.monotonic()
                    time.sleep(.2)
                self.child.wait(timeout=30)
            step.update(exit_code=self.child.returncode, process_terminal=True, log_sha256=sha(log),
                        engine_errors=error_count(log))
            assert self.child.returncode == expected_exit and not step['engine_errors']
            exports.require_complete(mode)
            suite.freeze_bytes(log,step['log_sha256'])
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
