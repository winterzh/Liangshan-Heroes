"""Derive an independently frozen gait comparison from the completed idle diagnostic."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2];H=ROOT/'qa/zhu_wounded_20261005/harness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
gdsrc=H/'ordinary_idle_motion_comparison_v4.gd';g=gdsrc.read_text(encoding='utf-8')
for before,after in [('ordinary_idle_comparison_actor_v4','ordinary_gait_comparison_actor_v5'),
                     ('ordinary_idle_motion_comparison','ordinary_gait_motion_comparison'),
                     ('ordinary_idle_motion_result','ordinary_gait_motion_result'),
                     ('ordinary_idle_comparison.json','ordinary_gait_comparison.json'),
                     ('ordinary_idle_live_','ordinary_gait_live_'),
                     ('ORDINARY_IDLE_QA','ORDINARY_GAIT_QA'),
                     ('use_candidate_idle','use_candidate_family'),
                     ('sampled_candidate_idle','sampled_candidate_family'),
                     ('native_idle_applied','native_family_applied'),
                     ('load_idle_family','load_gait_family')]:g=g.replace(before,after)
g=g.replace('baseline idle versus candidate idle, existing production walk','baseline ordinary art versus candidate upright idle/four-phase walk')
g=g.replace('"phase":u._anim_t,','"phase":u._anim_t,"frame_index":u.sampled_frame_index,')
g=g.replace('"existing_production_walk_"','"native_candidate_walk_"')
g=g.replace('s.units[i].state=="walk" and not s.units[i].native_family_applied','s.units[i].state=="walk" and s.units[i].native_family_applied')
g=g.replace('var passed := saved and checks.all(func(c):return c.passed)', '''var seen: Dictionary = {}
	for sample in samples:
		for row in sample.units:
			if row.candidate and row.native_family_applied and row.state=="walk":
				seen[row.direction+"_"+str(row.frame_index)]=true
	for d in DIRS:
		for phase in range(4):
			checks.append({"check":"four_authored_walk_phases_"+d+"_"+str(phase),"passed":seen.has(d+"_"+str(phase))})
	var passed := saved and checks.all(func(c):return c.passed)''')
g=g.replace('"samples":samples,"key":selected_key,','"samples":samples,"key":selected_key,"seen":seen,')
g=g.replace('Candidate idle substitution only; existing walk retained.','Candidate upright idle and four-phase walk substitution only; ordinary combat remains production Art.')
gddst=H/'ordinary_gait_motion_comparison_v5.gd';assert not gddst.exists();gddst.write_bytes(g.encode('utf-8'))
pysrc=H/'ordinary_idle_motion_comparison_v4.py';p=pysrc.read_text(encoding='utf-8')
for before,after in [('ordinary_idle_comparison_actor_v4','ordinary_gait_comparison_actor_v5'),
                     ('ordinary_idle_motion_comparison_v4','ordinary_gait_motion_comparison_v5'),
                     ('ordinary_idle_motion_result','ordinary_gait_motion_result'),
                     ('ordinary_idle_comparison.json','ordinary_gait_comparison.json'),
                     ('ordinary_idle_motion_','ordinary_gait_motion_'),
                     ('ORDINARY_IDLE_QA','ORDINARY_GAIT_QA'),
                     ('_traits_v4.json','_gait_v5.json'),
                     ('Candidate idle/existing-walk','Candidate idle/four-phase walk')]:p=p.replace(before,after)
p=p.replace("len(m['resources'])==4 and len(m['sources'])==1","len(m['resources'])==8 and len(m['sources'])==17")
p=p.replace("for s in m['sources'].values():assert sha(ROOT/s['path'])==s['sha256']==sha(old/s['path'])",'''candidate_paths=set(m['resources'])
    for s in m['sources'].values():
        assert sha(ROOT/s['path'])==s['sha256'] and s['import_dimensions_verified']
        candidate_paths.update([s['path'],s['path']+'.import'])
    candidate_inputs=[{'path':name,'sha256':sha(ROOT/name)} for name in sorted(candidate_paths)]
    bootstrap=read(args.work_root/'texture_bootstrap_wu_song_gait_v5_run.json')
    bootstrap_project=Path(bootstrap['run'])/'project'
    assert read(Path(bootstrap['run'])/'receipt.json')['complete']''')
p=p.replace("'inputs':inputs,'harnesses':[]", "'inputs':inputs,'candidate_inputs':candidate_inputs,'harnesses':[]")
p=p.replace("shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)",'''shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)
        for row in candidate_inputs:
            dst=project/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],dst)
        for src in (bootstrap_project/'.godot/imported').iterdir():
            if src.is_file():
                dst=project/'.godot/imported'/src.name
                if dst.exists():assert sha(dst)==sha(src),str(dst)
                else:shutil.copy2(src,dst)''')
p=p.replace("len(result['checks'])==80", "len(result['checks'])==96")
p=p.replace("receipt.update(complete=True,input_sha_drift=0", "assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/r['path']) for r in candidate_inputs)\n        receipt.update(complete=True,input_sha_drift=0,candidate_input_drift=0")
p=p.replace("no production route, Battle/collision/combat/UI/save/continuous-playback/performance/platform qualification.","no production route, Battle/collision/combat/UI/save/continuous-playback/performance/platform qualification; authored idle/four-phase walk substituted only.")
pydst=H/'ordinary_gait_motion_comparison_v5.py';assert not pydst.exists();compile(p,str(pydst),'exec');pydst.write_bytes(p.encode('utf-8'))
dest=ROOT/'qa/zhu_wounded_20261005/wu_gait_motion_producer_parents_v5.json';assert not dest.exists()
dest.write_bytes((json.dumps({'parents':[{'path':s.relative_to(ROOT).as_posix(),'sha256':sha(s)} for s in [gdsrc,pysrc]],
    'derived':[{'path':s.relative_to(ROOT).as_posix(),'sha256':sha(s)} for s in [gddst,pydst]],'prior_producers_unchanged':True},indent=2)+'\n').encode('utf-8'))
print(json.dumps({'new_motion_harnesses':2,'expected_checks':96,'production_qualified':False}))
