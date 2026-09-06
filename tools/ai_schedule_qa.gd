extends "res://tools/campaign_mode_performance_test.gd"

var probe_script: GDScript
var decisions_compared := 0

func _probe(b):
	var p=probe_script.new()
	p.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.map=b.map;p.hud=b.hud;p._defs=b._defs;p._abilities=b._abilities
	p.fog=false;p.economy=false;p.ai_friendly=false
	p.units_root=Node2D.new();p.add_child(p.units_root)
	return p

func _hero(p, serial: int):
	var u=p.spawn_unit("song_jiang",0,Vector2(700,700))
	u.set_meta("qa_serial",serial);u.auto_micro=true;u.skill_points=0
	return u

func _trace(p, steps: int, weak := false) -> Array:
	root.get_node("Settings").auto_micro_level=1 if weak else 2
	p.brain_calls.clear()
	for frame in range(1,steps+1):
		p._ai_tick_frame=frame;p._auto_micro_pass()
	return p.brain_calls.duplicate(true)

func _decoration_case(b, count: int, weak: bool) -> Array:
	var p=_probe(b)
	var building_key: String=b.units.filter(func(u):return u.is_building)[0].key
	var resource_key: String=b.units.filter(func(u):return u.is_resource)[0].key
	for i in range(32):
		for _j in range(count): p.add_child(Node.new())
		if count>0:
			p.spawn_unit(building_key,0,Vector2(700,700))
			p.spawn_unit(resource_key,0,Vector2(700,700))
		var u=_hero(p,i)
		check(u.ai_tick_phase==p.AI_TICK_PHASES[i%16],"mobile spawn phase "+str(i)+" decoration="+str(count)+" weak="+str(weak))
	var phases:=[]
	for u in p.units:
		if u.is_hero: phases.append(u.ai_tick_phase)
	check(phases.slice(0,16).duplicate().size()==16 and p._ai_spawn_serial==32,"buildings/resources do not consume mobile phases")
	var trace:=_trace(p,64,weak)
	var hits:={}
	for row in trace:
		var serial: int=row[1]
		if not hits.has(serial): hits[serial]=[]
		hits[serial].append(row[0])
	var exact:=hits.size()==32
	for frames in hits.values():
		exact=exact and frames.size()==4
		for j in range(1,frames.size()): exact=exact and frames[j]-frames[j-1]==16
	check(exact,"all 32 heroes decide exactly every 16 battle ticks")
	var occupancy:={}
	for row in trace:occupancy[row[0]]=int(occupancy.get(row[0],0))+1
	check(occupancy.size()==64 and occupancy.values().all(func(n):return n==2),"32 heroes evenly occupy all 16 phases")
	var retained=p.units.filter(func(u):return u.is_hero)[5]
	var retained_phase: int=retained.ai_tick_phase
	var removed=p.units.filter(func(u):return u.is_hero)[0]
	p.units.erase(removed);removed.free()
	var replacement=_hero(p,32)
	check(retained.ai_tick_phase==retained_phase and replacement.ai_tick_phase==p.AI_TICK_PHASES[0] and p._ai_spawn_serial==33,"death/spawn does not renumber survivors")
	p.queue_free();await process_frame;await process_frame
	return trace

