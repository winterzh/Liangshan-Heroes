"""Compare two completed real-GameMap reports. Never invokes Godot or navigation."""
import argparse
import hashlib
import json
from pathlib import Path

CASE_IDS = [
    'strict_same_cell', 'strict_outside_start', 'strict_reachable',
    'strict_weighted_detour_faction1', 'firing_endpoint_reach_reject',
    'firing_partial_reachable', 'firing_one_node_final_empty',
    'firing_zero_reach_guard', 'strict_water_reachable',
]
MAP_RAW = {'baseline':'0f090079229a68269ac94870d1902238444e9ba0ddbc7f359df52f38a4b2db87',
           'candidate':'9145fac5b213ae732fb837f8bd4ecdeccc212b3d39b589798181ad65f6d87122'}
MAP_LF = {'baseline':'35a31084088e8665790b9bc940054d05a96f7e995ecfcd28796d2b6fad63800a',
          'candidate':'cf898e57959412dca0dd3b23de4d9f891bb2859c25cba5df7f63dd0d8f80cc1d'}

def compare_reports(baseline: dict, candidate: dict) -> dict:
    checks=[]; mismatches=[]
    def check(label, ok):
        checks.append({'check':label,'passed':bool(ok)})
        if not ok: mismatches.append(label)
    check('two distinct actual engine PIDs',baseline.get('pid')!=candidate.get('pid') and all(type(x.get('pid')) is int and x['pid']>0 for x in [baseline,candidate]))
    check('same real Godot build and external QA bytes',baseline.get('godot')==candidate.get('godot') and baseline.get('qa_script_raw_sha256')==candidate.get('qa_script_raw_sha256') and bool(baseline.get('qa_script_raw_sha256')))
    for variant,report in [('baseline',baseline),('candidate',candidate)]:
        check(variant+' complete report',report.get('schema')==1 and report.get('variant')==variant and report.get('complete') is True and report.get('failures')==[])
        check(variant+' pinned actual and loaded Map source',report.get('map_source_before')==report.get('map_source_after')==MAP_RAW[variant] and report.get('map_script_lf_sha256')==MAP_LF[variant])
        check(variant+' no stub or Unit/performance overclaim',report.get('stub_cases')==[] and report.get('unit_do_chase_state_equivalence') is False and report.get('performance_claim') is False)
        ids=[x.get('spec',{}).get('id') for x in report.get('cases',[])]
        check(variant+' exact ordered nine-case set',ids==CASE_IDS)
        check(variant+' exactly thirteen original method calls',sum(len(x.get('calls',[])) for x in report.get('cases',[]))==13)
    if len(baseline.get('cases',[]))!=9 or len(candidate.get('cases',[]))!=9:
        return {'schema':1,'comparison_valid':False,'checks':checks,'mismatches':mismatches,'performance_claim':False,'unit_do_chase_state_equivalence':False}
    points_compared=0
    for old,new in zip(baseline['cases'],candidate['cases']):
        label=old['spec']['id'];spec=old['spec']
        check(label+' identical fixture and input specification',spec==new.get('spec'))
        check(label+' equal real grid/nav state in both processes',old.get('navigation_before')==new.get('navigation_before'))
        check(label+' real grid/nav untouched by both call chains',old.get('navigation_before')==old.get('navigation_after') and new.get('navigation_before')==new.get('navigation_after'))
        check(label+' both real maps freed',old.get('map_freed') is True and new.get('map_freed') is True)
        expected_methods=['find_path','find_firing_path'] if spec['firing'] else ['find_path']
        check(label+' exact real call order', [x.get('method') for x in old.get('calls',[])]==[x.get('method') for x in new.get('calls',[])]==expected_methods)
        for call_index,(a,b) in enumerate(zip(old.get('calls',[]),new.get('calls',[]))):
            call_label=label+'/'+str(call_index)
            check(call_label+' identical actual call inputs',a.get('input')==b.get('input'))
            check(call_label+' actual PackedVector2Array type and length',a.get('variant_type')==b.get('variant_type')==35 and a.get('size')==b.get('size')==len(a.get('points',[]))==len(b.get('points',[])))
            check(call_label+' every ordered vector component equal',a.get('points')==b.get('points'))
            check(call_label+' exact packed path variant bytes equal',a.get('variant_bytes_hex')==b.get('variant_bytes_hex') and bool(a.get('variant_bytes_hex')))
            check(call_label+' baseline has no injected observer',a.get('ledger_after_call') is None)
            snap=b.get('ledger_after_call')
            check(call_label+' actual candidate observer call completed',isinstance(snap,dict) and snap.get('mode')=='clockless' and snap.get('errors')==0 and snap.get('chain_open') is True and snap.get('call_kind')==-1 and snap.get('astar_open') is False)
            points_compared+=len(a.get('points',[]))
        ledger=new.get('ledger_after_case');metrics=ledger.get('metrics',{}) if isinstance(ledger,dict) else {}
        check(label+' candidate completed unbroken observer scope',isinstance(ledger,dict) and ledger.get('errors')==0 and ledger.get('chain_open') is False and ledger.get('call_kind')==-1 and ledger.get('astar_open') is False)
        check(label+' exactly one real strict call counted',metrics.get('chain_calls')==metrics.get('chain_completions')==metrics.get('strict_calls')==metrics.get('strict_returns')==1)
        check(label+' expected actual strict branch observed',metrics.get(spec['strict_reason'])==1)
        check(label+' exact actual fallback count',metrics.get('fallback_calls')==metrics.get('fallback_returns')==metrics.get('strict_ranged_empty')==int(spec['firing']))
        if spec['firing']: check(label+' expected actual fallback branch observed',metrics.get(spec['fallback_reason'])==1)
        if label=='firing_one_node_final_empty':
            check(label+' one nonempty native AStar node became an empty final path',metrics.get('fallback_astar_enter')==metrics.get('fallback_astar_return')==metrics.get('fallback_astar_ids_total')==metrics.get('fallback_smooth_empty')==1 and metrics.get('fallback_astar_empty_ids')==0)
        time_keys=[k for k in metrics if k.endswith('_us')]
        check(label+' six method clocks explicitly unavailable',len(time_keys)==6 and all(metrics[k] is None for k in time_keys))
    check('same honest uncovered real branches',baseline.get('uncovered_real_branches')==candidate.get('uncovered_real_branches') and len(baseline.get('uncovered_real_branches',[]))==2)
    return {'schema':1,'comparison_valid':not mismatches,'case_count':9,'original_calls_per_process':13,'ordered_points_compared':points_compared,
            'check_count':len(checks),'checks':checks,'mismatches':mismatches,'stub_cases':[],
            'uncovered_real_branches':baseline.get('uncovered_real_branches'),'unit_do_chase_state_equivalence':False,
            'scope':'Two sequential real GameMap processes, exact ordered path and packed bytes; no navigation oracle or production optimization.',
            'performance_claim':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline',type=Path);parser.add_argument('candidate',type=Path);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    before=args.baseline.read_bytes();after=args.candidate.read_bytes()
    result=compare_reports(json.loads(before),json.loads(after))
    result['source_report_sha256']={'baseline':hashlib.sha256(before).hexdigest(),'candidate':hashlib.sha256(after).hexdigest()}
    result['comparator_raw_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    with args.out.open('x',encoding='utf-8') as stream: json.dump(result,stream,ensure_ascii=False,indent=2);stream.write('\n')
    print(json.dumps({k:result[k] for k in ['comparison_valid','mismatches']}))
    raise SystemExit(0 if result['comparison_valid'] else 2)

if __name__=='__main__':main()
