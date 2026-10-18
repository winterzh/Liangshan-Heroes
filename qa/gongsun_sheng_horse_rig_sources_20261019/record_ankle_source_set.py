from pathlib import Path
import ast,datetime,hashlib,json
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
chosen={'body_v1','fore_upper_v2','fore_shin_v2','hind_upper_v2','hind_shin_v1','hoof_v1'}
old={'fore_lower_v1','hind_lower_v2'};rows=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text())
    if 'key' not in row or 'file' not in row:continue
    assert sha(Q/row['file'])==row['sha256']
    args=json.loads((Q/row['exact_tool_arguments']).read_text());assert hashlib.sha256(args['prompt'].encode()).hexdigest()==row['exact_prompt_sha256']
    for ref in row['references']:assert sha(Path(ref['path']))==ref['sha256']
    row['selection']='assembly_v3_candidate' if row['key'] in chosen else 'previous_assembly_v1_only' if row['key'] in old else 'superseded'
    row['production_adopted']=False;rows.append(row)
assert len(rows)==12
save(Q/'prompt_set_v2.json',{'mode':'builtin_imagegen','raw_sources':12,'new_this_batch':4,'candidate_parts':sorted(chosen),'originals':rows,'scope':'Source provenance snapshot before v3 native/visual acceptance; source size/position invariance requested by prompt is not assumed proven. New hooves and shins are registered manually once.','production_adopted':False,'full_goal_complete':False})
save(Q/'assembly_v2/admission.json',{'recorded_at':datetime.datetime.now().isoformat(),'command':'python -X utf8 -B qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v2/run.py','exit_code':1,'reason':'shared engine lane occupied','native_started':False,'actual_project_created':False,'predecessor_frozen_preserved':True,'successor':'assembly_v3','successor_reason':'body bob multiplier aligned to leg-root multiplier during slow/hold/start; new frozen inputs, no rewriting attempted or predecessor inputs'})
for p in Q.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
print(json.dumps({'sources':len(rows),'new_painted_sources':4,'candidate_parts':len(chosen)}))
