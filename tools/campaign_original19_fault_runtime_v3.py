"""Owned serial loopback file-fault phase; no CLI or self execution admission.

Ordinary phases retain the immutable full runtime. A future reviewed producer
must bind its complete native reports and evidence before granting any scope.
"""
import hashlib
import os
from pathlib import Path
import re
import socket
import struct
import subprocess
import time
import uuid

from campaign_original19_debug_faults_v5 import FaultController, typed_equal, FLOW
from campaign_original19_native_exports_v1 import NativeExports
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import OwnedSerialBatch, CLEAR_ENV, ANSI, no_links, sha
from godot_debug_wire import DebugConnection, stack_frames
from run_workstation_baseline import engines

CASES=('bad_existing_cfg_load','existing_vanished_prior','write_failure',
       'save_OK_fresh_load_failure','readback_semantic_mismatch','readback_SHA_changed')
ERROR_LINE=re.compile(r'^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)')


def validate_phase_environment(suite, step, values):
    require(type(values) is dict and all(type(k) is str and type(v) is str for k,v in values.items()), 'Exact string native environment')
    forbidden={'APPDATA','LOCALAPPDATA','TEMP','TMP','CAMPAIGN_QA','STEAM_DISABLED','GODOT_USER_HOME','LSH_CONTINUE_FLOW_QA','LSH_CONTINUE_FLOW_PROFILE'}
    require({k.upper() for k in values}.isdisjoint(forbidden) and len({k.upper() for k in values})==len(values), 'Protected normal-mode profile environment without Windows key aliases')
    identity=Path(suite.identity_path); no_links(identity)
    require(identity.resolve().is_relative_to(suite.run.resolve()), 'Current owned installed identity artifact')
    key=str(identity.resolve()).casefold()
    require(key in suite.evidence_by_path, 'Identity requires original post-cold pin before phase')
    first=suite.evidence_by_path[key]; suite.freeze_bytes(identity,first['sha256'])
    document=suite.read_fixed(identity)
    require(type(document) is dict and set(document)=={'runtime_fields','complete_identity'}
            and typed_equal(document['runtime_fields'],suite.runtime_fields), 'Original complete post-cold identity field binding')
    expected={'CAMPAIGN_FILE19_CASE':step['case'],'CAMPAIGN_TERMINAL_MODE':'fresh',
              'CAMPAIGN_TERMINAL_OUTPUT':step['output'],'CAMPAIGN_TERMINAL_PROFILE':step['profile'],
              'CAMPAIGN_TERMINAL_NONCE':step['nonce'],'CAMPAIGN_TERMINAL_TOKEN':'',
              'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(identity),
              'CAMPAIGN_TERMINAL_IDENTITY_SHA256':first['sha256']}
    require(all(values.get(k)==v for k,v in expected.items()), 'Exact current owned output/profile/nonce/case/identity before launch')


def diagnostic_budget(log, controller, terminal=False):
    raw=Path(log).read_bytes()
    if not terminal: raw=raw[:raw.rfind(b'\n')+1]
    text=ANSI.sub('',raw.decode('utf-8',errors='strict'))
    # An in-flight final line is never adopted as a complete diagnostic.
    lines=text.splitlines(keepends=True)
    if not terminal and lines and not lines[-1].endswith(('\n','\r')): lines.pop()
    errors=[line.rstrip('\r\n') for line in lines if ERROR_LINE.match(line)]
    allowed=[]
    if controller.case=='bad_existing_cfg_load' and controller.injection is not None:
        target=str(controller.target).replace('\\','/')
        allowed=['ERROR: ConfigFile parse error at '+target+':0: Unexpected EOF while parsing simple tag.']
    require(len(errors)<=len(allowed) and all(line in allowed for line in errors), 'Only precise owned malformed-CFG diagnostic is allowed')
    if terminal:
        require(errors==allowed, 'Exact final malformed-CFG count; all other cases have zero diagnostics')
        if errors:
            for index,line in enumerate(lines):
                if not ERROR_LINE.match(line): continue
                block=[v.rstrip('\r\n') for v in lines[index+1:index+4]]
                require(block==['   at: _parse (core/io/config_file.cpp:292)',
                                '   GDScript backtrace (most recent call first):',
                                '       [0] _stable_cfg (res://scripts/run_campaign_cfg_transaction.gd:146)'],
                        'Parser and R12 load frame must immediately belong to the allowed ERROR block')
    return {'total':len(errors),'expected_owned_malformed_CFG':len(allowed),
            'actual_complete_error_lines':errors,'SCRIPT_errors':0,'Parse_errors':0,
            'write_denial_extra_budget':0,'terminal':terminal}


