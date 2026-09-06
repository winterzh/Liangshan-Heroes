extends "res://tools/zhujiazhuang_rts_test.gd"
## Missing campaign terminal art must not borrow another costume or living down.
const PAIRS := [
	["lin_chong","lin_chong_bound"], ["lin_chong","lin_chong_prisoner"],
	["lin_chong","lin_chong_escort"], ["wu_song","wu_song_mengzhou"],
	["jiang_menshen","jiang_menshen_fists"], ["lu_zhishen","lu_zhishen_rescue"],
	["song_jiang","song_jiang_bound"], ["song_jiang","song_jiang_rescued"],
	["dong_chao","dong_chao_escort"], ["xue_ba","xue_ba_escort"]]
const DIRS := ["se","sw","ne","nw"]
var terminal_out := "res://.godot/campaign_terminal_costume"
var observed: Array = []

func _source(frame) -> String:
	return frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path

func _terminal_contracts() -> void:
	var art = root.get_node("Art")
	var ca = load("res://scripts/campaign_art.gd")
	for pair in PAIRS:
		for d in DIRS:
			var generic: Array = art.unit_anim_frames(pair[0],"death",d)
			for state in ["death","down"]:
				var exact: String = ca.animation_path(pair[1],state,d)
				var frames: Array = art.unit_anim_frames(pair[0],state,d,pair[1])
				var has_exact: bool = art.campaign_variant_has_animation(pair[1],state,d)
				check((not frames.is_empty() and _source(frames[0])==exact) if has_exact else frames.is_empty(),pair[1]+" "+state+" "+d+" keeps its own costume or uses procedural fallback")
				check(art.unit_anim_uses_directional_source(pair[0],state,d,pair[1])==has_exact,"direction flag agrees "+pair[1]+" "+state+" "+d)
			var walk: Array = art.unit_anim_frames(pair[0],"walk",d,pair[1])
			check(not walk.is_empty() and _source(walk[0]).begins_with("res://assets/campaign/anim/"+pair[1]+"_"),"fallback base keeps period costume "+pair[1]+" "+d)
			check(art.unit_anim_frames(pair[0],"death",d)==generic,"campaign negative lookup preserves generic death cache "+pair[1]+" "+d)
	# Simulate a newly installed generic directional death resource without
	# writing anything to assets/. Campaign results must stay independent.
	var probe_key := "lin_chong|death|ne"
	var cached_path: Variant = art._generic_directional_path_cache.get(probe_key)
	var ck := "unit|lin_chong|death|ne"
	var cached_frames: Variant = art._anim_cache.get(ck)
	art._generic_directional_path_cache[probe_key]="res://assets/anim/song_jiang_death_ne.tres"
	art._anim_cache.erase(ck)
	var injected: Array = art.unit_anim_frames("lin_chong","death","ne")
	check(not injected.is_empty(),"new generic directional death fixture resolves")
	for variant in ["lin_chong_bound","lin_chong_prisoner","lin_chong_escort"]:
		check(art.unit_anim_frames("lin_chong","death","ne",variant).is_empty(),"new generic four-direction pack cannot replace "+variant)
		check(not art.unit_anim_uses_directional_source("lin_chong","death","ne",variant),"new generic pack cannot change variant mirror flag "+variant)
	check(art.unit_anim_frames("lin_chong","death","ne")==injected,"variant lookups do not overwrite new generic frames")
	if cached_path==null: art._generic_directional_path_cache.erase(probe_key)
	else: art._generic_directional_path_cache[probe_key]=cached_path
	if cached_frames==null: art._anim_cache.erase(ck)
	else: art._anim_cache[ck]=cached_frames
	check(art.unit_anim_frames("lin_chong","death","invalid","lin_chong_bound").is_empty(),"invalid direction rejected")
	check(art.unit_anim_frames("song_jiang","death","se","unknown_variant")==art.unit_anim_frames("song_jiang","death","se"),"unknown variants retain existing compatibility")
	check(art.unit_anim_frames("qin_ming","death","se","bound_qin_ming")==art.unit_anim_frames("qin_ming","death","se"),"programmatic bindings retain their own generic body")
	check(art.unit_anim_frames("song_jiang","death","se","bound_qin_ming").is_empty(),"programmatic binding rejects wrong owner")

