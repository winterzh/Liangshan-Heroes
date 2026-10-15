extends SceneTree
const CampaignArt = preload("res://scripts/campaign_art.gd")
const SKIN := CampaignArt.SHI_EN_RECOVERY_VARIANT
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var a=get_tree().root.get_node("Art")
		if actor._anim_frame_for_state(a.unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction))==expected:
			captured=true;actor.set_physics_process(false)
class DeathProbe extends Node:
	var actor
	var seen: Array=[]
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var index:=mini(int(actor._death_t/actor.DEATH_DUR*4.0),3)
		if not seen.has(index):seen.append(index)
		if index==3:captured=true;actor.set_physics_process(false)
var out := ""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var art
var pack_inputs: Dictionary={}
var runtime: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func snap(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var path:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(path),"size":[root.size.x,root.size.y]})
func stage_camera(b,u) -> void:
	b.camera.position=b.to_screen(u.position)+Vector2(0,-25)
	b.camera.force_update_scroll()
func freeze(b) -> void:
	for unit in b.units:unit.set_physics_process(false)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false);b.camera.set_physics_process(false);b.camera.position_smoothing_enabled=false;b.camera.zoom=Vector2.ONE*2.8
func clear_cell(b) -> Vector2i:
	for x in range(8,b.map.w-8):
		for y in range(8,b.map.h-8):
			var cell:=Vector2i(x,y)
			var valid:=true
			for dx in range(-3,4):
				for dy in range(-3,4):
					if not b.map.is_open_world(b.map.cell_to_world(cell+Vector2i(dx,dy))) or b.map.t_at(x+dx,y+dy) in [b.map.T.FOREST,b.map.T.REEDS,b.map.T.MARSH]:valid=false
			if valid:
				var p: Vector2=b.map.cell_to_world(cell)
				# Scenery is not in Battle.units. Reject sites under the original
				# large banners rather than hiding, removing or relocating scenery.
				if b.map.decor.any(func(row):return b.map.cell_to_world(row[1]).distance_to(p)<maxf(220.0,float(row[2]))):continue
				if not b.units.any(func(u):return is_instance_valid(u) and u.position.distance_to(p)<180):return cell
	return Vector2i(-1,-1)
func verify_packed_textures() -> void:
	var references: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(references.size()==pack_inputs.textures.size(),"all officer body and portrait native sources referenced")
	for p in references:
		check(not FileAccess.file_exists("res://"+String(p)),"native PNG absent from real PCK "+p)
		var tex: Texture2D=load("res://"+String(p))
		check(tex!=null,"packed native texture loads "+p)
		if tex==null:continue
		var im:=tex.get_image()
		if im.is_compressed():check(im.decompress()==OK,"packed texture decompression "+p)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(im.get_data())
		check(digest.finish().hex_encode()==String(references[p].data_sha256),"packed actual texture pixels and mipmaps match native import "+p)
		check(im.get_width()==int(references[p].size[0]) and im.get_height()==int(references[p].size[1]),"packed native dimensions "+p)
func fits(control: Control) -> bool:
	var available:=Rect2(Vector2.ZERO,Vector2(root.size))
	var p=control.get_parent()
	while p!=null:
		if p is Control and p.clip_contents:available=available.intersection(p.get_global_rect())
		p=p.get_parent()
	return control.is_visible_in_tree() and available.encloses(control.get_global_rect())
func settle() -> void:
	for i in range(6):await process_frame

func native_frame(u) -> Texture2D:
	return u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))

func chapter():
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=6;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	check(b.level.get_script().resource_path=="res://scripts/levels/level7_kuaihuolin_short.gd","actual current short Level7 loaded")
	return b

func binding(b,u) -> void:
	check(u.key=="shi_en" and u.art_variant.is_empty() and u.visual_art_variant()==SKIN,"actual chapter role derives skin without changing saved variant")
	check(u.setup_def.atk==0 and u.is_noncombat and u.setup_def.abilities.is_empty() and u.max_hp==210,"original noncombat definition retained")
	check(u.ui_portrait_texture()!=art.portrait_texture("shi_en"),"stage portrait is distinct from healthy identity")
	var role=b.level.shi
	b.level.shi=null
	check(u.visual_art_variant().is_empty(),"same named non-role actor cannot derive chapter skin")
	b.level.shi=role
	check(u.visual_art_variant()==SKIN,"direct role rebind recovers appearance; not full save restore")
	var f: int=u.faction;u.faction=1
	check(u.visual_art_variant().is_empty(),"enemy actor excluded");u.faction=f
	u.is_noncombat=false
	check(u.visual_art_variant().is_empty(),"combatant excluded");u.is_noncombat=true
	u.art_variant="bound_shi_qian"
	check(u.visual_art_variant()=="bound_shi_qian","explicit persisted variant retains precedence");u.art_variant=""
	var short_level=b.level
	var long_level=load("res://scripts/levels/level7_kuaihuolin.gd").new()
	long_level.shi=u;b.level=long_level
	check(u.visual_art_variant()==SKIN,"original long Level7 role binding")
	b.level=short_level
	var extra=b.spawn_unit("shi_en",0,u.position+Vector2(80,0));extra.set_physics_process(false)
	check(extra.visual_art_variant().is_empty(),"extra same-key actor in same chapter excluded")
	b.units.erase(extra);extra.queue_free()
	for d in ["se","sw","ne","nw"]:
		for state in ["idle","walk","hurt","death"]:
			check(art.campaign_variant_has_animation(SKIN,state,d),"authored chapter state "+state+d)
			check(art.unit_anim_frames("wu_song",state,d,SKIN).is_empty(),"foreign body rejected "+state+d)
		check(art.unit_anim_frames("shi_en","attack",d,SKIN).is_empty() and not art.campaign_variant_has_animation(SKIN,"attack",d),"no borrowed armed attack "+d)
	check(art.ui_portrait_texture("wu_song",SKIN)==null and art.avatar_texture("wu_song",SKIN)==null,"foreign stage portrait and preview rejected")
	check(not u._should_draw_programmatic_swing_fx(),"no inferred weapon trail")

