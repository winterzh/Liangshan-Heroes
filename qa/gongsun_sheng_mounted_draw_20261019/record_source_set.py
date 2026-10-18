from pathlib import Path
import hashlib,json
Q=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
chosen={'torso_v1','upper_arm_v2','forearm_v1','hand_v1','sword_v1','scabbard_v1'};rows=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text())
    if 'key' not in row or 'file' not in row:continue
    assert sha(Q/row['file'])==row['sha256'];args=json.loads((Q/row['exact_tool_arguments']).read_text())
    assert hashlib.sha256(args['prompt'].encode()).hexdigest()==row['exact_prompt_sha256']
    for ref in row['references']:assert sha(Path(ref['path']))==ref['sha256']
    row['selection']='unqualified_rig_source' if row['key'] in chosen else 'not_selected'
    if row['key']=='clear_v1':row['reason']='Whole-rider full-draw attempt shifts/scales the body and sheath mouth; SE tip touches mouth rather than clear. Do not fit every frame to hide drift.'
    if row['key']=='upper_arm_v1':row['reason']='Includes distal sleeve cuff and armor-like shoulder flap/hollow end; replaced by filled cloth upper_arm_v2.'
    rows.append(row)
assert len(rows)==8
with (Q/'prompt_set.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'mode':'builtin_imagegen','raw_originals':8,'selected_parts':sorted(chosen),'originals':rows,'assembly_visual_accepted':False,'production_adopted':False,'full_goal_complete':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'raw_originals':8,'candidate_parts':6,'local_pixel_writes':False}))
