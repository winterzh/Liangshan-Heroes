"""Preserve v19c and reconstruct the inert Mission owner required by Gao graph capture."""
from pathlib import Path
import ast,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';BASE=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    run=BASE/'campaign_units_v19c_8ab33853';rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert not r['complete'] and r['lock_released'];report=json.loads((run/'skills/report.json').read_text(encoding='utf-8'))
    assert report['checks']==761 and len(report['failures'])==3 and len(report['runtime'])==7
    assert all('level5' in x and 'recaptured' in x for x in report['failures'])
    for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for src,dst in [('receipt.json','campaign_units_failed_receipt_v19c.json'),('skills/report.json','campaign_units_failed_report_v19c.json'),('skills.log','campaign_units_failed_log_v19c.txt')]:
        p=QA/dst;assert not p.exists();shutil.copy2(run/src,p);assert sha(p)==sha(run/src)
    directory=QA/'campaign_units_failed_snapshots_v19c';directory.mkdir(exist_ok=False);snapshots=[]
    for row in report['runtime']:
        source=Path(row['snapshot_path']);assert sha(source)==row['snapshot_sha256'];p=directory/source.name;shutil.copy2(source,p)
        snapshots.append({'case':row['case'],'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
    rejected={'qualified':False,'receipt_sha256':sha(rp),'report_sha256':sha(run/'skills/report.json'),'checks':761,'failures':report['failures'],'harnesses':r['harnesses'],'snapshots':snapshots,
      'finding':'All original actor construction/key-kind/reference checks and four Daming whole recaptures passed. Gao recapture correctly refused missing installed Mission/buttons on detached QA owner (LEVEL5_MISSION_BUTTONS). No production guard change.',
      'fix':'Sibling v19d uses the installed inert Mission constructor with typed private HUD/fx shell, empty ledger and no begin/tick/reward. Disconnect its owned localization signal before disposal. Re-run full seven cases.'}
    p=QA/'campaign_units_rejected_v19c.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=QA/'harness/campaign_units_v19c.gd';s=p.read_text(encoding='utf-8').replace('campaign_units_v19c','campaign_units_v19d')
    needle='\towner.next_entity_id=b.next_entity_id';assert s.count(needle)==1
    extra='''
\tif id=="level5":
\t\towner.hud=load("res://scripts/hud.gd").new();owner.hud.process_mode=Node.PROCESS_MODE_DISABLED;owner.hud.set_block_signals(true);owner.add_child(owner.hud)
\t\towner.fx_root=Node2D.new();owner.fx_root.process_mode=Node.PROCESS_MODE_DISABLED;owner.fx_root.set_block_signals(true);owner.add_child(owner.fx_root)
\t\towner.mission=load("res://scripts/campaign_mission.gd").new(owner)
\t\tcheck(owner.mission.events.is_empty() and owner.mission._generation==0 and not owner.mission._campaign_configured,label+" fresh inert Mission shell does not start chapter")'''
    s=s.replace(needle,needle+extra)
    needle='\towner.free()';assert s.count(needle)==1
    extra='''\tif id=="level5" and is_instance_valid(owner.mission):
\t\tvar localize=root.get_node("Localize")
\t\tif localize.language_changed.is_connected(owner.mission._on_language_changed):localize.language_changed.disconnect(owner.mission._on_language_changed)
'''
    s=s.replace(needle,extra+needle)
    p=p.with_name('campaign_units_v19d.gd');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    p=QA/'harness/run_campaign_units_v19c.py';s=p.read_text(encoding='utf-8').replace('campaign_units_v19c','campaign_units_v19d');ast.parse(s)
    p=p.with_name('run_campaign_units_v19d.py');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'actual_failed_batch_preserved':True,'new_production_patch':False,'sibling':'v19d','cases':7}))
if __name__=='__main__':main()
