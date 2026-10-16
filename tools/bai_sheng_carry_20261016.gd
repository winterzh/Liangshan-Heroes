extends SceneTree
const CampaignArt=preload("res://scripts/campaign_art.gd")
class WalkProbe extends Node:
	var actor
	var frames: Array=[]
	var seen: Array=[]
	var captured:=false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var a=get_tree().root.get_node("Art")
		var index: int=frames.find(actor._anim_frame_for_state(a.unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction)))
		if index>=0 and not seen.has(index):seen.append(index)
		if seen.size()==4:captured=true;actor.set_physics_process(false)
var out:=""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var observations: Array=[]
var art
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func settle() -> void:
	for i in range(4):await process_frame
func snap(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var path:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(path),"size":[root.size.x,root.size.y]})
func freeze(b) -> void:
	for u in b.units:u.set_physics_process(false)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false);b.camera.set_physics_process(false);b.camera.position_smoothing_enabled=false;b.camera.zoom=Vector2.ONE*2.8
func stage_camera(b,u) -> void:
	b.camera.position=b.to_screen(u.position)+Vector2(0,-22);b.camera.force_update_scroll()
func clear_cell(b) -> Vector2i:
	for x in range(8,b.map.w-8):
		for y in range(8,b.map.h-8):
			var cell:=Vector2i(x,y);var valid:=true
			for dx in range(-3,4):
				for dy in range(-3,4):
					if not b.map.is_open_world(b.map.cell_to_world(cell+Vector2i(dx,dy))) or b.map.t_at(x+dx,y+dy) in [b.map.T.FOREST,b.map.T.REEDS,b.map.T.MARSH]:valid=false
			if valid:
				var p: Vector2=b.map.cell_to_world(cell)
				if b.map.decor.any(func(row):return b.map.cell_to_world(row[1]).distance_to(p)<maxf(220.0,float(row[2]))):continue
				if not b.units.any(func(u):return is_instance_valid(u) and u.position.distance_to(p)<180):return cell
	return Vector2i(-1,-1)
func frame(u) -> Texture2D:
	return u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