func _label(parent, value: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text=value
	label.position=pos
	label.add_theme_font_size_override("font_size",18)
	parent.add_child(label)

func _visual() -> void:
	var b=await _start("",2)
	b.phase=b.Phase.DEPLOY
	b.world.hide()
	b.hud.hide()
	for existing in b.units: existing.set_physics_process(false)
	var canvas := CanvasLayer.new()
	canvas.layer=100
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color=Color("292c25")
	bg.size=Vector2(root.size)
	canvas.add_child(bg)
	_label(canvas,"战役服装隔离 · 实际致命伤后固定在倒下中段 · 每组左为存活，右为死亡",Vector2(20,15))
	var world := Node2D.new()
	world.transform=load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE*2.6)
	canvas.add_child(world)
	var samples: Array=[]
	var cases := [PAIRS[1],PAIRS[3],PAIRS[4],PAIRS[6]]
	for row in range(cases.size()):
		var pair: Array=cases[row]
		_label(canvas,pair[1],Vector2(15,130+row*195))
		for col in range(4):
			if row==0: _label(canvas,DIRS[col].to_upper(),Vector2(350+col*280,50))
			for dead in [false,true]:
				var u=load("res://tools/campaign_terminal_visual_unit.gd").new()
				b.units_root.add_child(u)
				var def: Dictionary=b._defs[pair[0]].duplicate(true)
				def.art_variant=pair[1]
				u.setup(pair[0],def,0,b,b.map)
				u.position=b.map.cell_to_world(Vector2i(18,36))
				b.units.append(u)
				u.died.connect(b._on_unit_died)
				u.set_physics_process(false)
				u.animation_direction=DIRS[col]
				u.face_left=col in [1,3]
				if dead:
					u.take_damage(999999,null,false,true)
					check(u._dying and not b.units.has(u),"real fatal hit starts death "+pair[1]+" "+DIRS[col])
					u._death_t=u.DEATH_DUR*0.42
					u._death_lean=1.0
				else: b.units.erase(u)
				u.reparent(world,false)
				u.position=world.transform.affine_inverse()*Vector2(300+col*280+(110 if dead else 0),185+row*195)
				u.set_process(false)
				u._flash=0.0
				u._flinch=Vector2.ZERO
				u.display_name=""
				u.fog_visible=true
				u.selected=false
				u.show()
				u.queue_redraw()
				if dead: samples.append(u)
	await process_frame
	await RenderingServer.frame_post_draw
	for u in samples:
		check(u.terminal_rest_calls>0 and u.terminal_rest_source.begins_with("res://assets/campaign/anim/"+u.art_variant+"_"),"real death drawing retains "+u.art_variant+" "+u.animation_direction)
		observed.append({"variant":u.art_variant,"direction":u.animation_direction,"rest_calls":u.terminal_rest_calls,"source":u.terminal_rest_source})
	check(root.get_texture().get_image().save_png(terminal_out+"/costume_matrix.png")==OK,"actual Unit matrix saved")
	canvas.queue_free()
	await process_frame
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var custom:=OS.get_environment("TERMINAL_COSTUME_OUT")
	if not custom.is_empty(): terminal_out=custom
	DirAccess.make_dir_recursive_absolute(terminal_out)
	_terminal_contracts()
	if OS.get_environment("TERMINAL_COSTUME_VISUAL")=="1":
		check(DisplayServer.get_name()!="headless","real rendering device")
		root.size=Vector2i(1440,900)
		root.content_scale_size=root.size
		DisplayServer.window_set_size(root.size)
		await _visual()
	FileAccess.open(terminal_out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observed":observed},"\t")+"\n")
	print("[terminal-costume] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