func _guard_cases(b) -> void:
	var p=_probe(b);var u=_hero(p,0)
	var slots: Array=u.ability_slots.duplicate(true)
	for entry in [
		{"name":"eligible","expected":4},
		{"name":"manual order","manual_order_active":true,"expected":0},
		{"name":"manual grace","manual_order_t":2.0,"expected":0},
		{"name":"casting","_cast_t":1.0,"expected":0},
		{"name":"dead","hp":0.0,"expected":0},
		{"name":"enemy hero","faction":1,"expected":0},
		{"name":"not hero","is_hero":false,"expected":0},
		{"name":"building","is_building":true,"expected":0},
		{"name":"disabled","auto_micro":false,"expected":0},
		{"name":"no slots","ability_slots":[],"expected":0}]:
		u.manual_order_active=false;u.manual_order_t=0;u._cast_t=0;u.hp=100;u.faction=0
		u.is_hero=true;u.is_building=false;u.auto_micro=true;u.ability_slots=slots.duplicate(true)
		for key in entry:
			if key not in ["name","expected"]:u.set(key,entry[key])
		check(_trace(p,64).size()==entry.expected,"hero guard retained: "+entry.name)
	u.ability_slots=slots;u.auto_micro=true
	root.get_node("Settings").auto_micro_level=0;p.brain_calls.clear();p._auto_micro_pass()
	check(not u.auto_micro and p.brain_calls.is_empty(),"global off cancels hero micro")
	p.ai_friendly=true;root.get_node("Settings").auto_micro_level=3
	p._ai_tick_frame=u.ai_tick_phase;p._auto_micro_pass()
	check(u.auto_micro and p.brain_calls.size()==1,"full auto enables eligible hero at assigned phase")
	p.ai_friendly=false
	var summon=p.spawn_unit("liang_dao",0,Vector2(720,720));summon.is_summon=true
	summon._state=0
	p.seek_calls.clear()
	for frame in range(1,65):p._ai_tick_frame=frame;p._summon_hunt_pass()
	check(p.seek_calls.size()==4 and p.seek_calls[1]-p.seek_calls[0]==16,"summon hunting uses same stable cadence")
	for entry in [{"name":"moving","_state":1},{"name":"dead","hp":0.0},{"name":"ordinary soldier","is_summon":false}]:
		summon._state=0;summon.hp=100;summon.is_summon=true
		for key in entry:
			if key!="name":summon.set(key,entry[key])
		p.seek_calls.clear()
		for frame in range(1,33):p._ai_tick_frame=frame;p._summon_hunt_pass()
		check(p.seek_calls.is_empty(),"summon guard retained: "+entry.name)
	p.queue_free();await process_frame;await process_frame

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/ai_schedule_qa")
	DirAccess.make_dir_recursive_absolute(output)
	var saved:=_save_hash()
	probe_script=GDScript.new()
	probe_script.source_code='extends "res://scripts/battle.gd"\nvar brain_calls := []\nvar seek_calls := []\nfunc _ready() -> void: pass\nfunc _auto_micro_hero(u: Unit) -> void:\n\tbrain_calls.append([_ai_tick_frame,int(u.get_meta("qa_serial")),"strong"])\nfunc _auto_micro_weak(u: Unit) -> void:\n\tbrain_calls.append([_ai_tick_frame,int(u.get_meta("qa_serial")),"weak"])\nfunc _nearest_foe_pos(_from: Vector2, _fac: int) -> Vector2:\n\tseek_calls.append(_ai_tick_frame)\n\treturn Vector2.INF\n'
	check(probe_script.reload()==OK,"production dispatch probe compiles after autoload startup")
	if not failures.is_empty():quit(2);return
	var b=await _start("level5");b.process_mode=Node.PROCESS_MODE_DISABLED
	var phases: Array=b.AI_TICK_PHASES.duplicate();phases.sort()
	check(phases==range(16) and b.AI_TICK==16,"phase order is a permutation of the unchanged 16-tick period")
	report["decision_traces"]=[]
	for weak in [false,true]:
		var baseline: Array=await _decoration_case(b,0,weak)
		var perturbed: Array=await _decoration_case(b,13,weak)
		check(baseline==perturbed,"complete decision trace independent of decoration and static-unit allocations; weak="+str(weak))
		report.decision_traces.append({"weak":weak,"baseline":baseline,"perturbed":perturbed})
		decisions_compared+=baseline.size()
	await _guard_cases(b)
	root.get_node("Settings").auto_micro_level=0
	b.phase=b.Phase.INTRO;var tick: int=b._ai_tick_frame;b._physics_process(0.0)
	check(b._ai_tick_frame==tick,"intro does not advance combat decision clock")
	b.phase=b.Phase.DEPLOY;b._physics_process(0.0)
	check(b._ai_tick_frame==tick+1,"one battle physics callback advances exactly one decision tick")
	tick=b._ai_tick_frame
	for _i in range(20):await process_frame
	check(b._ai_tick_frame==tick,"rendered/global frames cannot advance a disabled battle clock")
	b.process_mode=Node.PROCESS_MODE_INHERIT;paused=true
	var global_before:=Engine.get_physics_frames()
	await create_timer(0.07,true).timeout
	check(b._ai_tick_frame==tick and Engine.get_physics_frames()>global_before,"pause preserves battle cadence while global physics frames advance")
	report["pause_clock"]={"battle_before":tick,"battle_after":b._ai_tick_frame,"global_before":global_before,"global_after":Engine.get_physics_frames()}
	b.process_mode=Node.PROCESS_MODE_DISABLED;paused=false
	check(b.mission!=null,"real campaign section supports cleanup")
	if b.mission!=null:
		b.clear_campaign_section()
		check(b._ai_spawn_serial==0 and b._ai_tick_frame==0,"campaign section cleanup resets scheduling state")
		var fresh=b.spawn_unit("song_jiang",0,Vector2(700,700))
		check(fresh.ai_tick_phase==b.AI_TICK_PHASES[0] and b._ai_spawn_serial==1,"next section begins with fresh phase allocation")
	await _dispose(b,true)
	check(_save_hash()==saved,"player campaign save bytes unchanged")
	report["passed"]=failures.is_empty();report["failures"]=failures
	report["decisions_compared"]=decisions_compared
	report["scope"]="Real production spawn and hero/summon dispatch, with brain outputs intercepted to verify exact cadence/eligibility independent of object allocation. Not a balance or whole-battle determinism claim. Real campaign clock/section cleanup and save checks."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[ai-schedule-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"decisions_compared":decisions_compared,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
