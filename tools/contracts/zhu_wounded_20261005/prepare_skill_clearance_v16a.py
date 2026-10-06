"""Preserve failed v16; use original nonhero combat targets for Wu's actual rules."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';H=QA/'harness'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_skill_clearance_v16_138b15e4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    rp=RUN/'receipt.json';r=read(rp);report=read(RUN/'skills/report.json')
    assert not r['complete'] and r['lock_released'] and not report['passed'] and report['checks']==329
    assert len(report['screenshots'])==48 and report['failures']==['original enemy hero for cast target wu_song']*4
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for src,dst in [(rp,QA/'ordinary_skill_clearance_failed_receipt_v16.json'),(RUN/'skills/report.json',QA/'ordinary_skill_clearance_failed_report_v16.json')]:
        assert not dst.exists();shutil.copy2(src,dst);assert sha(src)==sha(dst)
    views=[];directory=QA/'ordinary_skill_clearance_preview_v16_frames';directory.mkdir(exist_ok=False)
    for name in ['lin_chong_0_se_mid_1440x960','lin_chong_0_se_late_1920x1080','lin_chong_1_se_late_1280x720']:
        row=next(x for x in report['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
        dst=directory/src.name;shutil.copy2(src,dst);views.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    rejected={'qualified':False,'receipt_sha256':sha(rp),'report_sha256':sha(RUN/'skills/report.json'),'checks':329,'captures':48,
        'failures':report['failures'],'harnesses':r['harnesses'],'lock_released':True,'viewed_partial':views,
        'reason':'All Lin four-heading active mid/late cases completed. Wu four cases stopped before cast: generic fixture demanded an original enemy hero, absent at current Daming opening. Wu active skills are self/AOE/summon and do not have the Lin R hero_only target rule. No full skill qualification.',
        'fix':'Sibling v16a preserves original enemy hero selection for Lin; Wu selects original living enemy combat unit, excluding buildings/resources/noncombat/workers, using same unaltered chapter roster. No inserted dummy, target stats, ability or production changes.',
        'scope':'Partial native phase observations only. Complete source drift and full 112-view qualification require new completed run.'}
    p=QA/'ordinary_skill_clearance_rejected_v16.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    text=(H/'ordinary_skill_clearance_v16.gd').read_text(encoding='utf-8')
    old='var foes: Array=b.units.filter(func(e):return alive(e) and e.faction==1 and e.is_hero)'
    new='var foes: Array=b.units.filter(func(e):return alive(e) and e.faction==1 and (e.is_hero if key=="lin_chong" else not e.is_building and not e.is_resource and not e.is_noncombat and not e.is_worker))'
    assert text.count(old)==1;text=text.replace(old,new).replace('original enemy hero for cast target','original rule-valid combat target').replace('ordinary_skill_clearance_v16','ordinary_skill_clearance_v16a')
    p=H/'ordinary_skill_clearance_v16a.gd';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    text=(H/'run_ordinary_skill_clearance_v16.py').read_text(encoding='utf-8').replace('ordinary_skill_clearance_v16','ordinary_skill_clearance_v16a')
    p=H/'run_ordinary_skill_clearance_v16a.py';assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print(json.dumps({'v16_preserved':True,'v16_qualified':False,'v16a_prepared':True,'production_changed':False,'expected_captures':112}))
if __name__=='__main__':main()
