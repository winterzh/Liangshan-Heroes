"""Strict pure arm acknowledgment decoding; never proves a breakpoint or PID."""
from campaign_callback_packets_v2 import CallbackPackets, json_value, raw_envelope, same, need

CASE = 'cloud_applying_callback_no_upload_claim'
ARM_COMMAND = 'lsh_callback19:arm'
ARM_REPLY = 'lsh_callback19:armed'
ARM_FIELDS = {'schema','pid','nonce','case','sequence','campaign_id','cloud_id',
              'identity','user_directory','SDK_reward_once_qualified','actual_callback_qualified','overall_goal_qualified'}


class CloudArmPackets(CallbackPackets):
    def __init__(self,pid,nonce,case,identity,user_directory):
        need(case == CASE, 'Arm handshake is only for fixed real cloud apply')
        super().__init__(pid,nonce,case,identity,user_directory)
        self.arm = None

    def consume_arm(self,raw,expected_thread):
        need(self.ready is not None and self.arm is None and self.sequence == 0
             and type(expected_thread) is int, 'One arm acknowledgment after ready and before snapshot')
        name,thread,data = raw_envelope(raw)
        need(name == ARM_REPLY and thread == expected_thread and len(data) == 5, 'Exact requested arm thread and envelope')
        self._binding(data[:3])
        need(type(data[3]) is int and data[3] == 0, 'Exact integer arm sequence zero')
        value = json_value(data[4])
        need(type(value) is dict and set(value) == ARM_FIELDS
             and value['schema'] == 'campaign_cloud_callback_arm_received_v2', 'Exact arm acknowledgment fields/schema')
        self._binding([value['pid'],value['nonce'],value['case']])
        need(type(value['sequence']) is int and value['sequence'] == 0, 'Exact JSON arm sequence zero')
        self._nodes(value)
        need(value['campaign_id'] == self.ready['campaign_id'] and value['cloud_id'] == self.ready['cloud_id']
             and same(value['identity'],self.identity) and value['user_directory'] == self.user,
             'Original ready nodes and exact identity/user in arm reply')
        need(all(value[k] is False for k in ['SDK_reward_once_qualified','actual_callback_qualified','overall_goal_qualified']),
             'Arm reply cannot grant callback/SDK/overall qualification')
        result = self._result(raw,thread,value)
        self.arm = result
        return result

    def consume_snapshot(self,raw,expected_thread,expected_sequence):
        need(self.arm is not None and expected_thread == self.arm['thread'], 'Snapshot only after arm on the same original thread')
        return super().consume_snapshot(raw,expected_thread,expected_sequence)
