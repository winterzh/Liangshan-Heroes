"""Owned real cloud applying phase with original breakpoint/arm/ack custody.

No CLI, producer or self execution admission. The future complete consumer must
replay original packets/arm/terminal tail and validate reports and real CFG journals.
Cold import and ordinary same-profile restart retain the reviewed parent phase.
"""
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid

from campaign_cloud_arm_controller_v1 import CloudArmController as CallbackController
from campaign_cloud_arm_raw_receiver_v1 import CallbackRawReceiver
from campaign_cloud_applying_exports_v1 import CallbackNativeExports
from campaign_callback_snapshot_wire_v1 import CallbackSnapshotConnection
from campaign_callback_packets_v2 import same
from campaign_natural_terminal_runtime_v1 import NaturalSerialBatch
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import CLEAR_ENV, no_links, sha, error_count
from run_workstation_baseline import engines
from godot_debug_wire import WireError

CASE='cloud_applying_callback_no_upload_claim'
GD='campaign_original19_cloud_applying_v2.gd'


def sealed_document(suite,path,digest):
    path=Path(path);no_links(path)
    require(any(Path(p['path']).resolve()==path.resolve() and p['sha256']==digest for p in suite.spec['pins']), 'Phase document must be in producer source seal')
    return suite.read_fixed(path,digest)


def validate_callback_environment(suite,step,values):
    require(type(values) is dict and all(type(k) is str and type(v) is str for k,v in values.items()), 'Exact string callback environment')
    forbidden={'APPDATA','LOCALAPPDATA','TEMP','TMP','CAMPAIGN_QA','STEAM_DISABLED','GODOT_USER_HOME','LSH_CONTINUE_FLOW_QA','LSH_CONTINUE_FLOW_PROFILE'}
    require({k.upper() for k in values}.isdisjoint(forbidden) and len({k.upper() for k in values})==len(values), 'No protected keys or Windows aliases')
    path=Path(suite.identity_path);no_links(path)
    require(path.resolve().is_relative_to(suite.run.resolve()), 'Current owned post-cold identity')
    key=str(path.resolve()).casefold();require(key in suite.evidence_by_path, 'Original identity pin before launch')
    pin=suite.evidence_by_path[key];doc=suite.read_fixed(path,pin['sha256'])
    require(type(doc) is dict and set(doc)=={'runtime_fields','complete_identity'} and same(doc['runtime_fields'],suite.runtime_fields)
            and same(doc['complete_identity'],suite.installed_identity), 'Complete original post-cold identity')
    expected={'CAMPAIGN_CALLBACK_CASE':CASE,'CAMPAIGN_TERMINAL_OUTPUT':step['output'],'CAMPAIGN_TERMINAL_NONCE':step['nonce'],
              'CAMPAIGN_TERMINAL_MODE':'first','CAMPAIGN_TERMINAL_PROFILE':step['profile'],'CAMPAIGN_TERMINAL_TOKEN':'',
              'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(path),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256'],
              'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':'','CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':'','CAMPAIGN_TERMINAL_PRIOR_TOKEN':''}
    require(values==expected, 'Exact owned fresh callback environment before Popen')


def drain_terminal_tail(suite,batch,controller,receiver,connection,deadline):
    require(batch.child is controller.child and controller.child.poll() is not None and controller.complete
            and controller.entered is None and not controller.waiting, 'Only retained terminal Popen after complete observation')
    if receiver.frames.buffer:
        controller._retain('terminal_tail_prefix',bytes(receiver.frames.buffer))
    rows=[]
    while True:
        require(time.monotonic()<deadline, 'Bounded terminal transport closure')
        try:chunk=connection.recv(65536)
        except socket.timeout:continue
        if not chunk:
            controller._retain('terminal_transport_eof',b'CALLBACK_TERMINAL_TRANSPORT_EOF\n')
            receiver.stopped=True
            return rows
        rows.append(controller._retain('terminal_tail_bytes',chunk))
        # Original stream bytes remain; the future complete consumer must parse
        # the prefix+tail, reject truncated/unknown packets and bind final events.


def completed_terminal_transition(error,batch,controller,step):
    # The child may exit between the outer poll and a guarded receive. Only this
    # precise ownership guard is recognized; decode/source/custody errors fail.
    return (type(error) is WireError and str(error)=='Original owned Popen still live'
            and not getattr(error,'__notes__',[]) and controller is not None
            and batch.child is controller.child and controller.child.pid==step['pid']
            and controller.child.poll()==0 and controller.complete
            and controller.entered is None and not controller.waiting)