func native_textures() -> void:
	var refs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(refs.size()==9,"five new carry atlases and four retained native identity textures")
	for p in refs:
		check(not FileAccess.file_exists("res://"+String(p)),"native PNG absent in full PCK "+p)
		var tex: Texture2D=load("res://"+String(p));check(tex!=null,"PCK texture loads "+p)
		if tex==null:continue
		var im:=tex.get_image()
		if im.is_compressed():check(im.decompress()==OK,"decompress "+p)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(im.get_data())
		check(digest.finish().hex_encode()==String(refs[p].data_sha256),"native pixels and mipmaps exact "+p)
		check(im.get_width()==int(refs[p].size[0]) and im.get_height()==int(refs[p].size[1]),"native texture dimensions exact "+p)
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	native_textures()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS"))).manifest
	var old_idle: Array=art.unit_anim_frames("bai_sheng","idle","se","hn_bai_sheng")
	var old_walk: Array=art.unit_anim_frames("bai_sheng","walk","se","hn_bai_sheng")
	var old_portrait: Texture2D=art.ui_portrait_texture("bai_sheng","hn_bai_sheng")
	check(old_idle.size()==1 and old_walk.size()==2 and old_portrait!=null,"original empty-handed body and portrait available")
	for d in ["se","sw","ne","nw"]:
		for state in ["carry_idle","carry_walk"]:
			var fs: Array=art.unit_anim_frames("bai_sheng",state,d,"hn_bai_sheng")
			check(fs.size()==(1 if state=="carry_idle" else 4),"dedicated carry count "+state+d)
			check(art.campaign_variant_has_animation("hn_bai_sheng",state,d) and art.unit_anim_uses_directional_source("bai_sheng",state,d,"hn_bai_sheng"),"exact directional carry route "+state+d)
		check(CampaignArt.native_wine_carry_path("liu_tang","hn_bai_sheng","carry_walk",d).is_empty(),"foreign actor cannot use new Bai carry "+d)
		check(CampaignArt.native_wine_carry_path("bai_sheng","","carry_walk",d).is_empty(),"ordinary Bai cannot use chapter carry "+d)
	check(CampaignArt.native_wine_carry_path("bai_sheng","hn_bai_sheng","death","se").is_empty() and CampaignArt.native_wine_carry_path("bai_sheng","hn_bai_sheng","carry_walk","bad").is_empty(),"terminal and malformed routes reject carry")
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
	check(b.level.get_script().resource_path=="res://scripts/levels/level1_huangnigang_short.gd" and b._gameplay_rng_issue.is_empty(),"actual current short chapter loads with original RNG")
	var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true)
	# Advance only inquiry prerequisites in this QA fixture; use the original
	# action callback to create Bai, set carry metadata and issue the entry walk.
	b.level.st=b.level.INQUIRY;b.level.exposure=0;b.level.yang.order_stop();b.level.yang.position=b.map.cell_to_world(b.level.INSPECT)
	b.mission.mark("yang_inquired","QA inquiry prerequisite")
	b.level.on_mission_action(b,"answer_yang",b.find_unit("liu_tang"));freeze(b)
	var u=b.find_unit("bai_sheng")
	check(is_instance_valid(u) and b.level.st==b.level.ARRIVAL and b.level.bai_arrival_auto,"original inquiry callback starts Bai arrival")
	if not is_instance_valid(u):finish();return
	check(u.art_variant=="hn_bai_sheng" and u.get_meta("carrying_wine",false) and b.mission.has_event("bai_arrived"),"original arrival creates explicit wine-carry identity")
	var original_stats: Array=[u.max_hp,u.atk,u.atk_cd,u.base_speed,u.setup_def.abilities.duplicate()]
	b.select_single(u,false);stage_camera(b,u);await snap("original_bai_entry")
	var cell:=clear_cell(b);check(cell!=Vector2i(-1,-1),"open original scenery site for gait sample")
	if cell==Vector2i(-1,-1):finish();return
	var origin: Vector2=b.map.cell_to_world(cell);u.position=origin;u.order_stop();u.auto_micro=false
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;await settle();stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["carry_idle","carry_walk"]:
				var fs: Array=art.unit_anim_frames("bai_sheng",state,d,"hn_bai_sheng")
				for i in range(fs.size()):
					u._move_blend=1.0 if state=="carry_walk" else 0.0;u._anim_t=TAU*(float(i)+.1)/float(fs.size());u._idle_t=0
					var p: Dictionary=manifest.poses[String(manifest.states[state][i])+"_"+d]
					check(frame(u)==fs[i] and u._frame_directional and u._real_frames,"actual Unit selects native carry and forbids mirror "+str(size.x)+state+d+str(i))
					check(fs[i].atlas.resource_path=="res://"+String(manifest.sources[p.source].path) and fs[i].region==Rect2(p.region[0],p.region[1],p.region[2],p.region[3]),"exact selected pose region "+str(size.x)+state+d+str(i))
					check(u._campaign_wine_carry_state()==state,"carry route suppresses old bucket overlay "+str(size.x)+state+d+str(i))
					u.queue_redraw();await snap("carry_"+str(size.x)+"_"+state+"_"+d+"_"+str(i))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop();stage_camera(b,u)
		var probe:=WalkProbe.new();probe.actor=u;probe.frames=art.unit_anim_frames("bai_sheng","carry_walk",row.d,"hn_bai_sheng");probe.process_physics_priority=1000;root.add_child(probe)
		u.set_physics_process(true);u.order_move(origin+row.delta*82.0)
		var deadline:=Time.get_ticks_msec()+5000
		while not probe.captured and Time.get_ticks_msec()<deadline:await physics_frame
		u.set_physics_process(false)
		check(probe.captured and probe.seen.size()==4 and u.position.distance_to(origin)>2 and u.animation_direction==row.d,"real Unit motion traverses four carry phases "+String(row.d))
		observations.append({"direction":row.d,"seen":probe.seen,"distance":u.position.distance_to(origin)})
		stage_camera(b,u);u.queue_redraw();await snap("actual_carry_walk_"+String(row.d));probe.queue_free();await process_frame
	# The original automatic-arrival consumer, not a replacement QA unload,
	# clears the metadata and creates the original static two-bucket object.
	u.order_stop();u.position=b.map.cell_to_world(b.level.WINE_UNLOAD);u._move_blend=0;b.level.bai_arrival_serial=u._order_serial;b.level.bai_arrival_auto=true;u.manual_order_active=false;u.manual_order_t=0
	b.level._bai_arrival_tick(b,1.6);stage_camera(b,u);u.queue_redraw();await snap("actual_unload_original_scene")
	check(b.level.st==b.level.WINE and b.mission.has_event("bai_unloaded") and not u.get_meta("carrying_wine",true),"original arrival consumer unloads at destination")
	check(u._campaign_wine_carry_state().is_empty(),"unloaded Unit leaves native carry state")
	u.animation_direction="se";check(frame(u)==old_idle[0],"unloaded Unit returns to original grey-clothed empty-handed idle")
	check(art.unit_anim_frames("bai_sheng","walk","se","hn_bai_sheng")==old_walk and u.ui_portrait_texture()==old_portrait,"old walk and portrait unchanged")
	check([u.max_hp,u.atk,u.atk_cd,u.base_speed,u.setup_def.abilities]==original_stats,"original Bai stats and skill definition unchanged")
	check(Array(b.map.grid)==grid and b.map.decor==decor,"original map and scenery retained")
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false);b.select_single(u,false);await snap("unloaded_hud_"+locale)
		check(b.hud._port_tex.texture==old_portrait,"original portrait in HUD "+locale)
	check(not u._dying and u.story_outcome=="","carry batch does not invent terminal outcome")
	finish()
func finish() -> void:
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"observations":observations,"scope":"Current short chapter Bai carry idle/walk, four directions and three sizes; actual Unit physics and original inquiry/arrival/unload callbacks with explicit QA prerequisite and location fixtures, unrelated actors frozen and fog off. No full chapter/campaign/save/performance/Steam/all art claim."}
	var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();quit(0 if failures.is_empty() else 1)
