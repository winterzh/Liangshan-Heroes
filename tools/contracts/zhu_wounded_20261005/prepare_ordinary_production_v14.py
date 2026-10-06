"""Prepare unchanged-production combat/death verification after candidate review."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'qa/zhu_wounded_20261005/harness'
def once(text,old,new):assert text.count(old)==1,old[:100];return text.replace(old,new)

def main():
    combat=(HERE/'ordinary_hurt_pilot_v13.gd').read_text(encoding='utf-8').replace('ordinary_hurt_pilot_v13','ordinary_combat_production_v14')
    combat=once(combat,'old_poses=row.current','old_poses=row.candidate')
    death=(HERE/'ordinary_death_pilot_v10a.gd').read_text(encoding='utf-8').replace('ordinary_death_pilot_v10a','ordinary_death_production_v14')
    death=death.replace('row.candidate','row.candidate') # keep original query field names explicit below
    death=death.replace('row.current','row.candidate')
    py=(HERE/'run_ordinary_hurt_pilot_v13.py').read_text(encoding='utf-8').replace('ordinary_hurt_pilot_v13','ordinary_production_v14')
    py=once(py,"assert pilot['result']['passed'] and pilot['result']['checks']==346 and len(pilot['result']['screenshots'])==32",
            "assert pilot['result']['passed'] and pilot['candidate_hurt_routes_verified'] and len(pilot['result']['screenshots'])==48")
    py=once(py,"assert review['passed'] and review['death_qualified']","assert review['passed'] and review['hurt_qualified']")
    py=once(py,'assert changed==[],changed',"assert changed==['scripts/art_db.gd'],changed")
    py=once(py,'inputs=before',"assert sha(ROOT/'scripts/art_db.gd')==pilot['private_patch']['patched_sha256']\n    inputs=[dict(row,sha256=sha(ROOT/row['path'])) for row in before]")
    py=once(py,"assert all(sha(ROOT/row['path'])==row['sha256']==sha(old/row['path']) for row in inputs+existing+new if row['path']!='scripts/art_db.gd')",
            "assert all(sha(ROOT/row['path'])==row['sha256']==sha(old/row['path']) for row in inputs+existing+new)")
    py=py.replace("'private_runtime_patches':1","'private_runtime_patches':0")
    a=py.index("        art=project/'scripts/art_db.gd';text=");z=py.index("        dump(project/'ordinary_predeath_query_baselines.json'",a)
    py=py[:a]+py[z:]
    py=once(py,"for name in ['ordinary_production_v14.gd','run_ordinary_production_v14.py']:",
            "for name in ['ordinary_combat_production_v14.gd','ordinary_death_production_v14.gd','run_ordinary_production_v14.py']:")
    py=once(py,"'harnesses':[],'steps':[],","'harnesses':[],'steps':[],'results':{},")
    old="""        stages=[('import',['--headless','--editor','--import','--quit']),('render',['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000','--script','res://ordinary_production_v14.gd'])]"""
    new="""        common=['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000']
        stages=[('import',['--headless','--editor','--import','--quit']),('combat',common+['--script','res://ordinary_combat_production_v14.gd']),('death',common+['--script','res://ordinary_death_production_v14.gd'])]"""
    py=once(py,old,new)
    py=once(py,"            log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)",
            "            out=run/label;out.mkdir();env['ART_QA_OUT']=str(out)\n            log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)")
    old="""            assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-5500:]
        result=read(out/'report.json');assert result['passed'] and result['engine_time_scale']==1.0 and len(result['screenshots'])==48"""
    new="""            assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-5500:]
            if label!='import':
                result=read(out/'report.json');assert result['passed'] and result['engine_time_scale']==1.0
                assert len(result['screenshots'])==(48 if label=='combat' else 32)
                receipt['results'][label]=result
        assert set(receipt['results'])=={'combat','death'}"""
    py=once(py,old,new)
    py=once(py,"assert all(sha(project/row['path'])==row['sha256'] for row in inputs+existing+new if row['path']!='scripts/art_db.gd')\n        assert sha(art)==receipt['private_patch']['patched_sha256']",
            "assert all(sha(project/row['path'])==row['sha256'] for row in inputs+existing+new)")
    py=once(py,"assert all(sha(Path(row['path']))==row['sha256'] for row in result['screenshots'])",
            "assert all(sha(Path(row['path']))==row['sha256'] for result in receipt['results'].values() for row in result['screenshots'])")
    py=once(py,'complete=True,result=result,root_input_drift=0,private_input_drift_except_declared_patch=0,private_patch_verified=True,candidate_hurt_routes_verified=True',
            'complete=True,root_input_drift=0,private_input_drift=0,covered_default_routes_verified=True')
    scope='Current production scripts copied unchanged with Wu death, Lin SW death and standing hurt adopted; no private runtime patch. Original Lin/Zhu and Wu/Daming actual orders, melee/counterhit and separate level1 fatal combat/death/shadow release. Unaffected ordinary and story routes guarded. Contact/freeze/fog/zoom/phase fixtures; not continuous animation, natural full chapter/save/performance/export/platform qualification.'
    py,n=re.subn(r"             'scope':'.*'}","             'scope':'"+scope+"'}",py);assert n==1
    py=py.replace('Original actor normal melee/counterhit pilot for corrected Lin southwest standing hurt.',
                  'Unmodified production combat/death qualification after reviewed candidate adoption.')
    for name,text in [('ordinary_combat_production_v14.gd',combat),('ordinary_death_production_v14.gd',death),('run_ordinary_production_v14.py',py)]:
        p=HERE/name;assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print('Prepared production v14; admission requires completed/reviewed v13 and exact root adoption.')

if __name__=='__main__':main()
