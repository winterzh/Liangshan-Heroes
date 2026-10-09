"""Preserve executed v15 and wait for actual four-vote direction before gait sampling."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005';H=QA/'harness'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_continuous_gait_v15_84f1500f'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    r=read(RUN/'receipt.json');report=read(RUN/'gait/report.json')
    assert not r['complete'] and r['lock_released'] and not report['passed'] and report['checks']==301 and len(report['screenshots'])==70
    assert len(report['failures'])==12
    summaries=[x for x in report['runtime'] if x['case']=='gait_summary']
    assert all(x['samples']==8 and len(x['poses_seen'])==(4 if x['direction']=='se' else 5) for x in summaries)
    for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for row in r['source_files']:assert sha(ROOT/row['path'])==row['sha256']
    rejected={'qualified':False,'receipt':str(RUN/'receipt.json'),'receipt_sha256':sha(RUN/'receipt.json'),
        'report':str(RUN/'gait/report.json'),'report_sha256':sha(RUN/'gait/report.json'),'checks':301,'captures':70,
        'failures':report['failures'],'harnesses':r['harnesses'],'lock_released':True,
        'reason':'Sampler started at movement blend threshold before existing Unit._face_dir four-vote transition completed. First new-direction sample included previous-direction gait, so three turning directions per actor counted five source poses. Actual before/after observations retain evidence; not a qualified continuous run.',
        'production_changed':False,'next':'Sibling v15a waits for actual direction and movement before sampling; no direct direction or animation writes, no subject physics pause. Preserve v15 producer and all evidence.'}
    p=QA/'ordinary_continuous_gait_rejected_v15.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    source=H/'ordinary_continuous_gait_v15.gd';text=source.read_text(encoding='utf-8')
    old='\t\t\tif u._move_blend<=0.3:continue';assert text.count(old)==1
    text=text.replace(old,'\t\t\t# Preserve real four-vote turn hysteresis; sample only after it settles.\n\t\t\tif u._move_blend<=0.3 or u.animation_direction!=d:continue').replace('ordinary_continuous_gait_v15','ordinary_continuous_gait_v15a')
    p=H/'ordinary_continuous_gait_v15a.gd';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    source=H/'run_ordinary_continuous_gait_v15.py';text=source.read_text(encoding='utf-8').replace('ordinary_continuous_gait_v15','ordinary_continuous_gait_v15a')
    p=H/'run_ordinary_continuous_gait_v15a.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'v15_preserved':True,'v15_qualified':False,'v15a_prepared':True,'production_changed':False}))
if __name__=='__main__':main()
