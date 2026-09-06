"""Prepare one pinned private observation patch. No engine/Git/project mutation."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SEP = HERE.parent / 'separation_sections_diag'
BODY = HERE.parent / 'unit_body_sections_diag'
BASE = '4baafc11af55b0e46a57a48e54df181b8c1917a2'
SOURCE = {
    'scripts/unit.gd': ('scripts__unit.gd', 'c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856'),
    'scripts/game_map.gd': ('scripts__game_map.gd', '0f090079229a68269ac94870d1902238444e9ba0ddbc7f359df52f38a4b2db87'),
}
LEDGER_SHA = 'eb9a3c1e38e9da184db83e6d6df73bd056788217d2a64e02987cc7fbac12008b'
DRIVER_TEMPLATE_SHA = '76fa9d82e6d4fc0b49420465527e3ccf05fb679e0a7d50d4f90a717de1b8c2d5'
M1_SHA = '04a47115c8cd05670b465086653491466fdae99f6fadf9c41c40379aee0c1407'
RESOURCE = 'res://scratchpad/chase_path_diag/generated/ledger.gd'
METRICS = '''chain_calls chain_completions ranged_chains
strict_calls strict_returns strict_empty strict_ranged_empty strict_points strict_us strict_fallback_us strict_fallback_astar_us
fallback_calls fallback_returns fallback_empty fallback_points fallback_us
strict_endpoint_reject strict_same_cell strict_astar_empty_reject strict_smooth_return strict_smooth_empty
strict_astar_enter strict_astar_return strict_astar_empty_ids strict_astar_ids_total strict_astar_us
fallback_precondition_reject fallback_no_open_target fallback_astar_empty_reject fallback_reach_reject fallback_smooth_return fallback_smooth_empty
fallback_astar_enter fallback_astar_return fallback_astar_empty_ids fallback_astar_ids_total fallback_astar_us'''.split()
ANCHOR_COLUMNS = ['m1_tick','physics_id','process_id','physics_signal_us','observer_us','collection_physics_id','collected_us']

def sha(b): return hashlib.sha256(b).hexdigest()
def lf(b): return b.replace(b'\r\n', b'\n')
def need(ok, why):
    if not ok: raise ValueError(why)
def save(path, obj): path.write_bytes((json.dumps(obj, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
def checked(path, wanted):
    b=path.read_bytes(); need(sha(b)==wanted, 'Pinned input drift: '+str(path)); return b

def span(raw, name, static=False):
    prefix = b'static func ' if static else b'func '
    matches=list(re.finditer(rb'(?m)^'+prefix+name.encode()+rb'\(', raw))
    need(len(matches)==1, 'Unique method '+name)
    start=matches[0].start(); nxt=re.search(rb'(?m)^'+prefix, raw[matches[0].end():])
    end=matches[0].end()+nxt.start() if nxt else len(raw)
    return start,end

def insert_line(raw, anchor, addition, after=False):
    matches=list(re.finditer(rb'(?m)^'+re.escape(anchor.encode())+rb'\r?\n',raw))
    need(len(matches)==1, 'Unique literal line '+anchor)
    m=matches[0]; eol=b'\r\n' if m.group().endswith(b'\r\n') else b'\n'
    pos=m.end() if after else m.start()
    return raw[:pos]+addition.encode().replace(b'\n',eol)+raw[pos:]

def return_reason(raw, condition, kind, reason):
    pattern=rb'(?m)^'+re.escape(condition.encode())+rb'\r?\n(?P<ret>\t\treturn out[^\n]*\n)'
    matches=list(re.finditer(pattern,raw)); need(len(matches)==1,'Unique return branch '+condition)
    m=matches[0]; eol=b'\r\n' if m['ret'].endswith(b'\r\n') else b'\n'
    note=('\t\t_ChasePathDiag.note_reason(%d, _ChasePathDiag.%s)'%(kind,reason)).encode()+eol
    pos=m.start('ret'); return raw[:pos]+note+raw[pos:]

def inline_reason(raw, old, condition, reason):
    matches=list(re.finditer(rb'(?m)^'+re.escape(old.encode())+rb'\r?\n',raw))
    need(len(matches)==1,'Unique inline return '+old);m=matches[0]
    eol=b'\r\n' if m.group().endswith(b'\r\n') else b'\n'
    new=(condition+'\n\t\t_ChasePathDiag.note_reason(1, '+reason+')\n\t\treturn out\n').encode().replace(b'\n',eol)
    return raw[:m.start()]+new+raw[m.end():]

def inverse(changed, proof):
    need(sha(changed)==proof['result_raw_sha256'],'Inverse input changed')
    for op in reversed(proof['operations']):
        before=op['before_utf8'].encode();after=op['after_utf8'].encode()
        need(changed.count(after)==1,'Unique inverse operation')
        changed=changed.replace(after,before,1)
    need(sha(changed)==proof['source_raw_sha256'],'Inverse source SHA mismatch')
    return changed

def transform(original, which):
    raw_pin=SOURCE[which][1]; frozen=(SEP/'frozen'/SOURCE[which][0]).read_bytes()
    need(sha(frozen)==raw_pin,'Frozen source changed')
    need(original in [frozen,lf(frozen)],'Only exact pinned raw or LF input accepted')
    need(b'_ChasePathDiag' not in original,'Already instrumented')
    result=original; operations=[]
    names=['_do_chase'] if which=='scripts/unit.gd' else ['find_path','find_firing_path']
    for name in names:
        a,b=span(result,name);before=result[a:b];after=before
        if name=='_do_chase':
            after=insert_line(after,'\t\t\t_path = map.find_path(position, _target.position, faction, movement_profile)',
                '\t\t\tvar __cp_token: bool = _ChasePathDiag.begin_chain(is_ranged)\n\t\t\tvar __cp_started: int = _ChasePathDiag.begin_call(__cp_token, 0)\n')
            after=insert_line(after,'\t\t\t_path = map.find_path(position, _target.position, faction, movement_profile)',
                '\t\t\t_ChasePathDiag.finish_call(__cp_token, 0, __cp_started, _path.size())\n',True)
            after=insert_line(after,'\t\t\t\t_path = map.find_firing_path(position,_target.position,reach,faction,movement_profile)',
                '\t\t\t\t__cp_started = _ChasePathDiag.begin_call(__cp_token, 1)\n')
            after=insert_line(after,'\t\t\t\t_path = map.find_firing_path(position,_target.position,reach,faction,movement_profile)',
                '\t\t\t\t_ChasePathDiag.finish_call(__cp_token, 1, __cp_started, _path.size())\n',True)
            after=insert_line(after,'\t\t\t_path_i = 0','\t\t\t_ChasePathDiag.end_chain(__cp_token)\n')
        elif name=='find_path':
            after=return_reason(after,'\tif a.x < 0 or b.x < 0 or not is_open_world(from_w, profile):',0,'STRICT_ENDPOINT_REJECT')
            # This branch includes append before return, so target its complete literal pair.
            after=insert_line(after,'\t\tout.append(to_w if target_cell == b and is_open_world(to_w, profile) else cell_to_world(b))',
                '\t\t_ChasePathDiag.note_reason(0, _ChasePathDiag.STRICT_SAME_CELL)\n',True)
            after=return_reason(after,'\tif ids.is_empty():',0,'STRICT_ASTAR_EMPTY_REJECT')
            after=insert_line(after,'\treturn smooth','\t_ChasePathDiag.note_reason(0, _ChasePathDiag.STRICT_SMOOTH_RETURN)\n')
            after=insert_line(after,'\tvar ids := nav.get_id_path(a, b)','\tvar __cp_astar_started: int = _ChasePathDiag.begin_astar(0)\n')
            after=insert_line(after,'\tvar ids := nav.get_id_path(a, b)','\t_ChasePathDiag.finish_astar(0, __cp_astar_started, ids.size())\n',True)
        else:
            after=inline_reason(after,'\tif reach<=0 or not is_open_world(from_w,profile): return out','\tif reach<=0 or not is_open_world(from_w,profile):','_ChasePathDiag.FALLBACK_PRECONDITION_REJECT')
            after=inline_reason(after,'\tif b.x<0: return out','\tif b.x<0:','_ChasePathDiag.FALLBACK_NO_OPEN_TARGET')
            after=inline_reason(after,'\tif ids.is_empty() or cell_to_world(ids[-1]).distance_to(target_w)>reach-4.0: return out',
                '\tif ids.is_empty() or cell_to_world(ids[-1]).distance_to(target_w)>reach-4.0:',
                '_ChasePathDiag.FALLBACK_ASTAR_EMPTY_REJECT if ids.size() == 0 else _ChasePathDiag.FALLBACK_REACH_REJECT')
            after=insert_line(after,'\treturn _smooth_path(from_w,out,profile)','\t_ChasePathDiag.note_reason(1, _ChasePathDiag.FALLBACK_SMOOTH_RETURN)\n')
            after=insert_line(after,'\tvar ids := nav.get_id_path(a,b,true)','\tvar __cp_astar_started: int = _ChasePathDiag.begin_astar(1)\n')
            after=insert_line(after,'\tvar ids := nav.get_id_path(a,b,true)','\t_ChasePathDiag.finish_astar(1, __cp_astar_started, ids.size())\n',True)
        if name==names[0]: after=('const _ChasePathDiag = preload("'+RESOURCE+'")\n\n').encode()+after
        operations.append({'method':name,'original_method_raw_sha256':sha(before),'original_method_lf_sha256':sha(lf(before)),
                           'before_utf8':before.decode(),'after_utf8':after.decode()})
        result=result[:a]+after+result[b:]
    proof={'source_raw_sha256':sha(original),'source_lf_sha256':sha(lf(original)),'result_raw_sha256':sha(result),'operations':operations,
           'inverse_restores_all_original_bytes':True,'changed_methods':names,'new_top_level_constants':['_ChasePathDiag']}
    need(inverse(result,proof)==original,'Full byte inverse failed')
    return result,proof

def ledger_from_pinned_frames():
    old=checked(BODY/'generated/ledger.gd',LEDGER_SHA)
    def methods(names): return b''.join(old[slice(*span(old,name,True))] for name in names).decode()
    constants='\n'.join('const %s := %d'%(key.upper(),i) for i,key in enumerate(METRICS))
    constants+='\nconst METRIC_COUNT := %d\nconst STEP_WIDTH := %d\nconst TIME_METRICS := %s\nconst STEP_COLUMNS := %s'%(
        len(METRICS),len(METRICS)+7,json.dumps([i for i,k in enumerate(METRICS) if k.endswith('_us')]),json.dumps(ANCHOR_COLUMNS+METRICS))
    template=(HERE/'ledger.gd.in').read_text(encoding='utf-8')
    for token,value in {'# @@METRIC_CONSTANTS@@':constants,'# @@EXACT_FRAME_BOUNDARIES@@':methods(['physics_boundary','process_boundary']),
                        '# @@EXACT_FRAME_ANCHORS@@':methods(['begin_measurement','presented','end_measurement','_rows'])}.items():
        needle=token+'\n\n' if token.startswith('# @@EXACT_FRAME_') else token
        need(template.count(needle)==1,'Ledger placeholder '+token);template=template.replace(needle,value)
    return template.encode()

def driver_from_pinned_m1():
    template=checked(BODY/'driver.gd.in',DRIVER_TEMPLATE_SHA).decode()
    template=template.replace('UnitBodyDiag','ChasePathDiag').replace('unit_sections','chase_path').replace('UNIT_BODY_SECTIONS','CHASE_PATH').replace('unit_body_sections_diag','chase_path_diag')
    template=template.replace('Unit body diagnostic','Chase path diagnostic').replace('only complete Unit body sections are timed','only direct chase path calls are observed').replace('body entry/exit/partition/frame ledger integrity','direct chase path count/return/frame ledger integrity').replace('Unit sections','Chase path')
    m1=checked(SEP/'frozen/tools__polish_performance_probe.gd',M1_SHA)
    run=m1[slice(*span(m1,'_run'))].decode(); changed=run
    hooks=[('\t_configure_settings()\n','\tChasePathDiag.prepare(chase_path_mode)\n',True),
       ('\troot.add_child(tick_driver)\n','\tphysics_frame.connect(_chase_path_physics_boundary)\n\tprocess_frame.connect(_chase_path_process_boundary)\n',False),
       ('\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n','\tChasePathDiag.begin_measurement(started, start_tick)\n',False),
       ('\t\traw.append(float(now-previous)/1000.0); previous = now\n','\t\tChasePathDiag.presented(now, physics_tick)\n',False),
       ('\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0\n','\tChasePathDiag.end_measurement(Time.get_ticks_usec(), physics_tick)\n',False)]
    for anchor,addition,before in hooks:
        need(changed.count(anchor)==1,'M1 anchor changed');changed=changed.replace(anchor,addition+anchor if before else anchor+addition,1)
    restored=changed
    for _,addition,_ in hooks:
        need(restored.count(addition)==1,'M1 inverse hook unique');restored=restored.replace(addition,'',1)
    need(restored==run,'Original M1 run not preserved')
    need(template.count('# @@PINNED_M1_RUN_WITH_ANCHORS@@')==1,'M1 run placeholder')
    return template.replace('# @@PINNED_M1_RUN_WITH_ANCHORS@@',changed).encode(),{'source_run_raw_sha256':sha(run.encode()),'five_observer_hooks_only':True,'inverse_restores_original_run':True}

def main():
    ast.parse(Path(__file__).read_text(encoding='utf-8'))
    generated=HERE/'generated';generated.mkdir(parents=True,exist_ok=True)
    outputs={};proofs={};patches=[];sources={}
    for target,(leaf,expected) in SOURCE.items():
        original=checked(SEP/'frozen'/leaf,expected);sources[target]={'frozen_path':str((SEP/'frozen'/leaf).relative_to(ROOT)),'raw_sha256':sha(original),'lf_sha256':sha(lf(original))}
        for variant,source in [('raw',original),('lf',lf(original))]:
            changed,proof=transform(source,target);name=Path(target).stem+'.instrumented.'+variant+'.gd.txt';outputs[name]=changed;proofs[name]=proof
            if variant=='lf': patches.append(''.join(difflib.unified_diff(source.decode().splitlines(True),changed.decode().splitlines(True),fromfile='a/'+target,tofile='b/'+target)))
    outputs['ledger.gd']=ledger_from_pinned_frames();outputs['driver.gd'],m1proof=driver_from_pinned_m1()
    for name,b in outputs.items(): (generated/name).write_bytes(b)
    patch=''.join(patches).encode();(HERE/'instrumentation.patch').write_bytes(patch)
    save(HERE/'inverse_proofs.json',proofs)
    save(HERE/'pins.json',{'schema':1,'base':BASE,'source_contract':sources,'generated_sha256':{k:sha(v) for k,v in outputs.items()},'inverse_proofs_sha256':sha((HERE/'inverse_proofs.json').read_bytes()),'patch_sha256':sha(patch),'m1':m1proof,
         'reused_small_sources':{'unit_body_sections_diag/generated/ledger.gd':LEDGER_SHA,'unit_body_sections_diag/driver.gd.in':DRIVER_TEMPLATE_SHA,'separation_sections_diag/frozen/tools__polish_performance_probe.gd':M1_SHA},
         'step_columns':ANCHOR_COLUMNS+METRICS,'time_columns':[x for x in METRICS if x.endswith('_us')],
         'generator_sha256':sha(Path(__file__).read_bytes()),'ledger_template_sha256':sha((HERE/'ledger.gd.in').read_bytes()),'godot_run':False,'production_or_old_private_project_mutated':False,'ready_for_performance_claim':False})
    print(json.dumps({'prepared':True,'generated_files':len(outputs),'inverse_variants':len(proofs),'metrics':len(METRICS),'step_width':len(METRICS)+7,'godot_run':False}))

if __name__=='__main__': main()
