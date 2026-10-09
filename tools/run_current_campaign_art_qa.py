"""Freeze current registered chapters; inventory openings and exercise original seven evacuees."""
from pathlib import Path
import json,time
import run_character_art_qa as driver
import run_zhu_captives_bound_qa as captives

def parse(repo,entries):
    assert entries==['current_campaign_art=assets/direction4/bound_yang_lin_20261005.json']
    case=captives.parse(repo,['zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json'])[0]
    case['character']='current_campaign_art'
    case['dependencies']+=['tools/run_current_campaign_art_qa.py','tools/run_zhu_captives_bound_qa.py','tools/art_character_direction4_qa.gd']
    proof=repo/'tools/contracts/current_campaign_opening_20261005/snapshot.json'
    if proof.is_file():
        snapshot=json.loads(proof.read_text(encoding='utf-8'))
        case['dependencies']+=['tools/contracts/current_campaign_opening_20261005/snapshot.json']+list(snapshot['source_evidence_sha256'])
        assert all(driver.sha(repo/p)==digest for p,digest in snapshot['source_evidence_sha256'].items())
    return [case]

def verify(case,directory,visual):
    p=directory/'report.json';r=json.loads(p.read_text(encoding='utf-8'))
    assert r['passed'] and not r['failures'] and r['character']=='current_campaign_art' and r['checks']>=50
    assert r['private_profile']['passed'] and r['engine_time_scale']==1.0
    a,b=r['identity_before'],r['identity_after'];assert a['ok'] and b['ok'] and a['source_sha256']==b['source_sha256']
    assert {x['chapter'] for x in r['resources']}=={'level'+str(i) for i in range(1,9)} and len(r['resources'])==8
    rows=[x for x in r['runtime'] if x['case']=='seven_actual_return']
    defenders=[x for x in r['runtime'] if x['case']=='ordinary_defender_clearance']
    assert len(defenders)==11 and all(x['normal_player_attack'] and not x['damage_injected'] and not x['actor_injected'] and x['cleared'] for x in defenders)
    assert {x['key'] for x in rows}=={'shi_qian','shi_xiu','qin_ming','yang_lin','huang_xin','wang_ying','deng_fei'}
    assert all(x['same_actor'] and not x['actor_teleported'] and x['player_movement'] and x['distance_moved']>900 and x['camp_distance']<190 and x['noncombat'] for x in rows)
    names=set()
    for row in r['screenshots']:
        image=Path(row['path']).resolve();assert image.is_relative_to(directory.resolve()) and driver.sha(image)==row['sha256'];names.add(row['name'])
    expected={'shi_xiu_'+s+'_current_'+d for s in ['bound','rescued'] for d in ['se','sw','ne','nw']}|{'seven_evac_16_23','seven_evac_25_18','seven_evac_43_18','seven_evac_52_29'}
    assert not visual or expected==names
    return {'character':r['character'],'checks':r['checks'],'report_sha256':driver.sha(p),'screenshots':len(names),'identity':a}

def main():
    original_parser=driver.parser;original_step=driver.process_step
    def step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        while True:
            while running_engine():print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
            try:return original_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
            except RuntimeError as exc:
                if str(exc)!='Godot/Liangshan engine appeared before step '+label:raise
    def parser():
        ap=original_parser();ap.set_defaults(qa_script=Path(__file__).with_name('current_campaign_art_qa.gd'));return ap
    driver.QA_DEST='tools/current_campaign_art_qa.gd'
    driver.TOOLS+=('tools/art_character_direction4_qa.gd','tools/run_character_art_qa.py','tools/run_zhu_captives_bound_qa.py','tools/run_current_campaign_art_qa.py')
    driver.parser=parser;driver.parse_cases=parse;driver.verify_character_report=verify;driver.process_step=step
    return driver.main()
if __name__=='__main__':raise SystemExit(main())
