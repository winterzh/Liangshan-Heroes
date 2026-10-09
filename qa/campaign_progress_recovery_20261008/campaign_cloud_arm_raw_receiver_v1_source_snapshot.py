"""Bounded original-frame receiver for the reviewed callback controller.

No decoder runs before custody. Timeouts retain the same stream buffer; EOF is
transport state only, never proof of process termination or native qualification.
No socket/process launcher or native execution admission is provided.
"""
import socket
import struct
from campaign_cloud_arm_controller_v1 import CloudArmController as CallbackController
from campaign_callback_snapshot_wire_v1 import CallbackSnapshotConnection
from campaign_callback_packets_v2 import need
from godot_debug_wire import MAX_PACKET, WireError


class FrameBuffer:
    """Pure bounded frame assembly; inputs alone cannot prove a real transport."""
    def __init__(self):
        self.buffer=bytearray()

    def wanted(self):
        if len(self.buffer)<4:
            return 4-len(self.buffer)
        size=struct.unpack('<I',self.buffer[:4])[0]
        need(4<=size<=MAX_PACKET, 'Original debugger frame length refused')
        return size+4-len(self.buffer)

    def add(self, chunk):
        need(type(chunk) is bytes and 0<len(chunk)<=min(self.wanted(),65536),
             'Exact bounded incoming stream fragment')
        self.buffer.extend(chunk)

    def take(self):
        need(self.wanted()==0, 'Only one complete original frame')
        frame=bytes(self.buffer)
        self.buffer.clear()
        return frame


class CallbackRawReceiver:
    def __init__(self, controller):
        need(type(controller) is CallbackController
             and type(controller.peer) is CallbackSnapshotConnection
             and type(controller.peer.connection) is socket.socket
             and not controller.peer.buffer, 'Reviewed controller and untouched actual transport')
        controller.live()
        self.controller=controller
        self.connection=controller.peer.connection
        self.frames=FrameBuffer()
        self.stopped=False
        self.last_frame=None

    def _failure(self, label):
        self.stopped=True
        # These bytes are exactly what was received, including a partial header.
        if self.frames.buffer:
            self.controller._retain(label,bytes(self.frames.buffer))
        if self.controller.peer.buffer:
            self.controller._retain('competing_decoder_bytes',bytes(self.controller.peer.buffer))
        self.controller._retain('transport_status',('CALLBACK_TRANSPORT_'+label.upper()+'\n').encode('ascii'))

    def _gate(self):
        try:
            self.controller.live()
            need(not self.controller.peer.buffer, 'No competing decoded receiver on this transport')
        except BaseException as error:
            self.stopped=True
            try:
                self._failure('receive_gate_refused')
            except BaseException as retention_error:
                error.add_note('Refusal custody failed: '+repr(retention_error))
            raise

    def receive_one(self):
        need(not self.stopped, 'Terminal/refused transport cannot be restarted')
        self._gate()
        while True:
            try:
                wanted=self.frames.wanted()
            except WireError:
                self._failure('receive_bad_header')
                raise
            if wanted==0:
                frame=bytes(self.frames.buffer)
                # Keep frame before controller's semantic decoder sees its body.
                try:
                    self.last_frame=self.controller._retain('receive_frame',frame)
                    self.frames.take()
                    self.controller.handle(frame[4:])
                except BaseException:
                    self.stopped=True
                    raise
                return self.last_frame
            self._gate()
            try:
                chunk=self.connection.recv(min(wanted,65536))
            except socket.timeout:
                # No reset, second connection or process-terminal assertion.
                raise
            except OSError:
                self._failure('receive_io_error')
                raise
            if not chunk:
                self._failure('receive_eof')
                raise EOFError('Owned callback transport closed; inspect retained Popen separately')
            self.frames.add(chunk)
