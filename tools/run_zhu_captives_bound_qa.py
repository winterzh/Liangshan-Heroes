"""Freeze four native captive atlases, run original RTS rescue and shared contracts."""
from pathlib import Path
import json,time
import run_character_art_qa as driver
SUBJECTS=('yang_lin','huang_xin','wang_ying','deng_fei')

def parse(repo,entries):
    first='assets/direction4/bound_yang_lin_20261005.json'
    assert entries==['zhu_captives_bound='+first]
    deps={'tools/build_directional_spriteframes.py','tools/directional_character_sources.py','tools/campaign_terminal_costume_qa.gd','tools/campaign_art_contract.gd'}
    for key in SUBJECTS:
        path='assets/direction4/bound_'+key+'_20261005.json'
        m=json.loads((repo/path).read_text(encoding='utf-8'))
        assert m['character']=='bound_'+key and m['states']=={'idle':['idle']} and len(m['poses'])==4
        resources={f'assets/anim/bound_{key}_idle_{d}.tres' for d in ('se','sw','ne','nw')}
        assert set(m['resources'])==resources;deps|=resources|{path}
        for source in m['sources'].values():
            p=driver.relative_source(repo,source['path']);assert driver.sha(repo/p)==source['sha256'];deps|={p,p+'.import'}
        contract=repo/f'tools/contracts/{key}_bound_20261005'
        deps|={driver.relative_source(repo,str(p)) for p in contract.rglob('*') if p.is_file()}
        for job in json.loads((contract/'jobs.json').read_text(encoding='utf-8')):
            p=driver.relative_source(repo,job['repository_input']);assert driver.sha(repo/p)==job['sha256'];deps.add(p)
            if job.get('request_file'):
                p=driver.relative_source(repo,job['request_file']);assert driver.sha(repo/p)==job['request_sha256'];deps.add(p)
    return [{'character':'zhu_captives_bound','manifest':first,'manifest_sha256':driver.sha(repo/first),'dependencies':sorted(deps)}]

def verify(case,directory,visual):
    p=directory/'report.json';r=json.loads(p.read_text(encoding='utf-8'))
    assert r['passed'] and not r['failures'] and r['character']=='zhu_captives_bound' and r['checks']>=350
    assert r['manifest']=='res://'+case['manifest'] and r['private_profile']['passed'] and r['engine_time_scale']==1.0
    a,b=r['identity_before'],r['identity_after'];assert a['ok'] and b['ok'] and a['source_sha256']==b['source_sha256'] and a['file_count']==b['file_count']
    rows=[x for x in r['runtime'] if x['case']=='current_rts_rescue'];assert {x['key'] for x in rows}==set(SUBJECTS) and len(rows)==4
    for x in rows:
        assert not x['actor_injected'] and x['same_actor'] and x['original_prisoners']==7 and x['normal_player_order'] and x['normal_timed_action'] and x['mission_event'] and x['hp_stats_unchanged'] and x['is_noncombat'] and x['base_speed']==82 and x['variant']=='' and x['battle_coordinator_paused'] is False
    names=set()
    for row in r['screenshots']:
        image=Path(row['path']).resolve();assert image.is_relative_to(directory.resolve()) and driver.sha(image)==row['sha256'];names.add(row['name'])
    expected={key+prefix+d for key in SUBJECTS for prefix in ('_bound_current_','_rescued_current_') for d in ('se','sw','ne','nw')}
    assert not visual or expected==names
    return {'character':r['character'],'checks':r['checks'],'report_sha256':driver.sha(p),'screenshots':len(names),'identity':a}

def main():
    original_parser=driver.parser;original_step=driver.process_step
    def idle_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        while True:
            while running_engine():print('WAIT shared engine natural idle before '+label,flush=True);time.sleep(15)
            try:return original_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
            except RuntimeError as exc:
                if str(exc)!='Godot/Liangshan engine appeared before step '+label:raise
    def step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        result=idle_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
        if label=='zhu_captives_bound':
            for extra,script,key in [('terminal_contract','campaign_terminal_costume_qa.gd','TERMINAL_COSTUME_OUT'),('campaign_contract','campaign_art_contract.gd','CAMPAIGN_ART_REPORT')]:
                directory=evidence/extra;directory.mkdir();output=directory if extra=='terminal_contract' else directory/'report.json'
                idle_step(engine,project,env|{key:str(output)},evidence,extra,['--headless','--script','res://tools/'+script],timeout,renderer,running_engine,steps)
                report=json.loads((directory/'report.json').read_text(encoding='utf-8'));assert report['passed'] and not report.get('failures')
        return result
    def parser():
        ap=original_parser();ap.set_defaults(qa_script=Path(__file__).with_name('zhu_captives_bound_qa.gd'));return ap
    driver.QA_DEST='tools/zhu_captives_bound_qa.gd'
    driver.TOOLS+=('tools/art_character_direction4_qa.gd','tools/run_character_art_qa.py','tools/run_zhu_captives_bound_qa.py')
    driver.parser=parser;driver.parse_cases=parse;driver.verify_character_report=verify;driver.process_step=step
    return driver.main()
if __name__=='__main__':raise SystemExit(main())
