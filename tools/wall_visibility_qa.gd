extends "res://tools/campaign_mode_performance_test.gd"

const REFERENCE := "res://tools/contracts/wall_visibility/before_2ea8c69.txt"
const REFERENCE_SHA := "96c5d1c144c21bc65f3c9005956a425d24248bc9ebbebb3d0c23853f9b728193"
var Entrance: GDScript
var Wall: GDScript
var Gate: GDScript
var part_comparisons := 0

class ProbeUnit extends Node2D:
	var hp := 100.0
	var is_building := false
	var story_outcome := ""
	var garrisoned_in = null

class ProbeBattle extends Node:
	var units := []

func _parts(s) -> Array:
	return s._wall_parts+s._gate_parts+s._side_gate_parts

func _state(s) -> Array:
	var result := []
	for p in _parts(s):
		result.append([p.modulate,p.sealed if p.get_script()==Gate else null])
	return result

func _restore(s, values: Array) -> void:
	var parts:=_parts(s)
	for i in range(parts.size()):
		parts[i].modulate=values[i][0]
		if parts[i].get_script()==Gate: parts[i].sealed=values[i][1]

func _bind(s, old) -> void:
	for key in ["_map","_wall_parts","_gate_parts","_side_gate_parts","_rts_layout","_gate_cell","_east_gate_cell"]:
		old.set(key,s.get(key))

func _compare(s, old, label: String, delta := 0.1) -> void:
	_bind(s,old)
	var original:=_state(s)
	var tick: float=s._tick
	old._tick=tick;old._process(delta)
	var expected:=_state(s)
	_restore(s,original)
	s._process(delta)
	check(_state(s)==expected and s._tick==old._tick,label+" exact wall/gate RGBA, seal and cadence")
	part_comparisons+=expected.size()

func _timed(s, calls: int) -> int:
	var started:=Time.get_ticks_usec()
	for i in range(calls): s._process(0.1)
	return Time.get_ticks_usec()-started

func _start_entrance(defense: bool):
	var c=root.get_node("Campaign")
	c.current=c.index_for_id("level5")
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(key,false)
	c.skirmish=defense
	seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b);current_scene=b
	await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle()
	return b

func _benchmark(s, old, label: String) -> void:
	_compare(s,old,label)
	_timed(s,5);_timed(old,5)
	var windows:=[];var before:=[];var after:=[]
	for old_first in [true,false,true]:
		for is_old in ([true,false] if old_first else [false,true]):
			var duration:=_timed(old if is_old else s,40)
			(before if is_old else after).append(duration)
			windows.append({"implementation":"reference" if is_old else "optimized","calls":40,"microseconds":duration})
	before.sort();after.sort()
	var battle=s._map.get_parent().get_parent()
	report.samples.append({"label":label,"units":battle.units.size(),"walls":s._wall_parts.size(),"windows":windows,"median_reference_us":before[1],"median_optimized_us":after[1],"optimized_over_reference":float(after[1])/maxi(1,before[1])})

func _real_occlusion(b, s, old) -> void:
	var shown:=[]
	for unit in b.units: shown.append(unit.visible);unit.hide()
	var wall=s._wall_parts[0]
	var foot: Vector2=b.map.project(wall.position)+wall.end_local*0.5-Vector2(0,wall.height_scale*0.4)
	var u=b.spawn_unit("liang_dao",0,b.map.unproject(foot))
	u.set_physics_process(false);u.fog_visible=true;u.show();u.z_index=wall.z_index
	var original_position: Vector2=u.position
	var original_hp: float=u.hp
	b._grid_build();b.select_single(u,false)
	_compare(s,old,b.level.id()+" real soldier behind wall")
	check(is_equal_approx(wall.modulate.a,0.72),b.level.id()+" real wall keeps authored opacity")
	check(b._friendly_at(b.to_screen(u.position))==u,b.level.id()+" player hit test still selects soldier through wall")
	if DisplayServer.get_name()!="headless":
		b.fog=false;b._fog_layer.hide();b.hud.hide()
		b.map.sync_render_position(u);u.z_index=wall.z_index
		b.camera.zoom=Vector2.ONE*1.5;b.camera.position=b.to_screen(u.position)
		b.camera.force_update_scroll()
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(b.level.id()+"_occluded.png"))==OK,b.level.id()+" rendered occlusion saved")
	u.position+=Vector2(1400,800)
	_compare(s,old,b.level.id()+" soldier leaves wall")
	check(wall.modulate.a==1.0,b.level.id()+" wall opacity restores immediately next tick")
	wall.end_local=-wall.end_local;wall.height_scale+=17.0
	_compare(s,old,b.level.id()+" changed wall geometry reads live")
	wall.end_local=-wall.end_local;wall.height_scale-=17.0
	check(u.position==original_position+Vector2(1400,800) and u.hp==original_hp,b.level.id()+" visibility pass preserves soldier position and HP")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(b.level.id()+"_restored.png"))==OK,b.level.id()+" rendered restoration saved")
	b.units.erase(u);u.free()
	for i in range(shown.size()): b.units[i].visible=shown[i]
	b._grid_build()