func chapter_ui(b,u) -> void:
	var p: Texture2D=u.ui_portrait_texture()
	check(p.resource_path=="res://assets/characters/shi_en_recovering_20261015/portrait.png","correct stage portrait resource")
	var lines: Array=b.level.intro_lines()
	var original_line: Dictionary={}
	for line in lines:
		if line.key=="shi_en":original_line=line
	check(not original_line.is_empty(),"original chapter Shi En dialogue exists")
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;stage_camera(b,u);b.select_single(u,false);await settle()
		check(b.hud._port_tex.texture==p and fits(b.hud._port_tex),"actual selected-role HUD portrait "+str(size.x))
		await snap("chapter_hud_"+str(size.x))
		b.hud.show_intro([original_line]);await settle()
		check(b.hud._intro_port_tex.texture==p and fits(b.hud._intro_port_tex),"original authored dialogue stage portrait "+str(size.x))
		await snap("chapter_dialogue_"+str(size.x));b.hud._intro_root.hide()

func matrix(b,u,origin: Vector2) -> void:
	u.position=origin;stage_camera(b,u)
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;await settle();stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["idle","walk","hurt","death"]:
				var frames: Array=art.unit_anim_frames("shi_en",state,d,SKIN)
				check(frames.size()==pack_inputs.gait.states[state].size(),"native frame count "+str(size.x)+state+d)
				for i in range(frames.size()):
					if size.x!=1280 and i!=(frames.size()-1):continue
					var phase: String=pack_inputs.gait.states[state][i]
					var pose: Dictionary=pack_inputs.gait.poses[phase+"_"+d]
					var frame: AtlasTexture=frames[i]
					check(frame.atlas.resource_path=="res://"+String(pack_inputs.gait.sources[pose.source].path) and frame.region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"native untouched source region "+str(size.x)+phase+d)
					u._dying=state=="death";u._lunge=0;u._flinch=Vector2.ZERO;u._flash=0;u._idle_t=0
					u._move_blend=1.0 if state=="walk" else 0.0
					u._anim_t=TAU*(float(i)+.1)/float(frames.size())
					u._shi_en_hurt_t=u.SHI_EN_HURT_DUR*(1.0-(float(i)+.1)/2.0) if state=="hurt" else 0.0
					u._death_t=u.DEATH_DUR*(float(i)+.02)/4.0 if state=="death" else 0.0
					if state!="death":check(native_frame(u)==frame,"Unit chooses chapter pose "+str(size.x)+phase+d)
					u.queue_redraw();await snap("matrix_"+str(size.x)+"_"+phase+"_"+d)
					check(u.visual_art_variant()==SKIN,"pose never leaks healthy variant "+str(size.x)+phase+d)
	u._dying=false;u._death_t=0;u._shi_en_hurt_t=0;u._move_blend=0;u._flash=0

func walk(b,u,origin: Vector2) -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	for row in [{"d":"se","v":Vector2.RIGHT},{"d":"sw","v":Vector2.DOWN},{"d":"ne","v":Vector2.UP},{"d":"nw","v":Vector2.LEFT}]:
		u.position=origin;u.order_stop();u.auto_micro=false;u.set_physics_process(true);u.order_move(origin+row.v*52.0)
		for tick in range(12):await physics_frame
		u.set_physics_process(false);stage_camera(b,u)
		check(u.position.distance_to(origin)>2 and u.animation_direction==row.d and u.visual_art_variant()==SKIN,"real chapter role movement "+String(row.d))
		u.queue_redraw();await snap("real_walk_"+String(row.d))
		check(u._frame_directional,"actual moving renderer uses authored facing "+String(row.d))
	u.order_stop()
	var t=b.spawn_unit("guan_dao",1,origin+Vector2(10,0));t.set_physics_process(false)
	var hp: float=t.hp
	u.position=origin;u.order_attack(t,false,true);u.set_physics_process(true)
	for tick in range(80):await physics_frame
	u.set_physics_process(false);u.order_stop()
	check(t.hp==hp and u.setup_def.abilities.is_empty(),"existing noncombat role cannot damage or gain skills")
	b.units.erase(t);t.queue_free()

