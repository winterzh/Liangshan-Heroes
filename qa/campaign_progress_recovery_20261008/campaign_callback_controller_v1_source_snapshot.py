"""Owned read-only callback breakpoint controller; no launcher or admission.

Only the two actual mark_dirty callback paths are observed here. The third
cloud file-failure case needs a separately reviewed fault driver. This component
does not qualify callback outcomes, restarts, the SDK, or the whole goal.
"""
import copy
import hashlib
import os
from pathlib import Path
import socket
import struct
import subprocess

from campaign_callback_packets_v2 import CallbackPackets, raw_envelope, same, need
from campaign_callback_snapshot_wire_v1 import CallbackSnapshotConnection, COMMAND
from durable_campaign_full_runtime import no_links
from godot_debug_wire import encode, stack_frames, MAX_PACKET

CLOUD = 'res://scripts/steam_cloud.gd'
CAMPAIGN = 'res://scripts/campaign.gd'
COORD = 'res://scripts/run_campaign_progress_coordinator.gd'
STOP = {'source':CLOUD,'line':230,'function':'mark_dirty'}
STACKS = {
    'callback_sees_new_memory':[
        STOP, {'source':CAMPAIGN,'line':405,'function':'progress_committed'},
        {'source':COORD,'line':189,'function':'retry'}],
    'cloud_applying_callback_no_upload_claim':[
        STOP, {'source':CAMPAIGN,'line':350,'function':'_writer_complete'},
        {'source':CAMPAIGN,'line':327,'function':'_write_values'},
        {'source':CAMPAIGN,'line':396,'function':'apply_cloud_progress'},
        {'source':CLOUD,'line':415,'function':'_apply_profile'}],
}


def matches_stack(case, frames):
    need(case in STACKS, 'Only the two actual callback stack cases')
    expected = STACKS[case]
    return len(frames)>=len(expected) and same(frames[:len(expected)],expected)


