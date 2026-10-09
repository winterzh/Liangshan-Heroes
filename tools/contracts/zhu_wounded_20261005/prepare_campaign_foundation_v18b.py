"""Preserve v18a; match Gao's Liangshan environment and typed private HUD."""
from pathlib import Path
import ast,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    run=ROOT.parent/'qa-ordinary-posture-20261006/campaign_foundation_v18a_4f530eeb';rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert not r['complete'] and r['lock_released']
    assert 'LEVEL5_CAMPAIGN_ENVIRONMENT_REQUIRED' in r['failure']['message'] and 'CanvasLayer' in r['failure']['message']
    for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'campaign_foundation_failed_receipt_v18a.json';assert not p.exists();shutil.copy2(rp,p)
    log=run/'skills.log';p=QA/'campaign_foundation_failed_log_v18a.txt';assert not p.exists();shutil.copy2(log,p)
    rejected={'qualified':False,'receipt_sha256':sha(rp),'log_sha256':sha(log),'harnesses':r['harnesses'],
        'failures':['Gao is intentionally absent from CampaignEnvironment.LEVELS; its production map uses the native Liangshan environment, not CampaignEnvironment.enabled(level5). Copied Level4 guard was wrong.',
        'QA owner.hud is typed HUD; a bare CanvasLayer is rejected.',
        'QA dispatched process(delta=0) before original strategy timer elapsed, so end-button stage could be postponed. Use explicit 0.5-second authored stage tick, without writing the timer.'],
        'fix':'Remove erroneous factory environment prerequisite only; retain native empty environment_buildings. Use installed HUD.new and actual chapter stage tick in sibling v18b. No change to environment/gameplay/level values.'}
    p=QA/'campaign_foundation_rejected_v18a.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=ROOT/'scripts/run_level5_world_factory.gd';before=sha(p);s=p.read_text(encoding='utf-8')
    old='\tif not CampaignEnvironment.enabled("level5"): return _bad("LEVEL5_CAMPAIGN_ENVIRONMENT_REQUIRED")';assert s.count(old)==1
    s=s.replace(old,'\t# Gao uses the native Liangshan environment; CampaignEnvironment excludes level5.\n\t# Its normal-launch scoped environment_buildings remains empty.');p.write_bytes(s.encode('utf-8'))
    fix={'path':p.relative_to(ROOT).as_posix(),'before_sha256':before,'after_sha256':sha(p),'producer_sha256':sha(Path(__file__)),
        'parent_failed_receipt_sha256':sha(rp),'scope':'Correct copied inert-factory prerequisite to match installed native Liangshan launch. No world adapter or public entry qualification.'}
    p=QA/'campaign_gao_factory_fix_v18b.json';assert not p.exists();p.write_bytes((json.dumps(fix,indent=2)+'\n').encode())
    p=QA/'harness/campaign_foundation_v18a.gd';s=p.read_text(encoding='utf-8')
    s=s.replace('owner.hud=CanvasLayer.new()','owner.hud=load("res://scripts/hud.gd").new()').replace('b.level.process(b,0.0)','b.level.process(b,0.5)').replace('campaign_foundation_v18a','campaign_foundation_v18b')
    p=p.with_name('campaign_foundation_v18b.gd');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    p=QA/'harness/run_campaign_foundation_v18a.py';s=p.read_text(encoding='utf-8').replace('campaign_foundation_v18a','campaign_foundation_v18b')
    old="expected=endings['after_sha256'] if delta['path']=='scripts/run_official_restore_profile.gd' else delta['after_sha256']"
    new="expected=endings['after_sha256'] if delta['path']=='scripts/run_official_restore_profile.gd' else delta['after_sha256']\n        if delta['path']=='scripts/run_level5_world_factory.gd':expected=read(ROOT/'qa/zhu_wounded_20261005/campaign_gao_factory_fix_v18b.json')['after_sha256']"
    assert old in s;s=s.replace(old,new);ast.parse(s);p=p.with_name('run_campaign_foundation_v18b.py');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'failed_batch_preserved':True,'production_fix':'Gao inert factory environment prerequisite','siblings':'v18b'}))
if __name__=='__main__':main()