class FaultSerialBatch(OwnedSerialBatch):
    def fault_phase(self, suite, case, source_manifest, profile, arguments, values, validator, timeout_seconds=1800):
        require(suite.batch is self and self.child is None and tuple(source_manifest['case_ids'])==CASES and case in CASES, 'Exact six cases and owned serial suite')
        require(arguments==['--headless','--script','res://tools/'+Path(source_manifest['candidate']['path']).name]
                and type(timeout_seconds) is int and 0<timeout_seconds<=1800, 'Fixed natural probe and bounded fresh fault phase')
        profile=Path(profile); no_links(profile)
        require(profile.resolve().is_relative_to((self.run/'profiles').resolve()), 'Current owned profile only')
        label='fault_'+case.lower(); require(re.fullmatch('[a-z0-9_]+',label), 'Fixed owned phase label')
        output=self.run/'steps'/label; no_links(output)
        log=output/'native.log'; transcript=output/'debugger_packets.bin'
        nonce=uuid.uuid4().hex; require(nonce not in self.nonces, 'Fresh unique native nonce'); self.nonces.add(nonce)
        step={'label':label,'case':case,'profile':str(profile),'output':str(output),'nonce':nonce,
              'complete':False,'process_terminal':False,'expected_exit':0,'CAMPAIGN_QA_enabled':False,
              'full_original19_qualified':False}
        self.steps.append(step); listener=connection=peer=controller=exports=None
        notice=0; started=time.monotonic()
        try:
            self.idle(); started=time.monotonic(); output.mkdir(parents=True,exist_ok=False)
            if callable(values): values=values(output,nonce)
            validate_phase_environment(suite,step,values)
            env=os.environ.copy()
            for key in list(env):
                if key.upper() in CLEAR_ENV or key.upper().startswith(('LSH_','ART_','DAMING_','V25_')) or key.upper().endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')): env.pop(key)
            env.update({key:str(profile/key.lower()) for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']}); env.update(STEAM_DISABLED='1'); env.update(values)
            listener=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
            listener.bind(('127.0.0.1',0)); listener.listen(1); listener.settimeout(.15)
            endpoint='tcp://127.0.0.1:'+str(listener.getsockname()[1])
            command=[str(self.engine),'--path',str(self.frozen.project),*arguments,'--remote-debug',endpoint]
            step.update(command=command,debugger_endpoint=endpoint,
                        environment_overrides={key:env[key] for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP','STEAM_DISABLED',*values]})
            self.persist(); suite.integrity(); require(not engines(), 'No foreign engine immediately before owned launch')
            with log.open('xb') as stream, transcript.open('xb') as wire:
                self.child=subprocess.Popen(command,env=env,stdout=stream,stderr=subprocess.STDOUT,
                                            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
                step['pid']=self.child.pid; require(self.child.pid not in self.pids, 'Native PID not reused'); self.pids.add(self.child.pid)
                controller=FaultController(suite,self.child,step,case,source_manifest); exports=NativeExports(suite,step); self.persist()
                while self.child.poll() is None:
                    require(time.monotonic()<self.deadline and time.monotonic()-started<timeout_seconds, 'Bounded owned fault phase')
                    require(not (engines()-{self.child.pid}), 'Foreign engine during owned fault phase')
                    exports.publish()
                    step['native_diagnostic_budget']=diagnostic_budget(log,controller)
                    controller.repair_if_pending()
                    if time.monotonic()-notice>=25:
                        print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True); notice=time.monotonic()
                    if listener is not None:
                        try: connection,address=listener.accept()
                        except socket.timeout: continue
                        require(address[0]=='127.0.0.1', 'Owned loopback peer only')
                        listener.close(); listener=None; connection.settimeout(.15); peer=DebugConnection(connection)
                    if peer is not None:
                        try: message,packet=peer.receive()
                        except socket.timeout: continue
                        except EOFError:
                            # A closed transport does not prove process termination.
                            peer=None; connection.close(); connection=None
                            step['debugger_closed_before_process_terminal']=self.child.poll() is None
                            require(controller.injection is not None and controller.repaired and controller.entered is None, 'Transport cannot close before owned fault and repair complete')
                            continue
                        wire.write(struct.pack('<I',len(packet))); wire.write(packet); wire.flush()
                        exports.publish()
                        if message[0]=='stack_dump' and controller.injection is None:
                            frames=stack_frames(message[2])
                            if any(f['source']==FLOW and f['function']=='_commit_terminal' for f in frames):
                                exports.wait_for_ready(self.child,min(self.deadline,started+timeout_seconds))
                        controller.handle(peer,message)
                    else: time.sleep(.2)
                self.child.wait(timeout=30); wire.flush(); os.fsync(wire.fileno())
            step.update(exit_code=self.child.returncode,process_terminal=True,log_sha256=sha(log))
            require(self.child.returncode==0 and controller.armed and controller.injection is not None
                    and controller.repaired and controller.entered is None, 'Actual owned injection/repair and terminal success required')
            step['native_diagnostic_budget']=diagnostic_budget(log,controller,terminal=True)
            exports.require_complete('fresh')
            step['engine_errors']=step['native_diagnostic_budget']['total']
            suite.freeze_bytes(log,step['log_sha256']); suite.freeze_bytes(transcript)
            step['debugger_transcript_sha256']=sha(transcript)
            validator(step,output,nonce); suite.integrity(); self.integrity()
            self.child=None; self.release(); step['complete']=True; self.persist(); return step
        except BaseException as error:
            step.update(failure=repr(error),complete=False)
            try:
                if self.child is not None:
                    if self.child.poll() is None: self.child.kill()
                    self.child.wait(timeout=30); step.update(exit_code=self.child.returncode,process_terminal=True)
                    if log.is_file(): step['log_sha256']=sha(log)
            except BaseException as cleanup: step.setdefault('cleanup_failures',[]).append(repr(cleanup))
            finally:
                if self.child is not None:
                    try:
                        result=self.child.poll()
                        if result is not None: step.update(exit_code=result,process_terminal=True); self.child=None
                        else: step.update(process_terminal=False,owned_child_retained=True)
                    except BaseException as cleanup:
                        step.update(process_terminal=False,owned_child_retained=True); step.setdefault('cleanup_failures',[]).append(repr(cleanup))
                try: self.release()
                except BaseException as cleanup: step.setdefault('cleanup_failures',[]).append(repr(cleanup))
                try: self.persist()
                except BaseException as cleanup: step.setdefault('cleanup_failures',[]).append(repr(cleanup))
            raise
        finally:
            if connection is not None: connection.close()
            if listener is not None: listener.close()
