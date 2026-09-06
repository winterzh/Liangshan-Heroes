extends "res://tools/campaign_mode_performance_test.gd"
const REFERENCE := "res://tools/contracts/chase_speed/before_69125b3.txt"
const REFERENCE_SHA := "7d14a3dfd6a61519d77c3cb9b6ae8a834466288555efae4ed225e92e2437dc0b"
var reference_source := ""
var comparisons := 0
var old_speed_calls := 0
var new_speed_calls := 0

func _script(spy: bool) -> GDScript:
	var script:=GDScript.new()
	script.source_code='extends "res://scripts/unit.gd"\n'+reference_source.replace("func _do_chase(","func _qa_reference_chase(")
	if spy:
		script.source_code+='''
var qa_actions := []
var qa_speed_calls := 0
var qa_speed_override: Variant = null
var qa_locked := false
func current_move_speed(at := Vector2.INF) -> float:
	qa_speed_calls+=1
	return super(at) if qa_speed_override==null else float(qa_speed_override)
func has_hua_locked_attack(_t: Unit) -> bool: return qa_locked
func _attack() -> void: qa_actions.append(["attack"])
func _acquire(range_override := -1.0, closest_first := false) -> void: qa_actions.append(["acquire",range_override,closest_first])
func _done_order() -> void: qa_actions.append(["done"])
func _begin_move(pos: Vector2) -> void: qa_actions.append(["move",pos])
func _begin_amove(pos: Vector2) -> void: qa_actions.append(["amove",pos])
func _begin_gather(node: Unit) -> void: qa_actions.append(["gather",node.get_instance_id()])
func _face_dir(d: Vector2, force := false) -> void: qa_actions.append(["face",d,force])
func _follow_path(delta: float) -> bool:
	qa_actions.append(["follow",delta])
	return false
'''
	check(script.reload()==OK,"frozen complete chase method compiles with spy="+str(spy))
	return script

func _unit(b, script: GDScript, faction: int):
	var u=script.new();b.units_root.add_child(u)
	u.setup("liang_dao",b._defs.liang_dao,faction,b,b.map)
	u.position=b.map.cell_to_world(b.map.nearest_open(Vector2i(10,10)))
	return u

