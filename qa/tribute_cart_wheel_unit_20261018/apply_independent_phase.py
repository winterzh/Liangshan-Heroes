from pathlib import Path
import hashlib,json,shutil,subprocess
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent
previous=E/'game_iteration1/20261018_122624_db897455/evidence/receipt.json'
d=json.loads(previous.read_text());assert d['complete'] and d['lock_released']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
frozen={x['path']:x['sha256'] for x in d['source_files']}
files=['scripts/unit.gd','scripts/tribute_cart_wheel_visual.gd','scripts/run_unit_state.gd','tools/ruan_xiaoqi_layered_20261018.gd','tools/run_ruan_xiaoqi_layered_20261018.py','assets/characters/tribute_cart_wheel_runtime_20261018/manifest.json']
B=E/'shared_phase_before_v3';assert not B.exists();B.mkdir()
for rel in files:
    assert sha(R/rel)==frozen[rel],rel
    p=B/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/rel,p)
def change(rel,old,new):
    p=R/rel;b=p.read_bytes();nl=b'\r\n' if b'\r\n' in b else b'\n'
    old=old.replace('\n',nl.decode()).encode();new=new.replace('\n',nl.decode()).encode()
    assert b.count(old)==1,(rel,old[:80],b.count(old));p.write_bytes(b.replace(old,new))
unit='scripts/unit.gd';helper='scripts/tribute_cart_wheel_visual.gd';qa='tools/ruan_xiaoqi_layered_20261018.gd';codec='scripts/run_unit_state.gd'
base=subprocess.check_output(['git','show','1a3789374e2aab566332c6b45b401b13fb39655d:scripts/unit.gd'],cwd=R)
assert hashlib.sha256(base).hexdigest()=='640df48e4b8d8a79e0dd07ac9959761af507bb6aaf048e51a3ceffddeec14a03'
# Restore only the gait/dust block to its exact retained production bytes.
change(unit,'\t\tif tribute_roll:\n\t\t\t_anim_t += TributeCartWheel.phase_delta(self, position - tribute_motion_origin, radius * 3.7 * visual_scale)\n\t\telse:\n\t\t\t_anim_t += delta * (13.0 if is_cavalry else 9.5) * MOVE_SCALE * (base_speed / 72.0)','\t\t_anim_t += delta * (13.0 if is_cavalry else 9.5) * MOVE_SCALE * (base_speed / 72.0)')
change(unit,'var _anim_t := 0.0','var _tribute_wheel_angle := 0.0 # Transient visual phase; reset on restore, never a gameplay/save value.\nvar _anim_t := 0.0')
change(unit,'\t_move_blend = move_toward(_move_blend, 1.0 if _stepped else 0.0, delta * 6.0)','\tif tribute_roll:\n\t\t_tribute_wheel_angle = fposmod(_tribute_wheel_angle + TributeCartWheel.phase_delta(self, position - tribute_motion_origin, radius * 3.7 * visual_scale), TAU)\n\t_move_blend = move_toward(_move_blend, 1.0 if _stepped else 0.0, delta * 6.0)')
change(helper,'const GAIT_PER_WHEEL := 0.9\n','')
change(helper,'\t# _anim_t already means gait phase and is explicitly saved/restored by the\n\t# existing codec. This opt-in phase now follows traveled distance; no hidden\n\t# per-unit wheel state, metadata or save payload is added.\n\treturn distance/radius*GAIT_PER_WHEEL','\t# Only a transient visual angle advances. Original gait, dust and their RNG\n\t# cadence remain unchanged. Save restore rebuilds this cache at angle zero.\n\treturn distance/radius')
change(helper,'fposmod(float(unit._anim_t)/GAIT_PER_WHEEL*float(row.phase_sign),TAU)','fposmod(float(unit._tribute_wheel_angle)*float(row.phase_sign),TAU)')
change(codec,'## Five draw caches are regenerated; draw cadence is not gameplay state.','## Six visual caches are regenerated; wheel angle is not gameplay/save state.')
change(codec,'const OMITTED_VISUAL_FIELDS := ["_animated_redraw_t",','const OMITTED_VISUAL_FIELDS := ["_tribute_wheel_angle", "_animated_redraw_t",')
change(codec,'\tunit._anim_t = values["_anim_t"]','\tunit._anim_t = values["_anim_t"]\n\tunit._tribute_wheel_angle = 0.0 # Same rebuild policy as other omitted visual caches.')
change(qa,'\tvar captured:=false','\tvar captured:=false\n\tvar wheel_last_angle:=0.0\n\tvar wheel_angular_distance:=0.0')
change(qa,'\t\tvar art=get_tree().root.get_node("Art")','\t\twheel_angular_distance+=fposmod(float(actor._tribute_wheel_angle)-wheel_last_angle,TAU);wheel_last_angle=actor._tribute_wheel_angle\n\t\tvar art=get_tree().root.get_node("Art")')
change(qa,'var probe:=WalkProbe.new();probe.actor=u;','var probe:=WalkProbe.new();probe.actor=u;probe.wheel_last_angle=u._tribute_wheel_angle;')
change(qa,'check(u._anim_t>wheel_phase_start,"actual displacement advances wheel/gait phase "+String(row.d))','check(u._anim_t>wheel_phase_start and probe.wheel_angular_distance>0.0,"actual displacement advances wheel/gait phase "+String(row.d))')
change(qa,'"phase_delta":u._anim_t-wheel_phase_start,"distance":u.position.distance_to(origin)','"gait_phase_delta":u._anim_t-wheel_phase_start,"independent_wheel_angle_traveled":probe.wheel_angular_distance,"distance":u.position.distance_to(origin)')
change(qa,'var stopped_phase: float=u._anim_t;','var stopped_phase: float=u._tribute_wheel_angle;var residual_gait_phase: float=u._anim_t;')
change(qa,'is_equal_approx(u._anim_t,stopped_phase)','is_equal_approx(u._tribute_wheel_angle,stopped_phase)')
change(qa,'\t\tawait snap("wheel_actual_stopped_"+String(row.d))','\t\tcheck(u._anim_t>residual_gait_phase,"original residual gait clock continues independently of stopped wheel "+String(row.d))\n\t\tawait snap("wheel_actual_stopped_"+String(row.d))')
change(qa,'var before_hurt_phase: float=u._anim_t','var before_hurt_phase: float=u._tribute_wheel_angle')
change(qa,'is_equal_approx(u._anim_t,before_hurt_phase)','is_equal_approx(u._tribute_wheel_angle,before_hurt_phase)')
change(qa,'["_anim_t","_idle_t","_move_blend","animation_direction"','["_tribute_wheel_angle","_anim_t","_idle_t","_move_blend","animation_direction"')
change(qa,'u._anim_t=.1;u.queue_redraw()','u._anim_t=.1;u._tribute_wheel_angle=.1;u.queue_redraw()')
change(qa,'u._anim_t=.8;u.queue_redraw()','u._tribute_wheel_angle=.8;u.queue_redraw()')
change(qa,'\tfor actor in b.units:\n\t\tif actor!=u:check(not wheel.enabled(actor),','''	var codec=load("res://scripts/run_unit_state.gd").new(null,null,null)
	var raw: Dictionary=codec._read_explicit(u)
	check(codec.OMITTED_VISUAL_FIELDS.has("_tribute_wheel_angle") and not raw.has("_tribute_wheel_angle"),"independent wheel is explicitly classified outside saved unit values")
	var gait_before: float=u._anim_t;u._tribute_wheel_angle=1.27;codec._assign_values(u,raw)
	check(u._tribute_wheel_angle==0.0 and u._anim_t==gait_before,"explicit unit assignment rebuilds visual wheel at zero and preserves saved gait")
	for actor in b.units:
		if actor!=u:check(not wheel.enabled(actor),''')