func _fixtures(old) -> void:
	var map_script:=GDScript.new()
	map_script.source_code="extends \"res://scripts/game_map.gd\"\nvar projections := 0\nfunc project(p: Vector2) -> Vector2:\n\tprojections+=1\n\treturn super.project(p)\n"
	check(map_script.reload()==OK,"projection-count map compiles")
	var map=map_script.new()
	var b:=ProbeBattle.new();var world:=Node.new();b.add_child(world);world.add_child(map)
	var s=Entrance.new();s._map=map;s._rts_layout=true
	s._gate_cell=Vector2i(-100,-100);s._east_gate_cell=Vector2i(-200,-200)
	for group in [s._gate_parts,s._side_gate_parts]:
		for i in range(3):
			var g=Gate.new();g.lintel=i==2;g.z_index=-200
			g.position=Vector2(-5000-i*100,-5000);g.modulate=Color(0.71,0.83,0.66,0.3)
			group.append(g)
	var wall=Wall.new();wall.position=Vector2(64,32);wall.z_index=20
	wall.modulate=Color(0.73,0.88,0.61,0.3);s._wall_parts.append(wall)
	var u:=ProbeUnit.new();b.units=[u]
	for end in [Vector2(96,48),Vector2(-96,48),Vector2(-96,-48),Vector2(96,-48),Vector2(96,62),Vector2(-96,31),Vector2.ZERO]:
		wall.end_local=end
		var area:=Rect2(Vector2.ZERO,Vector2.ZERO).expand(end)
		area.position.y-=wall.height_scale;area.size.y+=wall.height_scale+12
		var center:=area.get_center()
		for entry in [
			["inside",center,true],
			["left touches",Vector2(area.position.x-12,center.y),false],
			["left enters",Vector2(area.position.x-11.75,center.y),true],
			["right touches",Vector2(area.end.x+12,center.y),false],
			["right enters",Vector2(area.end.x+11.75,center.y),true],
			["top touches",Vector2(center.x,area.position.y-2),false],
			["top enters",Vector2(center.x,area.position.y-1.75),true],
			["bottom touches",Vector2(center.x,area.end.y+38),false],
			["bottom enters",Vector2(center.x,area.end.y+37.75),true],
			["outside",Vector2(500,400),false]]:
			u.position=map.ISO_INV*(map.project(wall.position)+entry[1])
			u.z_index=20
			_compare(s,old,str(end)+" "+entry[0])
			check(is_equal_approx(wall.modulate.a,0.72 if entry[2] else 1.0),str(end)+" "+entry[0]+" expected wall alpha")
	wall.end_local=Vector2(96,48)
	u.position=wall.position+map.ISO_INV*Vector2(20,-20)
	for entry in [
		{"name":"same depth","z":20,"fade":true},
		{"name":"in front","z":21,"fade":false},
		{"name":"negative depth","z":-100,"fade":true},
		{"name":"hidden","shown":false,"fade":false},
		{"name":"dead","hp":0.0,"fade":false},
		{"name":"negative hp","hp":-1.0,"fade":false},
		{"name":"NaN hp","hp":NAN,"fade":false},
		{"name":"building","building":true,"fade":false},
		{"name":"story still visible","story":"retreated","fade":true},
		{"name":"garrison still visible","garrison":wall,"fade":true}]:
		u.z_index=entry.get("z",19);u.hp=entry.get("hp",100.0)
		u.visible=entry.get("shown",true);u.is_building=entry.get("building",false)
		u.story_outcome=entry.get("story","");u.garrisoned_in=entry.get("garrison",null)
		_compare(s,old,entry.name)
		check(is_equal_approx(wall.modulate.a,0.72 if entry.fade else 1.0),entry.name+" expected wall alpha")
	u.hp=100;u.visible=true;u.is_building=false;u.z_index=19
	u.story_outcome="";u.garrisoned_in=null
	b.units.append(u);b.units.append(null)
	var freed:=ProbeUnit.new();b.units.append(freed);freed.free()
	_compare(s,old,"duplicate, null and freed candidates")
	s._wall_parts.append(wall);_compare(s,old,"duplicate wall references");s._wall_parts.pop_back()
	for gate_id in ["main","east",""]:
		u.set_meta("liangshan_gate_id",gate_id)
		_compare(s,old,"gate state "+gate_id)
		var gate_parts: Array=s._gate_parts if gate_id=="main" else s._side_gate_parts
		check(gate_parts.all(func(g): return g.sealed==(not g.lintel and gate_id!="")),"living gate metadata controls leaves "+gate_id)
	u.position=Vector2(s._gate_cell)*map.CELL
	_compare(s,old,"unit enters main gate fade zone")
	check(is_equal_approx(s._gate_parts[0].modulate.a,0.48),"open gate fades to authored alpha")
	u.set_meta("liangshan_gate_id","main")
	_compare(s,old,"sealed main gate fade zone")
	check(is_equal_approx(s._gate_parts[0].modulate.a,0.78),"sealed gate keeps authored alpha")
	s._tick=0.0;_compare(s,old,"sub-tick first",0.04);_compare(s,old,"sub-tick boundary",0.06)
	s._wall_parts.clear();_compare(s,old,"no walls");s._wall_parts.append(wall)
	b.units.clear();_compare(s,old,"no units restores opacity");u.free()
	for i in range(206):
		var unit:=ProbeUnit.new();unit.position=Vector2(1000+i*3,900-i*2);b.units.append(unit)
	for i in range(99):
		var extra=Wall.new();extra.end_local=Vector2(96,48);extra.z_index=20
		extra.position=Vector2(i*2,i);s._wall_parts.append(extra)
	_compare(s,old,"206 units outside 100 walls")
	map.projections=0;old._process(0.1);var old_count: int=map.projections
	map.projections=0;s._process(0.1);var new_count: int=map.projections
	check(old_count==41202 and new_count==308,"complete entrance projections fall from pairs to units plus walls")
	report["projection_counts"]={"reference":old_count,"optimized":new_count}
	_benchmark(s,old,"synthetic_206_outside_100_walls")
	for unit in b.units: unit.free()
	for part in _parts(s): part.free()
	s.free();b.free()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1440,900);DisplayServer.window_set_size(root.size)
		root.get_node("Settings").edge_scroll=false
	# --script initializes autoload names after parsing this driver.
	Entrance=load("res://scripts/liangshan_entrance.gd")
	Wall=load("res://scripts/liangshan_stockade.gd")
	Gate=load("res://scripts/liangshan_gate.gd")
	output=ProjectSettings.globalize_path("res://.godot/wall_visibility_qa")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen entrance source hash matches")
	var old_script:=GDScript.new();old_script.source_code=FileAccess.get_file_as_string(REFERENCE)
	check(old_script.reload()==OK,"frozen production entrance compiles")
	if not failures.is_empty(): quit(2);return
	var old=old_script.new();_fixtures(old)
	for defense in [false,true]:
		var b=await _start_entrance(defense)
		b.process_mode=Node.PROCESS_MODE_DISABLED
		var s=b.map.sample_scenery._entrance
		check(s!=null,"real entrance exists "+b.level.id())
		if s!=null:
			_benchmark(s,old,b.level.id()+"_authored")
			b._perf_bench_setup(200);b._prof_on=false
			await process_frame
			_benchmark(s,old,b.level.id()+"_200_enemy_bench")
			for unit in b.units: unit.visible=true
			_benchmark(s,old,b.level.id()+"_all_units_shown")
			for wall in s._wall_parts: wall.modulate.a=0.23
			_compare(s,old,b.level.id()+" changed visibility and prior alpha")
			await _real_occlusion(b,s,old)
		await _dispose(b,true)
	old.free()
	check(_save_hash()==saved_before,"player campaign save bytes unchanged")
	check(report.samples.size()==7,"all seven full entrance timing workloads completed")
	report["part_comparisons"]=part_comparisons
	report["reference"]={"path":REFERENCE,"sha256":FileAccess.get_sha256(REFERENCE)}
	report["passed"]=failures.is_empty();report["failures"]=failures
	report["scope"]="Exact frozen full entrance process comparison; walls and both gate groups, RGBA/sealing/tick cadence; authored level5/defense elevated maps. Paired timings include unit snapshots and original gate processing. Frozen simulation timings are not gameplay FPS."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[wall-visibility-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"part_comparisons":part_comparisons,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
