"""Bounded read-only QA snapshot command, separate from existing debug commands.

Uses the existing object-free scalar/Array wire codec. This module does not
launch or qualify a native process, evaluate expressions or mutate game state.
"""
import re,struct
from godot_debug_wire import DebugConnection,WireError,encode,MAX_PACKET

CASES=('callback_sees_new_memory','cloud_applying_callback_no_upload_claim','legacy_real_cloud_apply_failure_boundary')
COMMAND='lsh_callback19:read'

class CallbackSnapshotConnection(DebugConnection):
    def request_snapshot(self,thread_id,pid,nonce,case,sequence):
        if type(thread_id) is not int or type(pid) is not int or pid<=0 or type(nonce) is not str or not re.fullmatch('[0-9a-f]{32}',nonce):
            raise WireError('Exact native PID/thread/nonce snapshot identity required')
        if case not in CASES or type(sequence) is not int or not 1<=sequence<=8:
            raise WireError('Fixed callback case and bounded snapshot sequence required')
        packet=encode([COMMAND,thread_id,[pid,nonce,case,sequence]])
        if len(packet)>MAX_PACKET:raise WireError('Snapshot packet limit')
        self.connection.sendall(struct.pack('<I',len(packet))+packet)
