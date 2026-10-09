"""Keep native SE failures; wrong support and costume drift are not qualified."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for state in ('walk_a_se','walk_b_se','walk_b2_se'):
    jp=HERE/f'jobs/wang_ying_{state}_v4.json';j=read(jp)
    assert sha(ROOT/j['output'])==j['output_sha256'] and sha(ROOT/j['request'])==j['request_sha256']
    for parent in j['references']:assert sha(ROOT/parent['path'])==parent['sha256']
    rows.append({'state':state,'path':j['output'],'sha256':j['output_sha256'],
        'job':jp.relative_to(ROOT).as_posix(),'job_sha256':sha(jp),
        'selected_as_candidate':state=='walk_a_se'})
review={'schema':1,'character':'wang_ying','direction':'se','result':'opposing_pose_attempts_rejected',
    'rows':rows,'directly_viewed_native':True,
    'reasons':{'walk_b_se':['Still repeats A: image-right foreground boot planted and image-left boot raised'],
        'walk_b2_se':['Pose-first attempt still repeats the same planted foreground boot',
            'Shin wraps changed from Wang Ying horizontal bands to guide-style crisscross wrapping',
            'Do not select as a matching opposing walking frame']},
    'next':'Use an explicit short-adult geometry pose guide or different native edit strategy; SW/NW prepared requests have not run',
    'method':'built-in image_gen attempts; native PNGs/request/parents retained unchanged',
    'production_qualified':False}
p=ROOT/'qa/zhu_wounded_20261005/wang_ying_se_opposite_rejections_v4.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'rejected_native_sources':2,'ancestor_hashes_passed':True,'production_qualified':False}))
