"""Replay original callback custody and terminal tail; no owner/launcher proof.

The complete report consumer must separately require its retained terminal
Popen, source identity, original native reports and physical CFG/lifecycle.
"""
import hashlib
from pathlib import Path
import struct
from campaign_callback_packets_v2 import CallbackPackets,raw_envelope,same,need
from campaign_callback_controller_v3 import STOP,matches_stack,MAX_CUSTODY_EVENTS,MAX_CUSTODY_BYTES
from campaign_callback_snapshot_wire_v1 import COMMAND
from godot_debug_wire import MAX_PACKET,stack_frames
from durable_campaign_full_runtime import no_links

CASE='callback_sees_new_memory'
FIELDS={'order','direction','path','bytes','sha256'}
NOISE={'output','performance:profile_frame','performance:profile_names','debug_exit'}


def framed(raw):
    need(type(raw) is bytes and len(raw)>=8 and struct.unpack('<I',raw[:4])[0]==len(raw)-4
         and 4<=len(raw)-4<=MAX_PACKET, 'Exact original single frame')
    return raw[4:]


def tail_packets(raw):
    messages=[];offset=0
    while offset<len(raw):
        need(len(raw)-offset>=4, 'No truncated terminal length header')
        size=struct.unpack('<I',raw[offset:offset+4])[0]
        need(4<=size<=MAX_PACKET and offset+4+size<=len(raw), 'No truncated or oversized terminal body')
        messages.append(raw_envelope(raw[offset+4:offset+4+size]));offset+=size+4
    return messages


