"""Native captive Qin: current RTS original deployment and timed player rescue.
Shared source/engine/idle/profile guards; no packages or publication.
"""
from pathlib import Path
import json
import time
import run_character_art_qa as driver

def parse(repo, entries):
    assert entries == ['bound_qin_ming=assets/direction4/bound_qin_ming_20261005.json']
    manifest_path=entries[0].split('=',1)[1]
    manifest=json.loads((repo/manifest_path).read_text(encoding='utf-8'))
    assert manifest['character']=='bound_qin_ming' and manifest['states']=={'idle':['idle']}
    resources={f'assets/anim/bound_qin_ming_idle_{d}.tres' for d in ('se','sw','ne','nw')}
    assert set(manifest['resources'])==resources
    dependencies=resources|{manifest_path,'tools/build_directional_spriteframes.py','tools/directional_character_sources.py','tools/campaign_terminal_costume_qa.gd','tools/campaign_art_contract.gd'}
    for source in manifest['sources'].values():
        p=driver.relative_source(repo,source['path'])
        assert driver.sha(repo/p)==source['sha256']
        dependencies.update([p,p+'.import'])
    contract=repo/'tools/contracts/qin_ming_bound_20261005'
    dependencies.update(driver.relative_source(repo,str(p)) for p in contract.rglob('*') if p.is_file())
    for job in json.loads((contract/'jobs.json').read_text(encoding='utf-8')):
        p=driver.relative_source(repo,job['repository_input'])
        assert driver.sha(repo/p)==job['sha256'];dependencies.add(p)
        if job.get('request_file'):
            p=driver.relative_source(repo,job['request_file'])
            assert driver.sha(repo/p)==job['request_sha256'];dependencies.add(p)
    dependencies={driver.relative_source(repo,p) for p in dependencies}
    return [{'character':'bound_qin_ming','manifest':manifest_path,'manifest_sha256':driver.sha(repo/manifest_path),'dependencies':sorted(dependencies)}]

def verify(case,directory,visual):
    p=directory/'report.json';r=json.loads(p.read_text(encoding='utf-8'))
    assert r['passed'] is True and not r['failures'] and r['character']=='bound_qin_ming' and r['checks']>=95
    assert r['manifest']=='res://'+case['manifest'] and r['private_profile']['passed'] and r['engine_time_scale']==1.0
    a,b=r['identity_before'],r['identity_after']
    assert a['ok'] and b['ok'] and a['source_sha256']==b['source_sha256'] and a['file_count']==b['file_count']
    rows=[x for x in r['runtime'] if x['case']=='qin_current_rts_rescue'];assert len(rows)==1
    x=rows[0]
    assert x['actor_injected'] is False and x['same_actor'] and x['original_prisoners']==7 and x['normal_player_order'] and x['normal_timed_action'] and x['mission_event'] and x['hp_stats_unchanged'] and x['is_noncombat'] and x['base_speed']==82 and x['variant']=='' and x['battle_coordinator_paused'] is False
    names=set()
    for row in r['screenshots']:
        image=Path(row['path']).resolve()
        assert image.is_relative_to(directory.resolve()) and driver.sha(image)==row['sha256'];names.add(row['name'])
    expected={prefix+d for prefix in ('qin_bound_current_','qin_rescued_current_') for d in ('se','sw','ne','nw')}
    assert not visual or expected<=names
    return {'character':r['character'],'checks':r['checks'],'report_sha256':driver.sha(p),'screenshots':len(names),'identity':a}

def main():
    original_parser=driver.parser
    original_step=driver.process_step
    def idle_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        # User chose natural idle waiting. Never control unrelated processes.
        while True:
            while running_engine():
                print('WAIT shared engine idle before '+label,flush=True)
                time.sleep(15)
            try:
                return original_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
            except RuntimeError as exc:
                if str(exc)!='Godot/Liangshan engine appeared before step '+label:
                    raise
    def process_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps):
        result=idle_step(engine,project,env,evidence,label,args,timeout,renderer,running_engine,steps)
        if label=='bound_qin_ming':
            for extra,script,key in [('terminal_contract','campaign_terminal_costume_qa.gd','TERMINAL_COSTUME_OUT'),('campaign_contract','campaign_art_contract.gd','CAMPAIGN_ART_REPORT')]:
                directory=evidence/extra;directory.mkdir()
                output=directory if extra=='terminal_contract' else directory/'report.json'
                idle_step(engine,project,env|{key:str(output)},evidence,extra,['--headless','--script','res://tools/'+script],timeout,renderer,running_engine,steps)
                report=json.loads((directory/'report.json').read_text(encoding='utf-8'))
                assert report['passed'] is True and not report.get('failures')
        return result
    def parser():
        ap=original_parser();ap.set_defaults(qa_script=Path(__file__).with_name('qin_ming_bound_qa.gd'));return ap
    driver.QA_DEST='tools/qin_ming_bound_qa.gd'
    driver.TOOLS+=('tools/art_character_direction4_qa.gd','tools/run_character_art_qa.py','tools/run_qin_ming_bound_qa.py')
    driver.parser=parser;driver.parse_cases=parse;driver.verify_character_report=verify;driver.process_step=process_step
    return driver.main()
if __name__=='__main__':raise SystemExit(main())
