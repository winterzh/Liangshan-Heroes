"""Freeze original eight openings and the real seven-actor rescue/return route."""
from pathlib import Path
import json,time
import run_character_art_qa as driver
import run_zhu_captives_bound_qa as captives

def parse(repo,entries):
    assert entries==['rescued_seven_current=assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_declared_v4.json']
    case=captives.parse(repo,['zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json'])[0]
    case['character']='rescued_seven_current'
    case['manifest']=entries[0].split('=',1)[1]
    case['manifest_sha256']=driver.sha(repo/case['manifest'])
    deps=set(case['dependencies'])|{'tools/run_rescued_seven_art_qa.py','tools/run_zhu_captives_bound_qa.py','tools/art_character_direction4_qa.gd'}
    audit='qa/zhu_wounded_20261005/rescued_seven_candidate_identity_audit_v4.json'
    deps.add(audit)
    for row in json.loads((repo/audit).read_text(encoding='utf-8'))['characters']:
        mp=row['manifest'];assert driver.sha(repo/mp)==row['manifest_sha256']
        m=json.loads((repo/mp).read_text(encoding='utf-8'))
        deps|={mp}|set(m['resources'])
        for source in m['sources'].values():
            path=source['path'];assert driver.sha(repo/path)==source['sha256']
            deps|={path,path+'.import'}
    case['dependencies']=sorted(deps)
    return [case]

def verify(case,directory,visual):
    p=directory/'report.json';r=json.loads(p.read_text(encoding='utf-8'))
    assert r['passed'] and not r['failures'] and r['character']==case['character'] and r['checks']>=200
    assert r['private_profile']['passed'] and r['engine_time_scale']==1.0
    a,b=r['identity_before'],r['identity_after'];assert a['ok'] and b['ok'] and a['source_sha256']==b['source_sha256']
    assert len(r['resources'])==8 and {x['chapter'] for x in r['resources']}=={'level'+str(i) for i in range(1,9)}
    keys={'shi_qian','shi_xiu','qin_ming','yang_lin','huang_xin','wang_ying','deng_fei'}
    rows=[x for x in r['runtime'] if x['case']=='seven_actual_return']
    assert {x['key'] for x in rows}==keys
    assert all(x['same_actor'] and not x['actor_teleported'] and x['player_movement'] and x['distance_moved']>900 and x['camp_distance']<190 and x['noncombat'] and x['visual_variant']=='zhu_wounded_'+x['key'] for x in rows)
    poses=[x for x in r['runtime'] if x['case']=='rescued_native_route']
    assert len(poses)==28 and {(x['key'],x['direction']) for x in poses}=={(k,d) for k in keys for d in ('se','sw','ne','nw')}
    assert all(x['idle']['present'] and len(x['walk'])==4 and x['same_portrait'] and x['directional'] for x in poses)
    for row in r['screenshots']:
        image=Path(row['path']).resolve();assert image.is_relative_to(directory.resolve()) and driver.sha(image)==row['sha256']
    assert not visual or len(r['screenshots'])==16
    return {'character':r['character'],'checks':r['checks'],'report_sha256':driver.sha(p),'screenshots':len(r['screenshots']),'identity':a}

def main():
    original_parser=driver.parser;original_step=driver.process_step
    def step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        while True:
            while running_engine():print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
            try:return original_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
            except RuntimeError as exc:
                if str(exc)!='Godot/Liangshan engine appeared before step '+label:raise
    def parser():
        ap=original_parser();ap.set_defaults(qa_script=Path(__file__).with_name('rescued_seven_art_qa.gd'));return ap
    driver.QA_DEST='tools/rescued_seven_art_qa.gd'
    driver.TOOLS+=('tools/art_character_direction4_qa.gd','tools/run_character_art_qa.py','tools/run_zhu_captives_bound_qa.py','tools/run_rescued_seven_art_qa.py')
    driver.parser=parser;driver.parse_cases=parse;driver.verify_character_report=verify;driver.process_step=step
    return driver.main()
if __name__=='__main__':raise SystemExit(main())