class CallbackController:
    def __init__(self, suite, child, step, peer, case, driver_ready_path, driver_ready_sha256, source_map_path, source_map_sha256):
        need(case in STACKS, 'Callback observer does not inject cloud file faults')
        need(isinstance(child,subprocess.Popen) and suite.batch.child is child
             and child.poll() is None and type(child.pid) is int and child.pid==step['pid'],
             'Actual retained owned live Popen')
        need(type(peer) is CallbackSnapshotConnection and type(peer.connection) is socket.socket
             and peer.connection.getpeername()[0]=='127.0.0.1', 'Actual loopback transport')
        self.suite,self.child,self.step,self.peer,self.case = suite,child,step,peer,case
        self.output,self.profile = Path(step['output']),Path(step['profile'])
        driver_ready_path=Path(driver_ready_path);no_links(driver_ready_path)
        need(driver_ready_path.resolve().is_relative_to(self.output.resolve()), 'Current driver ready artifact')
        ready=suite.read_fixed(driver_ready_path,driver_ready_sha256)
        need(type(ready) is dict and set(ready)=={'schema','pid','nonce','case','identity','user_directory'}
             and ready['schema']=='campaign_callback_driver_ready_v1'
             and type(ready['pid']) is int and ready['pid']==child.pid
             and ready['nonce']==step['nonce'] and ready['case']==case, 'Actual driver ready binding')
        user_directory=ready['user_directory'];self.user = Path(user_directory)
        for p in [self.output,self.profile,self.user]: no_links(p)
        need(self.output.is_dir() and self.output.resolve().is_relative_to(suite.run.resolve())
             and self.profile.resolve().is_relative_to((suite.run/'profiles').resolve())
             and self.user.is_absolute() and self.user.resolve().is_relative_to((self.profile/'appdata').resolve()),
             'Current owned output/profile/user boundaries')
        identity_doc = suite.read_fixed(suite.identity_path)
        need(same(identity_doc['runtime_fields'],suite.runtime_fields)
             and same(identity_doc['complete_identity'],suite.installed_identity),
             'Actual post-cold installed identity binding')
        need(type(ready['identity']) is dict and ready['identity'].get('save_eligible') is True
             and all(k in ready['identity'] and same(ready['identity'][k],v) for k,v in suite.runtime_fields.items()),
             'Actual driver complete native identity matches all sealed runtime fields')
        self.packets = CallbackPackets(child.pid,step['nonce'],case,ready['identity'],user_directory)
        source_map_path=Path(source_map_path)
        need(any(Path(pin['path']).resolve()==source_map_path.resolve() and pin['sha256']==source_map_sha256
                 for pin in suite.spec['pins']), 'Source map must be in the producer source seal')
        self._verify_map(suite.read_fixed(source_map_path,source_map_sha256))
        self.live()
        self.directory = self.output/'callback_packets'
        no_links(self.directory); self.directory.mkdir(exist_ok=False)
        self.events=[];self.total_bytes=0;self.armed=False;self.entered=None
        self.waiting=False;self.snapshot=None;self.frames=None;self.complete=False;self.ready_thread=None
        self.step['callback_events']=self.events
        self.live()

    def _verify_map(self, source_map):
        need(source_map['schema']=='original19_callback_actual_source_mechanism_map_v1', 'Pinned source map schema')
        entry=source_map['cases'][self.case]
        windows=[entry['observer_stop'],*entry['actual_callers']]
        for window in windows:
            path=Path(window['path']);raw=self.suite.freeze_bytes(path,window['sha256'])
            need(raw.decode('utf-8').splitlines()[window['line']-1].strip()==window['statement'],
                 'Exact declared production source statement')
        need(same({k:entry['observer_stop'][{'source':'runtime_source'}.get(k,k)] for k in STOP},STOP),
             'Exact fixed callback stop')
        declared=[{'source':v['runtime_source'],'line':v['line'],'function':v['function']} for v in windows]
        expected=[STACKS[self.case][0],STACKS[self.case][1],STACKS[self.case][-1]]
        need(same(declared,expected), 'Pinned source map matches fixed callback callers')
        base=Path(entry['observer_stop']['path']).parent
        for frame in STACKS[self.case]:
            path=base/Path(frame['source']).name
            need(any(Path(pin['path']).resolve()==path.resolve() for pin in self.suite.spec['pins']),
                 'Every exact stack source belongs to producer seal')
            self.suite.freeze_bytes(path)

    def live(self):
        need(self.suite.batch.child is self.child and self.child.pid==self.step['pid']
             and self.child.poll() is None, 'Original owned Popen still live')
        self.suite.integrity()

    def _retain(self, direction, raw):
        need(type(raw) is bytes and 0<len(raw)<=MAX_PACKET+4
             and len(self.events)<256 and self.total_bytes+len(raw)<=16*1024*1024,
             'Bounded original packet custody')
        path=self.directory/('%04d_%s.bin'%(len(self.events)+1,direction))
        no_links(path)
        with path.open('xb') as stream:
            stream.write(raw);stream.flush();os.fsync(stream.fileno())
        self.suite.freeze_bytes(path,hashlib.sha256(raw).hexdigest())
        row={'order':len(self.events)+1,'direction':direction,'path':str(path),
             'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
        self.events.append(row);self.total_bytes+=len(raw)
        self.suite.persist()
        return row

    def _send(self, name, thread, data):
        self.live()
        need(type(thread) is int and type(data) is list, 'Fixed outbound envelope')
        allowed=(name in {'continue','get_stack_dump'} and not data)
        allowed=allowed or (name=='breakpoint' and len(data)==3 and same(data[:2],[CLOUD,230]) and type(data[2]) is bool)
        allowed=allowed or (name==COMMAND and same(data,[self.child.pid,self.step['nonce'],self.case,1])
                            and self.entered==thread and self.waiting)
        need(allowed, 'Only fixed read-only callback commands')
        packet=encode([name,thread,data]);raw=struct.pack('<I',len(packet))+packet
        event=self._retain('send_attempt',raw)
        self.peer.connection.sendall(raw)
        # A closed marker distinguishes a completed sendall from an attempted send.
        event['completion']=self._retain('send_complete',b'CALLBACK_SEND_COMPLETE\n'+event['sha256'].encode('ascii'))

    def handle(self, raw):
        self.live()
        # Retain even packets that are refused by semantic validation.
        need(type(raw) is bytes and 4<=len(raw)<=MAX_PACKET, 'Bounded original incoming bytes')
        self._retain('receive',struct.pack('<I',len(raw))+raw)
        name,thread,data=raw_envelope(raw)
        if name=='set_pid':
            need(not self.armed and same(data,[self.child.pid]), 'Unique owned debugger PID')
            self._send('breakpoint',thread,[CLOUD,230,True]);self.armed=True
        elif name=='lsh_callback19:ready':
            need(self.armed and self.entered is None, 'Ready before callback entry')
            self.packets.consume_ready(raw);self.ready_thread=thread
        elif name=='debug_enter':
            need(self.armed and not self.complete and self.entered is None
                 and same(data,[True,'Breakpoint',True,thread]), 'Exact breakpoint entry')
            self.entered=thread;self._send('get_stack_dump',thread,[])
        elif name=='stack_dump':
            need(self.entered==thread and not self.waiting, 'Stack of current paused thread')
            frames=stack_frames(data)
            need(frames[0]==STOP, 'Fixed production breakpoint top frame')
            if matches_stack(self.case,frames):
                need(self.packets.ready is not None and self.snapshot is None and thread==self.ready_thread,
                     'Ready actual observer on matching thread and unique callback')
                self.frames=copy.deepcopy(frames);self.waiting=True
                self._send(COMMAND,thread,[self.child.pid,self.step['nonce'],self.case,1])
            else:
                self._send('continue',thread,[]);self.entered=None
        elif name=='lsh_callback19:snapshot':
            need(self.waiting and self.entered==thread and self.frames is not None, 'Reply only after exact actual stack request')
            result=self.packets.consume_snapshot(raw,thread,1)
            need(result['observation']['cloud_state']['applying'] is (self.case=='cloud_applying_callback_no_upload_claim'),
                 'Actual applying state at the selected callback')
            self.snapshot=result;self._send('breakpoint',thread,[CLOUD,230,False])
            self._send('continue',thread,[]);self.entered=None;self.waiting=False;self.complete=True
        elif name in {'output','performance:profile_frame','performance:profile_names','debug_exit'}:
            need(name!='debug_exit' or self.entered is None, 'No debugger exit before paused observation completes')
        else:
            raise ValueError('Unexpected callback debugger event: '+name)

    def observation_result(self):
        need(self.complete and self.snapshot is not None and self.entered is None and not self.waiting,
             'One complete entered-stack observation')
        return {'case':self.case,'pid':self.child.pid,'nonce':self.step['nonce'],
                'actual_frames':copy.deepcopy(self.frames),'events':copy.deepcopy(self.events),
                'snapshot_sha256':self.snapshot['sha256'],
                'observation':copy.deepcopy(self.snapshot['observation']),
                'actual_case_qualified':False,'original19_qualified':False,
                'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