func injury_and_death(b,u,origin: Vector2,d: String) -> void:
	u.position=origin;u.animation_direction=d;u.order_stop();stage_camera(b,u);b.select_single(u,false)
	var t=b.spawn_unit("guan_dao",1,origin+Vector2(20,0));t.set_physics_process(false)
	var before: float=u.hp
	u.take_damage(7,t,false,true)
	var frames: Array=art.unit_anim_frames("shi_en","hurt",d,SKIN)
	check(u.hp<before and u._shi_en_hurt_t>0 and native_frame(u)==frames[0],"real incoming damage selects unarmed impact "+d)
	await snap("real_hurt_"+d)
	var probe:=RecoveryProbe.new();probe.actor=u;probe.expected=frames[1];probe.process_physics_priority=1000;root.add_child(probe)
	u.set_physics_process(true);var deadline:=Time.get_ticks_msec()+2000
	while not probe.captured and Time.get_ticks_msec()<deadline:await physics_frame
	check(probe.captured,"real physics reaches unarmed recovery "+d)
	await snap("real_recover_"+d);probe.queue_free();u.set_physics_process(false)
	u.take_damage(u.max_hp*20.0,null,false,true)
	check(u._dying and u.visual_art_variant()==SKIN and u.art_variant.is_empty(),"real lethal callback preserves unarmed role skin "+d)
	check(b.hud._end_root.visible,"existing chapter failure screen triggered by role death "+d)
	await snap("actual_failure_rule_"+d)
	# View the actual body behind the existing opaque failure screen. This is
	# a QA-only visibility change after proving failure; gameplay is untouched.
	b.hud._end_root.hide()
	var death:=DeathProbe.new();death.actor=u;death.process_physics_priority=1000;root.add_child(death)
	u.set_physics_process(true);deadline=Time.get_ticks_msec()+3500
	while not death.captured and is_instance_valid(u) and Time.get_ticks_msec()<deadline:await physics_frame
	check(death.captured and death.seen==[0,1,2,3],"actual four death phases "+d)
	if is_instance_valid(u):
		await snap("real_terminal_"+d)
		check(u._real_frames and u._frame_directional and u.visual_art_variant()==SKIN,"native terminal renderer has no staff "+d)
		u.set_physics_process(true);deadline=Time.get_ticks_msec()+2500
		while is_instance_valid(u) and Time.get_ticks_msec()<deadline:await process_frame
		check(not is_instance_valid(u),"normal fade releases role node "+d)
	b.hud._end_root.show()
	runtime.append({"direction":d,"death_indices":death.seen.duplicate(),"actual_short_level_role":true,"battle_and_other_actors_frozen":true})
	death.queue_free();b.units.erase(t);t.queue_free()

func ordinary_ui() -> void:
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("shi_en");await settle()
		check(codex._port.frames==[art.portrait_texture("shi_en")] and codex._port.frames[0].resource_path=="res://assets/characters/shi_en_canon_20261015/portrait.png","ordinary codex retains healthy portrait "+str(size.x))
		for index in range(4):
			codex._on_direction_selected(index);await settle()
			var d: String=["se","sw","ne","nw"][index]
			check(codex._walk.frames==art.unit_anim_frames("shi_en","walk",d) and codex._atk.frames==art.unit_anim_frames("shi_en","attack",d),"ordinary codex retains staff actions "+str(size.x)+d)
		await snap("ordinary_codex_"+str(size.x))
	codex.queue_free();await process_frame

func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")))
	verify_packed_textures()
	var b=await chapter();var u=b.level.shi
	binding(b,u);await chapter_ui(b,u)
	var cell: Vector2i=clear_cell(b)
	check(cell.x>=0,"unobstructed existing ground fixture")
	if cell.x<0:quit(3);return
	var origin: Vector2=b.map.cell_to_world(cell)
	await matrix(b,u,origin);await walk(b,u,origin);await injury_and_death(b,u,origin,"se")
	b.queue_free();await process_frame;await process_frame
	for d in ["sw","ne","nw"]:
		b=await chapter();u=b.level.shi
		await injury_and_death(b,u,origin,d)
		b.queue_free();await process_frame;await process_frame
	await ordinary_ui()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"scope":"Real full PCK imported pixels/mips; actual short Level7 role, original dialogue and selected HUD in three sizes. Derived long-level role binding and negatives; explicit44-pose matrix. Actual role movement, injury/recovery and death/fade; Battle/other actors frozen and role relocated to clear ground. Ordinary codex healthy staff regression. No full chapter playthrough, full save restore, performance, novel fate enactment, live SDK, Steam or whole art completion."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("SHI_EN_RECOVERING ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