def replay_callback_packets(suite,step,identity,user,seal):
    rows=step['callback_events'];output=Path(step['output']);directory=output/'callback_packets';no_links(directory)
    need(type(rows) is list and 0<len(rows)<=MAX_CUSTODY_EVENTS, 'Bounded complete event list')
    payloads=[];paths=[];total=0
    for index,row in enumerate(rows,1):
        need(type(row) is dict and set(row)==(FIELDS|{'completion'} if row.get('direction')=='send_attempt' else FIELDS)
             and type(row['order']) is int and row['order']==index and type(row['direction']) is str
             and type(row['bytes']) is int and 0<row['bytes']<=MAX_PACKET+4, 'Exact ordered event metadata')
        path=Path(row['path']);no_links(path)
        need(path==directory/('%04d_%s.bin'%(index,row['direction'])), 'Exact current owned event path')
        raw=suite.freeze_bytes(path,row['sha256']);need(len(raw)==row['bytes'], 'Whole original event byte count')
        total+=len(raw);need(total<=MAX_CUSTODY_BYTES, 'Cumulative original event budget')
        payloads.append(raw);paths.append(path.name)
    need({p.name for p in directory.iterdir()}==set(paths), 'No unlisted or temporary custody artifacts')
    observation=step['callback_observation']
    need(type(observation) is dict and set(observation)=={'case','pid','nonce','actual_frames','events','snapshot_sha256','observation',
         'actual_case_qualified','original19_qualified','SDK_reward_once_qualified','overall_goal_qualified'}
         and observation['case']==CASE and type(observation['pid']) is int and observation['pid']==step['pid']
         and observation['nonce']==step['nonce'] and same(observation['events'],rows)
         and all(observation[k] is False for k in ['actual_case_qualified','original19_qualified','SDK_reward_once_qualified','overall_goal_qualified']),
         'Original unqualified observation bound to complete event list')
    packets=CallbackPackets(step['pid'],step['nonce'],CASE,identity,str(user))
    armed=False;entered=None;waiting=False;complete=False;ready_thread=None;actual_frames=None;snapshot=None
    pending=[];pending_frame=None;tail=b'';refused_prefix=None;prefix_seen=False;closed=False;terminal_mode=False;tail_rows=[];eof_kind=None

    def receive(raw,late=False):
        nonlocal armed,entered,waiting,complete,ready_thread,actual_frames,snapshot,pending
        name,thread,data=raw_envelope(raw)
        need(not pending and not closed, 'Original receive only after all issued commands complete')
        if late:
            need(complete and name in NOISE, 'Terminal original frame cannot add callback/control claims')
            return
        if name=='set_pid':
            need(not armed and same(data,[step['pid']]), 'Unique bound debugger PID')
            armed=True;pending=[['breakpoint',thread,[STOP['source'],STOP['line'],True]]]
        elif name=='lsh_callback19:ready':
            need(armed and entered is None, 'Ready before entered callback')
            packets.consume_ready(raw);ready_thread=thread
        elif name=='debug_enter':
            need(armed and not complete and entered is None and same(data,[True,'Breakpoint',True,thread]), 'Exact entered production thread')
            entered=thread;pending=[['get_stack_dump',thread,[]]]
        elif name=='stack_dump':
            need(entered==thread and not waiting, 'Stack from current entered thread')
            frames=stack_frames(data);need(same(frames[0],STOP), 'Exact fixed production top frame')
            if matches_stack(CASE,frames):
                need(packets.ready is not None and thread==ready_thread and snapshot is None, 'Unique ready matching callback')
                actual_frames=frames;waiting=True;pending=[[COMMAND,thread,[step['pid'],step['nonce'],CASE,1]]]
            else:pending=[['continue',thread,[]]]
        elif name=='lsh_callback19:snapshot':
            need(waiting and entered==thread and actual_frames is not None, 'Snapshot after actual exact stack request')
            snapshot=packets.consume_snapshot(raw,thread,1)
            value=snapshot['observation'];memory=value['campaign_memory']
            need(value['cloud_state']['applying'] is False and value['campaign_id']==seal['campaign_id']
                 and memory['owner']=='' and memory['unlocked']==2 and same(memory['records'],{'level1':seal['level_record']})
                 and value['campaign_persistence_busy'] is False, 'Actual same-object newly published full memory at normal cloud callback')
            pending=[['breakpoint',thread,[STOP['source'],STOP['line'],False]],['continue',thread,[]]]
        else:
            need(name in NOISE and (name!='debug_exit' or entered is None), 'No unknown/early exit debugger event')

    index=0
    while index<len(rows):
        row=rows[index];raw=payloads[index];kind=row['direction']
        if kind=='receive_frame':
            need(pending_frame is None and not terminal_mode and not closed, 'One original frame awaiting its duplicate')
            pending_frame=framed(raw)
            if index+1==len(rows) or rows[index+1]['direction']!='receive':
                need(step.get('terminal_transition_guard_observed') is True and complete, 'Adapter-only frame only at guarded completed terminal race')
                receive(pending_frame,late=True);pending_frame=None;terminal_mode=True
        elif kind=='receive':
            need(pending_frame is not None and framed(raw)==pending_frame and not terminal_mode, 'Controller duplicate of exact adapter bytes')
            receive(pending_frame);pending_frame=None
        elif kind=='send_attempt':
            need(pending and pending_frame is None and not terminal_mode and not closed
                 and same(raw_envelope(framed(raw)),pending[0]), 'Exact issued read-only command order/thread/arguments')
            need(index+1<len(rows) and rows[index+1]['direction']=='send_complete'
                 and same(row['completion'],rows[index+1])
                 and payloads[index+1]==b'CALLBACK_SEND_COMPLETE\n'+row['sha256'].encode('ascii'), 'Original completed sendall marker')
            command=pending.pop(0)
            if command[0]=='continue':
                entered=None
                if snapshot is not None:waiting=False;complete=True
            index+=1
        elif kind=='receive_gate_refused':
            need(complete and not pending and step.get('terminal_transition_guard_observed') is True
                 and refused_prefix is None and not closed and not terminal_mode and not prefix_seen and not tail,
                 'Refused original prefix must precede all terminal tail records')
            refused_prefix=raw;terminal_mode=True
        elif kind=='transport_status':
            need(complete and not pending and not closed, 'Transport closure after completed snapshot')
            if raw==b'CALLBACK_TRANSPORT_RECEIVE_GATE_REFUSED\n':
                need(step.get('terminal_transition_guard_observed') is True, 'Actual guarded terminal transition status')
                terminal_mode=True
            else:
                need(raw==b'CALLBACK_TRANSPORT_RECEIVE_EOF\n' and type(step.get('debugger_closed_before_process_terminal')) is bool,
                     'Exact nontruncated observed EOF status')
                need(not terminal_mode and not tail and refused_prefix is None and 'terminal_tail' not in step,
                     'Observed EOF cannot discard a terminal prefix/tail')
                closed=True;eof_kind='observed'
        elif kind=='terminal_tail_prefix':
            need(complete and not pending and not closed and not tail, 'Unique terminal stream prefix')
            need(refused_prefix is None or raw==refused_prefix, 'Repeated refused prefix is same received bytes')
            tail=raw;terminal_mode=True;prefix_seen=True
        elif kind=='terminal_tail_bytes':
            need(complete and not pending and not closed, 'Tail retained after completed callback')
            tail+=raw;tail_rows.append(row);terminal_mode=True
        elif kind=='terminal_transport_eof':
            need(complete and not pending and not closed and raw==b'CALLBACK_TERMINAL_TRANSPORT_EOF\n', 'Exact closed terminal tail marker')
            need(refused_prefix is None or (prefix_seen and tail.startswith(refused_prefix)),
                 'Every refused original prefix must enter tail reconstruction byte-exact')
            for name,thread,data in tail_packets(tail):need(name in NOISE, 'No late control/snapshot or unknown terminal packet')
            need(same(step.get('terminal_tail'),tail_rows), 'Complete original tail chunk index')
            closed=True;eof_kind='terminal'
        else:raise ValueError('Refused/unknown successful custody direction: '+kind)
        index+=1
    need(complete and closed and pending_frame is None and not pending and entered is None and not waiting and snapshot is not None,
         'Complete original request/reply/resume and actual transport closure')
    need(same(actual_frames,observation['actual_frames']) and snapshot['sha256']==observation['snapshot_sha256']
         and same(snapshot['observation'],observation['observation']), 'Snapshot/frame metadata equals independently decoded originals')
    return {'events':len(rows),'original_bytes':total,'snapshot_sha256':snapshot['sha256'],'transport_eof':eof_kind,
            'native_ownership_proven':False,'whole_suite_qualified':False}