class CloudApplyingSerialBatch(NaturalSerialBatch):
    def cloud_apply_phase(self,suite,manifest_path,manifest_sha256,map_path,map_sha256,profile,values,validator,timeout_seconds=1800):
        require(suite.batch is self and self.child is None and type(timeout_seconds) is int and 0<timeout_seconds<=1800, 'Owned idle batch and bounded natural callback phase')
        source_manifest=sealed_document(suite,manifest_path,manifest_sha256)
        sealed_document(suite,map_path,map_sha256)
        require(source_manifest['case']==CASE and source_manifest['required_mode']=='first'
                and Path(source_manifest['candidate']['path']).name==GD, 'Fixed reviewed real cloud apply driver')
        require([Path(source_manifest[key]['path']).name for key in ['parent_GD','observer_GD','observer_parent_GD']]
                ==['campaign_original19_first_repeat_v1.gd','campaign_cloud_callback_observer_v2.gd','campaign_callback_snapshot_v1.gd'],
                'Exact parent and arm/read-only observer native aliases')
        for key in ['candidate','parent_GD','observer_GD','observer_parent_GD']:
            pin=source_manifest[key]
            require(any(Path(p['path']).resolve()==Path(pin['path']).resolve() and p['sha256']==pin['sha256'] for p in suite.spec['pins']), 'Every native driver dependency in producer seal')
            suite.freeze_bytes(pin['path'],pin['sha256'])
        profile=Path(profile);no_links(profile)
        require(profile.resolve().is_relative_to((self.run/'profiles').resolve()), 'Current owned private profile')
        label='cloud_applying';output=self.run/'steps'/label;no_links(output);log=output/'native.log'
        nonce=uuid.uuid4().hex;require(nonce not in self.nonces, 'Unique actual callback nonce');self.nonces.add(nonce)
        step={'label':label,'case':CASE,'mode':'first','profile':str(profile),'output':str(output),'nonce':nonce,
              'complete':False,'process_terminal':False,'expected_exit':0,'CAMPAIGN_QA_enabled':False,'actual_callback_qualified':False,'full_original19_qualified':False}
        self.steps.append(step);listener=connection=peer=controller=exports=receiver=None;notice=0;started=time.monotonic()
        try:
            self.idle();started=time.monotonic();output.mkdir(parents=True,exist_ok=False)
            if callable(values):values=values(output,nonce)
            validate_callback_environment(suite,step,values)
            env=os.environ.copy()
            for key in list(env):
                if key.upper() in CLEAR_ENV or key.upper().startswith(('LSH_','ART_','DAMING_','V25_')) or key.upper().endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')):env.pop(key)
            env.update({key:str(profile/key.lower()) for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']});env.update(STEAM_DISABLED='1');env.update(values)
            listener=socket.socket(socket.AF_INET,socket.SOCK_STREAM);listener.bind(('127.0.0.1',0));listener.listen(1);listener.settimeout(.15)
            endpoint='tcp://127.0.0.1:'+str(listener.getsockname()[1])
            command=[str(self.engine),'--path',str(self.frozen.project),'--headless','--script','res://tools/'+GD,'--remote-debug',endpoint]
            step.update(command=command,debugger_endpoint=endpoint,environment_overrides={key:env[key] for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP','STEAM_DISABLED',*values]})
            self.persist();suite.integrity();require(not engines(), 'No foreign engine before owned launch')
            with log.open('xb') as stream:
                self.child=subprocess.Popen(command,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
                step['pid']=self.child.pid;require(self.child.pid not in self.pids, 'Unique actual native PID');self.pids.add(self.child.pid)
                exports=CallbackNativeExports(suite,step);self.persist()
                while self.child.poll() is None:
                    require(time.monotonic()<self.deadline and time.monotonic()-started<timeout_seconds, 'Bounded owned natural callback phase')
                    require(not (engines()-{self.child.pid}), 'Foreign engine during owned callback phase')
                    require(error_count(log)==0, 'Zero actual native diagnostics');exports.publish()
                    if time.monotonic()-notice>=25:
                        print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);notice=time.monotonic()
                    if listener is not None:
                        try:connection,address=listener.accept()
                        except socket.timeout:continue
                        require(address[0]=='127.0.0.1', 'Actual loopback peer only');listener.close();listener=None
                        connection.settimeout(.15);peer=CallbackSnapshotConnection(connection)
                    if controller is None and peer is not None and {'callback_driver_ready.json','cloud_apply_ready.json'}<=set(exports.rows):
                        ready=exports.rows['callback_driver_ready.json']
                        apply_ready=exports.rows['cloud_apply_ready.json']
                        controller=CallbackController(suite,self.child,step,peer,CASE,ready['published_path'],ready['sha256'],map_path,map_sha256,
                                                      apply_ready['published_path'],apply_ready['sha256'])
                        receiver=CallbackRawReceiver(controller);self.persist()
                    if receiver is not None and connection is not None:
                        try:receiver.receive_one()
                        except socket.timeout:continue
                        except EOFError:
                            step['debugger_closed_before_process_terminal']=self.child.poll() is None
                            require(controller.complete and not receiver.frames.buffer and controller.entered is None and not controller.waiting, 'No early or truncated transport closure')
                            connection.close();connection=None;peer=None
                        except WireError as error:
                            require(completed_terminal_transition(error,self,controller,step),
                                    'Only a completed actual terminal transition may end guarded receive')
                            step['terminal_transition_guard_observed']=True
                            break
                    else:time.sleep(.2)
                self.child.wait(timeout=30)
                if connection is not None:
                    require(controller is not None and receiver is not None, 'Actual observer constructed before terminal')
                    step['terminal_tail']=drain_terminal_tail(suite,self,controller,receiver,connection,min(self.deadline,time.monotonic()+30))
            step.update(exit_code=self.child.returncode,process_terminal=True,log_sha256=sha(log),engine_errors=error_count(log))
            require(self.child.returncode==0 and not step['engine_errors'] and controller is not None and controller.complete, 'Actual terminal zero after complete stack observation')
            exports.require_complete(CASE);suite.freeze_bytes(log,step['log_sha256'])
            step['callback_observation']=controller.observation_result();self.persist()
            validator(step,output,nonce);suite.integrity();self.integrity()
            self.child=None;self.release();step['complete']=True;self.persist();return step
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
