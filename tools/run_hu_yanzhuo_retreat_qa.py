"""Original linked-cavalry chapter full-HP normal-damage retreat regression.
Uses shared idle/lock/source/profile/engine guards. No art edits or publication.
"""
from pathlib import Path
import json
import run_character_art_qa as driver

def verify(case,directory,visual):
 p=directory/'report.json';r=json.loads(p.read_text(encoding='utf-8'))
 assert r.get('passed') is True and not r.get('failures') and r['character']=='hu_yanzhuo' and r['checks']>=35
 assert r['manifest']=='res://'+case['manifest'] and r['private_profile']['passed'] and r['engine_time_scale']==1.0
 a,b=r['identity_before'],r['identity_after'];assert a['ok'] and b['ok'] and a['source_sha256']==b['source_sha256'] and a['file_count']==b['file_count']
 rows=[x for x in r['runtime'] if x['case']=='hu_original_normal_retreat'];assert len(rows)==1
 x=rows[0];assert x['actor_injected'] is False and x['hp_modified'] is False and x['stats_modified'] is False and x['actor_retained'] and x['hp_before']==780 and x['hp_after']==1 and x['damage_ticks']>1 and x['hidden'] and x['signals']=={'deaths':0,'retreats':1} and x['normal_attack'] and x['mission_event'] and x['kill_rewards_unchanged']
 names=set()
 for row in r['screenshots']:
  image=Path(row['path']).resolve();assert image.is_relative_to(directory.resolve()) and driver.sha(image)==row['sha256'];names.add(row['name'])
 expected={'hu_opening_'+d for d in ('se','sw','ne','nw')}|{'hu_normal_hit','hu_retreated','hu_retreat_persistent'}
 assert not visual or expected<=names
 return {'character':'hu_yanzhuo','checks':r['checks'],'report_sha256':driver.sha(p),'screenshots':len(names),'identity':a}

def main():
 original_parser=driver.parser;original_parse=driver.parse_cases
 def parser():
  ap=original_parser();ap.set_defaults(qa_script=Path(__file__).with_name('hu_yanzhuo_retreat_qa.gd'));return ap
 def parse(repo,entries):
  cases=original_parse(repo,entries);assert len(cases)==1 and cases[0]['character']=='hu_yanzhuo'
  contract=repo/'tools/contracts/hu_yanzhuo_direction4_20261003'
  deps=set(cases[0]['dependencies'])
  deps.update(driver.relative_source(repo,str(p)) for p in contract.rglob('*') if p.is_file())
  cases[0]['dependencies']=sorted(deps);return cases
 driver.QA_DEST='tools/hu_yanzhuo_retreat_qa.gd'
 driver.TOOLS+=('tools/art_character_direction4_qa.gd','tools/run_character_art_qa.py','tools/run_hu_yanzhuo_retreat_qa.py')
 driver.parser=parser;driver.parse_cases=parse;driver.verify_character_report=verify
 return driver.main()
if __name__=='__main__':raise SystemExit(main())