func _capture(u) -> Dictionary:
	var result:={}
	for prop in u.get_property_list():
		if int(prop.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and not prop.name.begins_with("qa_"):
			var v: Variant=u.get(prop.name)
			result[prop.name]=v.duplicate(true) if v is Array or v is Dictionary else v
	for name in ["position","rotation","scale","visible","modulate","z_index"]:result[name]=u.get(name)
	return result

func _restore(u, state: Dictionary) -> void:
	for name in state:
		var v: Variant=state[name]
		u.set(name,v.duplicate(true) if v is Array or v is Dictionary else v)

func _delta64(value: float, increment: int) -> float:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	bytes.encode_u64(0,bytes.decode_u64(0)+increment)
	return bytes.decode_double(0)

func _prepare(u, target, time: float, intent: int, blocker: bool, empty: bool) -> void:
	u._target=target;u._chase_last_id=target.get_instance_id();u._chase_best_distance=u.position.distance_to(target.position)
	u._chase_t=time;u._chase_intent=intent;u._chasing_path_blocker=blocker
	u._has_home=false;u._resume_amove=false;u._repath=4.0;u._path_i=0
	u._path=PackedVector2Array() if empty else PackedVector2Array([target.position])
	u.stance=u.STANCE_AGGRO;u.passive=false;u.is_worker=false;u._cd=0.0
	u._giveup_id=0;u._giveup_t=0;u._state=u.ST_CHASE

func _spy_pair(u, target, delta: float) -> bool:
	var start:=_capture(u)
	u.qa_actions.clear();u.qa_speed_calls=0;target.qa_speed_calls=0
	u._qa_reference_chase(delta)
	var expected:=var_to_bytes([_capture(u),u.qa_actions])
	old_speed_calls+=u.qa_speed_calls+target.qa_speed_calls
	_restore(u,start);u.qa_actions.clear();u.qa_speed_calls=0;target.qa_speed_calls=0
	u._do_chase(delta)
	new_speed_calls+=u.qa_speed_calls+target.qa_speed_calls
	comparisons+=1
	return var_to_bytes([_capture(u),u.qa_actions])==expected

func _dispatch_cases(b, script: GDScript) -> void:
	var u=_unit(b,script,0);var target=_unit(b,script,1)
	u.position=Vector2(400,400);target.position=Vector2(700,400)
	var times: Array=[-1.0,0.0,0.8,3.5,INF,NAN]
	for value in [u.CHASE_GIVEUP_FAST,u.CHASE_GIVEUP,3.5]:
		for offset in [-1,0,1]:times.append(_delta64(value,offset))
	var speeds: Array=[0.0,40.0,_delta64(41.0,-1),41.0,_delta64(41.0,1),100.0,INF,NAN]
	for intent in [u.CHASE_AUTO,u.CHASE_AMOVE,u.CHASE_EXPLICIT,u.CHASE_FORCED]:
		for blocker in [false,true]:
			var exact:=true
			for empty in [false,true]:
				for time in times:
					for delta in [0.0,1.0/60.0,0.2]:
						for speed in speeds:
							_prepare(u,target,time,intent,blocker,empty)
							u.qa_speed_override=40.0;target.qa_speed_override=speed
							exact=_spy_pair(u,target,delta) and exact
			check(exact,"all time/speed IEEE64 boundaries and paths agree intent="+str(intent)+" blocker="+str(blocker))
	u.qa_speed_override=null;target.qa_speed_override=null
	var map=b.map
	for profile in ["land","water","unsupported"]:
		for faction in [0,1]:
			var exact:=true
			for cell in [Vector2i(1,1),Vector2i(8,12),Vector2i(16,16)]:
				u.position=map.cell_to_world(cell);target.position=u.position+Vector2(320,0)
				u.movement_profile=profile;target.movement_profile=profile;u.faction=faction
				for boost in [0.4,1.0,1.8]:
					u.temp_speed=boost;target.aura_slow=boost
					_prepare(u,target,1.5,u.CHASE_AUTO,false,false)
					exact=_spy_pair(u,target,1.0/60.0) and exact
			check(exact,"actual terrain/faction/profile and buffs agree "+profile+" faction="+str(faction))
	u.position=Vector2(400,400);target.position=Vector2(700,400)
	u.movement_profile="land";target.movement_profile="land";u.faction=0
	for scenario in ["progress","new_target","explicit_missing","auto_missing","amove_missing","hold","leash","hero_leash_exempt","hua_locked","in_range","passive","worker","resume_amove","forced","path_blocker"]:
		_prepare(u,target,4.0,u.CHASE_AUTO,false,false);u.qa_locked=false;u.auto_micro=false
		match scenario:
			"progress":u._chase_best_distance=400.0
			"new_target":u._chase_last_id=0
			"explicit_missing":u._target=null;u._chase_intent=u.CHASE_EXPLICIT
			"auto_missing":u._target=null
			"amove_missing":u._target=null;u._resume_amove=true;u._amove_dest=Vector2(950,500)
			"hold":u.stance=u.STANCE_HOLD
			"leash":u._has_home=true;u._home=Vector2.ZERO
			"hero_leash_exempt":u._has_home=true;u._home=Vector2.ZERO;u.auto_micro=true
			"hua_locked":u.qa_locked=true
			"in_range":u.atk_range=350
			"passive":u.passive=true
			"worker":u.is_worker=true
			"resume_amove":u._resume_amove=true;u._amove_dest=Vector2(950,500)
			"forced":u._chase_intent=u.CHASE_FORCED
			"path_blocker":u._chasing_path_blocker=true
		check(_spy_pair(u,target,1.0/60.0),"complete branch action sequence agrees: "+scenario)
		u.atk_range=25
	check(new_speed_calls<old_speed_calls,"unnecessary speed/terrain reads are actually removed")
	report["dispatch"]={"comparisons":comparisons,"reference_speed_reads":old_speed_calls,"optimized_speed_reads":new_speed_calls,"scope":"Full frozen method on the same Unit; action endpoints intercepted to compare state and dispatch. Exact speed override for IEEE boundaries, real terrain/speed functions in separate fixtures."}
	u.free();target.free()

func _actual_cases(b, script: GDScript) -> void:
	var u=_unit(b,script,0);var target=_unit(b,script,1);var alternate=_unit(b,script,1)
	var ordinary: Array=b.units.duplicate();b.units.assign([u,target,alternate]);b.fog=false
	var exact:=true;var steps:=0;var targets_unchanged:=true
	for intent in [u.CHASE_AUTO,u.CHASE_AMOVE,u.CHASE_EXPLICIT,u.CHASE_FORCED]:
		u.position=b.map.cell_to_world(b.map.nearest_open(Vector2i(12,12)))
		target.position=b.map.cell_to_world(b.map.nearest_open(Vector2i(20,16)))
		alternate.position=u.position+Vector2(180,60)
		_prepare(u,target,0.0,intent,false,false);u._repath=0
		for frame in range(180):
			if u._state!=u.ST_CHASE or u._target==null:_prepare(u,target,0.0,intent,false,false)
			if frame%30==0:target.temp_speed=0.4 if frame%60==0 else 1.8
			if frame%45==0:target.position+=Vector2(64,32)
			b._grid_build()
			# This fixture compares pursuit, path and acquisition, without allowing
			# the reference run to damage a target before the production run starts.
			u._cd=1000.0
			var target_hp: Array=[target.hp,alternate.hp]
			var start:=_capture(u)
			u._qa_reference_chase(1.0/60.0)
			var expected:=var_to_bytes(_capture(u))
			_restore(u,start);u._do_chase(1.0/60.0)
			exact=var_to_bytes(_capture(u))==expected and exact;steps+=1
			targets_unchanged=targets_unchanged and target_hp==[target.hp,alternate.hp]
		check(exact,"real movement/path/reacquisition state replay intent="+str(intent))
	check(steps==720,"720 actual Unit chase steps compared without action stubs")
	check(targets_unchanged,"actual replay never changes shared target health between paired runs")
	report["actual_replay"]={"steps":steps,"exact":exact,"targets_unchanged":targets_unchanged,"scope":"Same actual Unit and real movement/path/reacquisition methods, restored to identical per-step state. Attack cooldown held to avoid mutating shared targets; target movement/buff changes controlled. Not damage or campaign completion evidence."}
	var origin: Vector2=b.map.cell_to_world(b.map.nearest_open(Vector2i(12,12)))
	for label in ["early_auto","explicit","window_slow"]:
		var samples:=[];var before:=[];var after:=[]
		u.position=origin;target.position=origin+Vector2(400,0);target.base_speed=20
		b._grid_build()
		for warm in range(2):_timed_actual(u,target,false,label,origin);_timed_actual(u,target,true,label,origin)
		for old_first in [true,false,true]:
			for reference in ([true,false] if old_first else [false,true]):
				var us:=_timed_actual(u,target,reference,label,origin)
				(before if reference else after).append(us);samples.append({"reference":reference,"microseconds":us,"calls":6000})
		check(u.position!=origin and b.map.is_open_world(u.position),"timed full method includes actual legal movement: "+label)
		before.sort();after.sort();report.samples.append({"label":label,"median_before_us":before[1],"median_after_us":after[1],"after_over_before":float(after[1])/before[1],"windows":samples})
	b.units.assign(ordinary);u.free();target.free();alternate.free()

func _timed_actual(u, target, reference: bool, label: String, origin: Vector2) -> int:
	var elapsed:=0
	for i in range(6000):
		u.position=origin;_prepare(u,target,1.5 if label=="window_slow" else 0.3,u.CHASE_EXPLICIT if label=="explicit" else u.CHASE_AUTO,false,false)
		var started:=Time.get_ticks_usec()
		if reference:u._qa_reference_chase(1.0/60.0)
		else:u._do_chase(1.0/60.0)
		elapsed+=Time.get_ticks_usec()-started
	return elapsed

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/chase_speed_qa");DirAccess.make_dir_recursive_absolute(output)
	var saved:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen complete 69125b3 chase function hash matches")
	reference_source=FileAccess.get_file_as_string(REFERENCE)
	var b=await _start("level1");b.process_mode=Node.PROCESS_MODE_DISABLED
	var spy:=_script(true);var actual:=_script(false)
	if not failures.is_empty():quit(2);return
	await _dispatch_cases(b,spy)
	_actual_cases(b,actual)
	await _dispose(b,true)
	check(_save_hash()==saved,"player campaign save bytes unchanged")
	report["passed"]=failures.is_empty();report["failures"]=failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[chase-speed-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"dispatch_comparisons":comparisons,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
