"""Strict pure callback observation decoding; no socket or native qualification.

JSON is an observation projection, not preservation of Godot Variant types.
The future owned controller must establish PID, stack, source and packet custody.
"""
import copy
import hashlib
import json
import math
import re
from campaign_callback_snapshot_wire_v1 import CASES
from godot_debug_wire import decode, WireError, MAX_PACKET

JSON_LIMIT = 2 << 20
SNAPSHOT_FIELDS = {'schema','pid','nonce','case','sequence','identity','user_directory',
                   'campaign_id','cloud_id','campaign_memory','cloud_state',
                   'campaign_persistence_busy','time_scale','physics_ticks',
                   'original19_qualified','SDK_reward_once_qualified','overall_goal_qualified'}


def need(condition, message):
    if not condition:
        raise WireError(message)


def same(left, right):
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return left.keys() == right.keys() and all(same(left[k], right[k]) for k in left)
    if type(left) is list:
        return len(left) == len(right) and all(same(a,b) for a,b in zip(left,right))
    return left == right


def json_value(text):
    need(type(text) is str and 0 < len(text.encode('utf-8')) <= JSON_LIMIT, 'Bounded JSON observation')
    def text_value(value):
        try:
            need(len(value.encode('utf-8', errors='strict')) <= JSON_LIMIT, 'Bounded UTF8 observation string')
        except UnicodeError as error:
            raise WireError('Invalid UTF8 observation string') from error
    def pairs(items):
        result = {}
        for key,value in items:
            need(key not in result, 'Duplicate JSON observation key')
            result[key] = value
        return result
    def constant(value):
        raise WireError('Nonfinite JSON observation: '+value)
    try:
        value = json.loads(text, object_pairs_hook=pairs, parse_constant=constant)
    except (ValueError, RecursionError) as error:
        raise WireError('Invalid bounded JSON observation') from error
    count = 0
    def walk(item, depth=0):
        nonlocal count
        count += 1
        need(depth <= 24 and count <= 50000, 'JSON observation structure limit')
        if type(item) is dict:
            for key,child in item.items():
                need(type(key) is str, 'JSON string key'); text_value(key); walk(child,depth+1)
        elif type(item) is list:
            for child in item: walk(child,depth+1)
        elif type(item) is str:
            text_value(item)
        elif type(item) is float:
            need(math.isfinite(item), 'Finite observation number')
        else:
            need(type(item) in (str,int,bool,type(None)), 'JSON scalar observation')
    walk(value)
    return value


def raw_envelope(raw):
    need(type(raw) is bytes and 4 <= len(raw) <= MAX_PACKET, 'Original complete packet bytes')
    message = decode(raw)
    need(type(message) is list and len(message)==3 and type(message[0]) is str
         and type(message[1]) is int and type(message[2]) is list, 'Exact callback wire envelope')
    return message


class CallbackPackets:
    """Ordered observations for one externally proven process and one case.

    Constructor arguments are bindings supplied by the owner, not proof of it.
    Successful decoding never grants native, callback or whole-goal qualification.
    """
    def __init__(self, pid, nonce, case, identity, user_directory):
        need(type(pid) is int and pid>0 and type(nonce) is str and re.fullmatch('[0-9a-f]{32}',nonce)
             and type(case) is str and case in CASES, 'Exact supplied observation binding')
        need(type(identity) is dict and identity.get('save_eligible') is True
             and type(user_directory) is str and user_directory, 'Expected installed identity and user directory')
        self.pid,self.nonce,self.case = pid,nonce,case
        self.identity,self.user = copy.deepcopy(identity),user_directory
        self.ready = None
        self.sequence = 0

    def consume_ready(self, raw):
        name,thread,data = raw_envelope(raw)
        need(self.ready is None and name=='lsh_callback19:ready' and len(data)==4,
             'Only one initial observer ready packet')
        self._binding(data[:3])
        value = json_value(data[3])
        need(type(value) is dict and set(value)=={'campaign_id','cloud_id','identity','user_directory'},
             'Exact ready JSON fields')
        self._nodes(value)
        need(same(value['identity'],self.identity) and value['user_directory']==self.user,
             'Ready supplied identity/user binding')
        self.ready = copy.deepcopy(value)
        return self._result(raw,thread,value)

    def consume_snapshot(self, raw, expected_thread, expected_sequence):
        need(self.ready is not None and type(expected_thread) is int
             and type(expected_sequence) is int and expected_sequence==self.sequence+1
             and 1<=expected_sequence<=8, 'Ordered requested observation only')
        name,thread,data = raw_envelope(raw)
        need(name=='lsh_callback19:snapshot' and thread==expected_thread and len(data)==5,
             'Snapshot from exactly requested thread')
        self._binding(data[:3])
        need(type(data[3]) is int and data[3]==expected_sequence, 'Exact requested sequence')
        value = json_value(data[4])
        need(type(value) is dict and set(value)==SNAPSHOT_FIELDS, 'Exact snapshot JSON fields')
        need(value['schema']=='campaign_callback_readonly_snapshot_v1', 'Snapshot schema')
        self._binding([value['pid'],value['nonce'],value['case']])
        need(type(value['sequence']) is int and value['sequence']==expected_sequence, 'JSON sequence binding')
        self._nodes(value)
        need(value['campaign_id']==self.ready['campaign_id'] and value['cloud_id']==self.ready['cloud_id']
             and same(value['identity'],self.identity) and value['user_directory']==self.user,
             'Original nodes and supplied identity/user unchanged')
        memory,cloud = value['campaign_memory'],value['cloud_state']
        need(type(memory) is dict and set(memory)=={'records','unlocked','owner'}
             and type(memory['records']) is dict and type(memory['unlocked']) is int
             and memory['unlocked']>=1 and type(memory['owner']) is str, 'Campaign observation shape')
        need(type(cloud) is dict and set(cloud)=={'dirty','pending_upload','revision','applying','owner','shared_profile_pending'}
             and all(type(cloud[k]) is bool for k in ['dirty','pending_upload','applying','shared_profile_pending'])
             and type(cloud['revision']) is int and cloud['revision']>=0 and type(cloud['owner']) is str,
             'Cloud observation shape')
        need(type(value['campaign_persistence_busy']) is bool
             and type(value['time_scale']) in (int,float) and not isinstance(value['time_scale'],bool)
             and value['time_scale']==1 and type(value['physics_ticks']) is int and value['physics_ticks']>0,
             'Normal clock and busy observation types')
        need(all(value[k] is False for k in ['original19_qualified','SDK_reward_once_qualified','overall_goal_qualified']),
             'Observation cannot claim qualification')
        self.sequence = expected_sequence
        return self._result(raw,thread,value)

    def _binding(self, values):
        need(len(values)==3 and type(values[0]) is int and values[0]==self.pid
             and type(values[1]) is str and values[1]==self.nonce
             and type(values[2]) is str and values[2]==self.case, 'Original PID/nonce/case binding')

    def _nodes(self, value):
        need(all(type(value[k]) is int and value[k]>0 for k in ['campaign_id','cloud_id'])
             and value['campaign_id']!=value['cloud_id'], 'Distinct positive actual node IDs')

    def _result(self, raw, thread, value):
        return {'raw':raw,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
                'thread':thread,'observation':copy.deepcopy(value),
                'ownership_proven':False,'native_qualified':False}
