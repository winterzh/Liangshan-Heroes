extends SceneTree
## Actual level7 route + independent geometry checks. Optional real renderer
## screenshots: MENGZHOU_GATE_VISUAL=1, output MENGZHOU_GATE_OUT or .godot below.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print("[mengzhou-gate] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	# A SceneTree --script is parsed before autoloads. Load the map/render chain
	# only after initialization so its Art and Settings autoload names resolve.
	var Gate = load("res://scripts/campaign_mengzhou_gate.gd")
	var Config = load("res://scripts/campaign_environment.gd")
	var Map = load("res://scripts/game_map.gd")
	var Shadow = load("res://scripts/world_shadow.gd")
	AudioServer.set_bus_mute(0,true)
	var folder := OS.get_environment("MENGZHOU_GATE_OUT")
	if folder.is_empty(): folder="res://.godot/mengzhou_gate_alignment"
	DirAccess.make_dir_recursive_absolute(folder)
	var campaign := root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]:
		campaign.set(key,false)
	campaign.current=campaign.index_for_id("level7")
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene=b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.set_process(false)
	b.camera.set_process(false)
	for unit in b.units: unit.set_physics_process(false)
	check(b.level.get_script().resource_path=="res://scripts/levels/level7_kuaihuolin_short.gd","current campaign route is the short chapter")
	var scenery = b.map.sample_scenery
	var gates: Array=scenery._sprites.filter(func(node): return node.get_script()==Gate)
	check(gates.size()==1,"exactly one dedicated Mengzhou gate is instantiated")
	check(not b.map.decor.any(func(d): return d[0]=="zhu_gate"),"level7 no longer requests the wrong-facing generic gate")
	var observations := {}
	if gates.size()==1:
		var gate = gates[0]
		check(gate.tex.resource_path==Gate.TEXTURE_PATH,"gate uses the existing unlettered stone city source")
		check(FileAccess.get_sha256(Gate.TEXTURE_PATH)=="8f4e97c4a4d967b98de4640114dd562dfa316c388f8340afb83738841d600b14","source bitmap is unchanged")
		check(gate.get_meta("campaign_environment_route","")==Config.MENGZHOU_GATE_MARKER,"explicit Mengzhou route is retained")
		check(b.map.world_to_cell(gate.position)==Vector2i(2,19),"threshold stays at the authored east entrance")
		var size: Vector2=gate.tex.get_size()
		# Independent feet measured in the existing source, not renderer constants.
		var left:=Vector2(0.22,0.822)*size
		var right:=Vector2(0.943,0.635)*size
		var tr: Transform2D=gate.source_transform()
		check((tr*left).distance_to(Vector2(-64,32))<0.01 and (tr*right).distance_to(Vector2(64,-32))<0.01,"wall feet follow the Y axis across the X-axis road")
		check(tr.determinant()>0 and tr.x.x>0,"native source facing is never mirrored")
		check(absf(tr.y.x)<0.0001 and tr.y.y>0,"door jambs and vertical stone courses stay upright")
		check(absf(tr.x.y/tr.x.x)<0.13,"residual ground correction stays below 13 percent")
		var shadow: Transform2D=gate.source_transform(Shadow.CAST_SHEAR)
		check((shadow*left).distance_to(tr*left)<0.01 and (shadow*right).distance_to(tr*right)<0.01,"shadow silhouette retains both gate feet")
		check(gate.has_node("AlignedGroundShadow") and gate.get_node("AlignedGroundShadow").z_index==0,"aligned shadow is submitted below units")
		check(not scenery._ground_shadows.any(func(item): return item.p.distance_to(gate.position)<0.01),"no duplicate square scenery shadow remains")
		observations={"source":gate.tex.resource_path,"wall_axis":[0,-128],"axis_correction_ratio":absf(tr.x.y/tr.x.x),"determinant":tr.determinant()}
	for x in range(2,7):
		check(b.map.t_at(x,19)==Map.T.ROAD and b.map.is_open_cell(Vector2i(x,19)),"road reaches the gate through open cell "+str(Vector2i(x,19)))
	check(not b.map.find_path(b.level.wu.position,b.map.cell_to_world(Vector2i(2,19))).is_empty(),"actual navigation reaches the visible threshold")
	check(root.get_node("Art").campaign_object_texture("zhu_gate")==null,"generic gate alias remains unchanged outside this chapter")
	var visual:=OS.get_environment("MENGZHOU_GATE_VISUAL")=="1"
	if visual:
		check(DisplayServer.get_name()!="headless","visual mode uses a real rendering device")
		if DisplayServer.get_name()!="headless":
			root.mode=Window.MODE_WINDOWED
			root.size=Vector2i(1280,720)
			root.content_scale_size=root.size
			b.fog=false
			if is_instance_valid(b._fog_layer): b._fog_layer.hide()
			for unit in b.units: unit.fog_visible=true; unit.show()
			for view in [["entrance",Vector2i(6,19),1.25],["gate_close",Vector2i(3,19),1.9]]:
				b.camera.zoom=Vector2.ONE*view[2]
				b.center_camera_cell(view[1])
				b.camera.force_update_scroll()
				await create_timer(0.35).timeout
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(folder.path_join(view[0]+".png"))==OK,"saved "+view[0]+" at 1280x720")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"visual_requested":visual,"observations":observations}
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("[mengzhou-gate] ",checks," checks, failures=",failures.size())
	b.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
