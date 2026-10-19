"""Verify actual stop traces: lifted sequential steps, planted support and compact final stance."""
from pathlib import Path
import hashlib,json,math,sys
Q=Path(__file__).resolve().parent;E=Path(sys.argv[1]).resolve()
assert not (E/'recovery_verification.json').exists()
report=json.loads((E/'browser_report.json').read_text(encoding='utf-8'))
trace=json.loads((E/'trace.json').read_text(encoding='utf-8'))
fixture=json.loads((E/'fixture.json').read_text(encoding='utf-8'))
F={'se':[1,0,0],'sw':[0,1,0],'ne':[0,-1,0],'nw':[-1,0,0]}
def dist(a,b):return math.dist(a,b)
def rest(row):
    f=F[row['direction']];side=1 if row['leg']=='right' else -1
    root=[v*row['distanceWorld']/fixture['params']['model_to_world_scale'] for v in f]
    return [root[0]+(-f[1]*20+f[0]*8)*side,root[1]+(f[0]*20+f[1]*8)*side,0]
stops=[];start=0
for section in report['timeline']:
    if section['speed']==0:stops.append((start,section['end']))
    start=section['end']
assert len(stops)==3
rows=[]
for start,end in stops:
    pairs={}
    for row in trace:
        if start+1e-7<row['t']<end:
            assert dist(row['restTarget'],rest(row))<1e-6
            pairs.setdefault((row['direction'],row['t']),[]).append(row)
    assert pairs
    lifted=0;max_simultaneous=0
    for pair in pairs.values():
        assert len(pair)==2
        recovering=[row for row in pair if row['mode']=='settling']
        max_simultaneous=max(max_simultaneous,len(recovering));assert len(recovering)<=1
        if recovering:
            support=next(r for r in pair if r not in recovering)
            assert support['mode']=='held' and abs(support['sole'][2])<1e-6
            lifted+=sum(r['sole'][2]>1 for r in recovering)
    assert lifted>=8,'No recorded lifted recovery across headings'
    for direction in F:
        observed=[r for r in trace if r['direction']==direction and start+1e-7<r['t']<end]
        assert max(r['distanceWorld'] for r in observed)-min(r['distanceWorld'] for r in observed)<1e-6
        final_t=max(r['t'] for r in observed)
        final=[r for r in observed if r['t']==final_t]
        assert end-final_t<.15 and len(final)==2
        assert all(r['mode']=='held' and dist(r['sole'],rest(r))<1e-6 for r in final)
    rows.append({'interval':[start,end],'paired_frames':len(pairs),'lifted_recovery_samples':lifted,'max_simultaneous_recovery_feet':max_simultaneous,'final_compact_stance_all_four_directions':True,'root_stationary':True})
assert report['finalFeetHeld'] and len(report['finalRestPositions'])==4
result={'scope':'Recorded browser stop transitions only; no native, full sole contact, natural gait or production acceptance.',
    'trace_sha256':hashlib.sha256((E/'trace.json').read_bytes()).hexdigest(),
    'rest_offset_source':{'right_forward':8,'left_forward':-8,'right_lateral':20,'left_lateral':-20},
    'stops':rows,'passed':True,'production_adopted':False,'natural_gait_accepted':False}
with (E/'recovery_verification.json').open('x',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result))
