"""Owned real cloud callback with original breakpoint/arm-send/ack custody.

Inherits actual Popen/socket/source checks and original byte ledger. No launcher.
Arm acknowledgment is dispatcher evidence only, not breakpoint-install proof.
"""
import copy
import struct

from campaign_callback_controller_v3 import CallbackController, CLOUD, STOP, matches_stack
from campaign_callback_packets_v2 import raw_envelope, json_value, same, need
from campaign_callback_snapshot_wire_v1 import COMMAND
from campaign_cloud_arm_packets_v1 import CloudArmPackets, CASE, ARM_COMMAND, ARM_REPLY
from godot_debug_wire import encode, stack_frames, MAX_PACKET


class CloudArmController(CallbackController):
    def __init__(self,suite,child,step,peer,case,driver_ready_path,driver_ready_sha256,source_map_path,source_map_sha256,apply_ready_path,apply_ready_sha256):
        need(case == CASE, 'Only actual cloud applying controller')
        super().__init__(suite,child,step,peer,case,driver_ready_path,driver_ready_sha256,source_map_path,source_map_sha256)
        self.packets = CloudArmPackets(child.pid,step['nonce'],case,self.packets.identity,self.packets.user)
        self.arm_request_sent = False
        self.apply_ready = self._apply_baseline(apply_ready_path,apply_ready_sha256)

    def _apply_baseline(self,path,digest):
        from pathlib import Path
        path = Path(path)
        need(path.resolve() == (self.output/'cloud_apply_ready.json').resolve(), 'Current owned original apply-ready path')
        value = json_value(self.suite.freeze_bytes(path,digest).decode('utf-8-sig'))
        fields = {'schema','pid','nonce','case','identity','user_directory','campaign_id','cloud_id',
                  'original_memory','original_cloud','original_cfg_sha256','payload','synthetic_local_owner',
                  'SDK_disabled','Steam_account_qualified','upload_qualified'}
        need(type(value) is dict and set(value) == fields and value['schema'] == 'campaign_cloud_apply_ready_v1'
             and type(value['pid']) is int and value['pid'] == self.child.pid and value['nonce'] == self.step['nonce']
             and value['case'] == CASE and same(value['identity'],self.packets.identity)
             and value['user_directory'] == self.packets.user, 'Complete original apply-ready PID/nonce/identity/user')
        self.packets._nodes(value)
        need(same(value['original_memory'],{'records':{},'unlocked':1,'owner':''}), 'Original fresh production campaign memory')
        original = value['original_cloud']
        need(type(original) is dict and set(original) == {'dirty','pending_upload','revision'}
             and type(original['dirty']) is bool and type(original['pending_upload']) is bool
             and type(original['revision']) is int and original['revision'] >= 0, 'Original cloud upload state types')
        digest = value['original_cfg_sha256']
        need(type(digest) is str and (digest == '' or len(digest) == 64 and all(c in '0123456789abcdef' for c in digest)), 'Original existing/missing CFG SHA')
        payload = value['payload']
        need(type(payload) is dict and set(payload) == {'schema','owner','updated_at','campaign','settings_text','language_text'}
             and type(payload['schema']) is int and payload['schema'] == 1 and payload['owner'] == '1'
             and type(payload['updated_at']) is int and 0 <= payload['updated_at'] <= 9007199254740991
             and same(payload['campaign'],{'schema':2,'unlocked':2,'records':{}})
             and type(payload['settings_text']) is str and type(payload['language_text']) is str,
             'Complete bounded synthetic local cloud input; not a natural victory')
        need(value['synthetic_local_owner'] is True and value['SDK_disabled'] is True
             and value['Steam_account_qualified'] is False and value['upload_qualified'] is False,
             'Local SDK-disabled seam input cannot grant Steam account/upload qualification')
        return value

    def _send(self,name,thread,data):
        if name != ARM_COMMAND:
            return super()._send(name,thread,data)
        self.live()
        need(type(thread) is int and type(data) is list and same(data,[self.child.pid,self.step['nonce'],CASE,0])
             and self.armed and self.ready_thread == thread and self.packets.ready is not None
             and not self.arm_request_sent and self.packets.arm is None and self.entered is None and not self.waiting,
             'One fixed read-only arm after original breakpoint send and observer ready')
        packet = encode([name,thread,data])
        raw = struct.pack('<I',len(packet)) + packet
        event = self._retain('send_attempt',raw)
        self.peer.connection.sendall(raw)
        event['completion'] = self._retain('send_complete',b'CALLBACK_SEND_COMPLETE\n'+event['sha256'].encode('ascii'))
        self.arm_request_sent = True

    def handle(self,raw):
        self.live()
        need(type(raw) is bytes and 4 <= len(raw) <= MAX_PACKET, 'Bounded original incoming bytes')
        self._retain('receive',struct.pack('<I',len(raw))+raw)
        name,thread,data = raw_envelope(raw)
        if name == 'set_pid':
            need(not self.armed and same(data,[self.child.pid]), 'Unique owned debugger PID')
            self._send('breakpoint',thread,[CLOUD,230,True])
            self.armed = True
        elif name == 'lsh_callback19:ready':
            need(self.armed and self.entered is None, 'Ready before callback entry')
            self.packets.consume_ready(raw)
            need(self.packets.ready['campaign_id'] == self.apply_ready['campaign_id']
                 and self.packets.ready['cloud_id'] == self.apply_ready['cloud_id'], 'Original apply-ready and debugger-ready nodes agree')
            self.ready_thread = thread
            self._send(ARM_COMMAND,thread,[self.child.pid,self.step['nonce'],CASE,0])
        elif name == ARM_REPLY:
            need(self.arm_request_sent and self.entered is None and not self.waiting and not self.complete,
                 'Original arm request completed before reply')
            self.packets.consume_arm(raw,self.ready_thread)
        elif name == 'debug_enter':
            need(self.armed and not self.complete and self.entered is None
                 and same(data,[True,'Breakpoint',True,thread]), 'Exact breakpoint entry')
            self.entered = thread
            self._send('get_stack_dump',thread,[])
        elif name == 'stack_dump':
            need(self.entered == thread and not self.waiting, 'Stack of current paused thread')
            frames = stack_frames(data)
            need(frames[0] == STOP, 'Fixed production breakpoint top frame')
            if matches_stack(CASE,frames):
                need(self.arm_request_sent and self.packets.arm is not None and self.packets.ready is not None
                     and self.snapshot is None and thread == self.ready_thread,
                     'Actual arm reply before matching cloud callback stack and unique snapshot')
                self.frames = copy.deepcopy(frames)
                self.waiting = True
                self._send(COMMAND,thread,[self.child.pid,self.step['nonce'],CASE,1])
            else:
                self._send('continue',thread,[])
                self.entered = None
        elif name == 'lsh_callback19:snapshot':
            need(self.waiting and self.entered == thread and self.frames is not None, 'Reply only after exact actual stack request')
            result = self.packets.consume_snapshot(raw,thread,1)
            observed = result['observation']
            need(same(observed['campaign_memory'],{'records':{},'unlocked':2,'owner':'1'})
                 and observed['campaign_persistence_busy'] is False, 'Real writer-complete memory before cloud callback')
            cloud = observed['cloud_state']
            need(cloud['applying'] is True and cloud['owner'] == '1' and cloud['shared_profile_pending'] is True
                 and all(same(cloud[k],self.apply_ready['original_cloud'][k]) for k in ['dirty','pending_upload','revision']),
                 'Applying callback preserves original upload state and real shared pending boundary')
            self.snapshot = result
            self._send('breakpoint',thread,[CLOUD,230,False])
            self._send('continue',thread,[])
            self.entered = None
            self.waiting = False
            self.complete = True
        elif name in {'output','performance:profile_frame','performance:profile_names','debug_exit'}:
            need(name != 'debug_exit' or self.entered is None, 'No debugger exit before paused observation completes')
        else:
            raise ValueError('Unexpected cloud callback debugger event: '+name)

    def observation_result(self):
        need(self.arm_request_sent and self.packets.arm is not None, 'Completed original arm request/reply required')
        result = super().observation_result()
        result.update(arm_ack=copy.deepcopy(self.packets.arm['observation']),arm_ack_sha256=self.packets.arm['sha256'],
                      breakpoint_installation_verified=False)
        return result