# Keep importer UID equal to the real successful private candidate descriptor.
uid=Path(d['project'])/'scripts/tribute_cart_wheel_visual.gd.uid'
uid_row=next(x for x in d['generated_identity']['identity']['files'] if x['path']=='scripts/tribute_cart_wheel_visual.gd.uid')
assert sha(uid)==uid_row['sha256'];before_uid=(R/'scripts/tribute_cart_wheel_visual.gd.uid').read_bytes();shutil.copyfile(uid,R/'scripts/tribute_cart_wheel_visual.gd.uid')
manifest_path=R/'assets/characters/tribute_cart_wheel_runtime_20261018/manifest.json'
m=json.loads(manifest_path.read_text());m['scope']='Source provenance for exact Ruan Xiaoqi chapter16 separated cart; actual adoption is determined by Unit and Wheel.enabled, and actual native QA.'
m.pop('gait_per_wheel',None);m.pop('runtime_adopted',None)
m['phase']='Independent transient _tribute_wheel_angle follows actual terrain-lifted displacement / rendered outer rim radius; no camera clock. Original gait/dust code remains exact. Explicit omitted visual cache resets to0 on restore; no persistent payload change.'
m['limitations']=['Other6 cart carriers still need body separation and rolling wheel acceptance.','Wheel angle rebuilds at0 on loading a saved game; logical cargo and original saved gait retain their existing schema.','Fixed rim grain/light, fit/physical radius, drop/delivery visual angle continuity and cloth inertia remain provisional.','Existing three cargo goals, seven-cart/eleven-load migration and whole-art acceptance remain open.']
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
out={'base_commit':'1a3789374e2aab566332c6b45b401b13fb39655d','previous_actual_receipt':str(previous),'previous_actual_checks':1680,'previous_actual_screenshots':144,'previous_candidate_quality_rejected':'Shared wheel/gait phase changes original per-direction gait distance and cosmetic dust RNG cadence. Superseded although narrow1680 checks passed.','new_visual_fields':['_tribute_wheel_angle'],'persistent_fields_added':0,'saved_wire_schema_changed':False,'restore_policy':'Explicitly omitted visual cache reset to0; no wheel-angle continuity claim across save/load.','before_uid_sha256':hashlib.sha256(before_uid).hexdigest(),'canonical_uid_sha256':sha(uid),'files':[{'path':f,'sha256':sha(R/f)} for f in files+['scripts/tribute_cart_wheel_visual.gd.uid']]}
(E/'independent_phase_candidate.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Independent wheel angle applied; original gait/dust block restored exactly; visual cache classified and reset explicitly.')
