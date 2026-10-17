extends SceneTree
class WalkProbe extends Node:
	var actor
	var frames: Array=[]
	var seen: Array=[]
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var a=get_tree().root.get_node("Art")
		var index: int=frames.find(actor._anim_frame_for_state(a.unit_texture(actor.key,"",actor.animation_direction)))
		if index>=0 and not seen.has(index):seen.append(index)
		if seen.size()==4:captured=true;actor.set_physics_process(false)
class LaunchProbe extends Node:
	var actor
	var battle
	var captured:=false
	var frame: Texture2D
	var projectile_kind:=""
	var lunge:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		for child in battle.fx_root.get_children():
			# Resolve the exact runtime script without a compile-time Projectile
			# dependency: --check-only has no running autoload tree for Unit.
			if child.get_script()!=null and child.get_script().resource_path=="res://scripts/projectile.gd" and child.shooter==actor:
				captured=true;projectile_kind=child.kind;lunge=actor._lunge
				frame=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction))
				actor.set_physics_process(false);return
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured:=false
	var timer:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var frame: Texture2D=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("gongsun_sheng","",actor.animation_direction))
		if frame==expected:
			captured=true;timer=actor._shi_en_hurt_t;actor.set_physics_process(false)
class DeathProbe extends Node:
	var actor
	var seen: Array=[]
	var captured:=false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var index:=mini(int(actor._death_t/actor.DEATH_DUR*4.0),3)
		if not seen.has(index):seen.append(index)
		if index==3:captured=true;actor.set_physics_process(false)
var out:=""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var runtime: Array=[]
var art
var pack_inputs: Dictionary={}
var hud_events: Array=[]
func _initialize() -> void:run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)

func snap(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var path:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(path),"size":[root.size.x,root.size.y]})

func fingerprint(b) -> Array:
	var rows: Array=[]
	for u in b.units:rows.append([u.key,u.entity_id,u.position.x,u.position.y,u.hp,u.faction,u.art_variant])
	return rows

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

func native_frame(u,state: String) -> Texture2D:
	var base: Texture2D=art.unit_texture("gongsun_sheng","",u.animation_direction)
	if state=="death":
		var frames: Array=art.unit_anim_frames("gongsun_sheng","death",u.animation_direction,"")
		return frames[mini(int(u._death_t/u.DEATH_DUR*frames.size()),frames.size()-1)]
	return u._anim_frame_for_state(base)

func matrix(b,origin: Vector2,manifest: Dictionary) -> void:
	var u=b.spawn_unit("gongsun_sheng",0,origin);u.set_physics_process(false);u.auto_micro=false
	stage_camera(b,u);b.select_single(u,false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await process_frame;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["attack","hurt","death"]:
				var frames: Array=art.unit_anim_frames("gongsun_sheng",state,d,"")
				check(frames.size()==(8 if state=="attack" else 2 if state=="hurt" else 4),"frame count "+str(size)+state+d)
				var unique: Array=[]
				for index in range(frames.size()):
					var phase: String=manifest.states[state][index]
					if unique.has(phase):continue
					unique.append(phase)
					if size.x!=1280 and index!=(3 if state=="attack" else 0 if state=="hurt" else 3):continue
					var frame: AtlasTexture=frames[index] as AtlasTexture
					var pose: Dictionary=manifest.poses[phase+"_"+d]
					check(frame!=null and frame.atlas.resource_path=="res://"+String(manifest.sources[pose.source].path),"exact native atlas "+str(size)+phase+d)
					check(frame!=null and frame.region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"native sample geometry "+str(size)+phase+d)
					u._lunge=0.0;u._flinch=Vector2.ZERO;u._shi_en_hurt_t=0.0;u._move_blend=0.0;u._dying=state=="death";u._flash=0.0
					if state=="attack":u._lunge=1.0-(float(index)+0.1)/float(frames.size())
					if state=="hurt":u._shi_en_hurt_t=u.SHI_EN_HURT_DUR*(1.0-(float(index)+0.1)/2.0)
					if state=="death":u._death_t=u.DEATH_DUR*(float(index)+0.02)/4.0
					check(native_frame(u,state)==frame,"original Unit chooses authored frame "+str(size)+phase+d)
					u.queue_redraw();await snap(str(size.x)+"x"+str(size.y)+"_"+state+"_"+phase+"_"+d)
	# Existing gait is checked against the exact previously adopted source family.
	u._dying=false;u._lunge=0;u._shi_en_hurt_t=0;u._flinch=Vector2.ZERO
	for d in ["se","sw","ne","nw"]:
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("gongsun_sheng",state,d,"")
			check(frames.size()==(1 if state=="idle" else 4) and frames[0].atlas.resource_path.begins_with("res://assets/characters/gongsun_sheng_daily_20261017/"),"canonical gait bound "+state+d)
	b.units.erase(u);u.queue_free();await process_frame

func verify_packed_textures() -> void:
	var references: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(references.size()==pack_inputs.textures.size(),"all canonical body and portrait native sources referenced")
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

func packed_gait(b,origin: Vector2) -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await process_frame
	var u=b.spawn_unit("gongsun_sheng",0,origin);u.set_physics_process(false);stage_camera(b,u);b.select_single(u,false)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("gongsun_sheng",state,d,"")
			for index in range(frames.size()):
				u._move_blend=1.0 if state=="walk" else 0.0;u._anim_t=TAU*(float(index)+.1)/float(frames.size());u._idle_t=0
				var pose: Dictionary=pack_inputs.gait.poses[String(pack_inputs.gait.states[state][index])+"_"+d]
				check(native_frame(u,state)==frames[index] and frames[index].region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"packed Unit selects canonical gait pose "+state+d+str(index))
				u.queue_redraw()
				await snap("packed_gait_"+state+"_"+d+"_"+str(index))
	b.units.erase(u);u.queue_free();await process_frame

func fits(control: Control) -> bool:
	var available:=Rect2(Vector2.ZERO,Vector2(root.size))
	var p=control.get_parent()
	while p!=null:
		if p is Control and p.clip_contents:available=available.intersection(p.get_global_rect())
		p=p.get_parent()
	return control.is_visible_in_tree() and available.encloses(control.get_global_rect())

func settle() -> void:
	for i in range(6):await process_frame


func real_walk(b,origin: Vector2) -> void:
	var u=b.spawn_unit("gongsun_sheng",0,origin);u.set_physics_process(false);u.auto_micro=false;b.select_single(u,false);stage_camera(b,u)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop()
		var probe:=WalkProbe.new();probe.actor=u;probe.frames=art.unit_anim_frames("gongsun_sheng","walk",row.d,"");probe.process_physics_priority=1000;root.add_child(probe)
		u.set_physics_process(true);u.order_move(origin+row.delta*82.0)
		var deadline:=Time.get_ticks_msec()+4000
		while not probe.captured and Time.get_ticks_msec()<deadline:await physics_frame
		u.set_physics_process(false)
		check(u.position.distance_to(origin)>2.0 and u.animation_direction==row.d,"real physics chooses daily walking facing "+String(row.d))
		check(probe.captured and probe.seen.size()==4,"real motion traverses all four authored gait phases "+String(row.d))
		u.queue_redraw();await snap("real_walk_"+String(row.d));check(u._frame_directional,"real walking renderer uses authored facing "+String(row.d))
		check(u.art_variant.is_empty(),"walking never changes saved variant "+String(row.d))
		runtime.append({"actual_gait_direction":row.d,"observed_phase_indices":probe.seen.duplicate(),"manual_phase_sampling":false});probe.queue_free()
	b.units.erase(u);u.queue_free();await process_frame


func identity_ui() -> void:
	var portrait: Texture2D=art.portrait_texture("gongsun_sheng")
	check(portrait!=null and portrait.resource_path=="res://assets/characters/gongsun_sheng_daily_20261017/portrait.png","canonical bearded cloth portrait resolved")
	check(art.ui_portrait_texture("gongsun_sheng","jiang_menshen_fists")==null,"foreign portrait owner remains rejected")
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("gongsun_sheng")
		for index in range(4):
			codex._on_direction_selected(index);await settle();var d: String=["se","sw","ne","nw"][index]
			check(codex._port.frames==[portrait] and fits(codex._port),"real codex canonical portrait fits "+str(size.x)+d)
			check(codex._walk.frames==art.unit_anim_frames("gongsun_sheng","walk",d) and codex._atk.frames==art.unit_anim_frames("gongsun_sheng","attack",d),"codex binds daily body sources "+str(size.x)+d)
			await snap("codex_gongsun_sheng_"+str(size.x)+"_"+d)
		if size.x==960:
			codex._detail_scroll.scroll_vertical=320;await settle();check(fits(codex._atk),"narrow canonical attack preview scrolls fully into view");await snap("codex_gongsun_sheng_960_attack_scrolled")
	root.get_node("Localize").set_language("en",false);codex._select("gongsun_sheng");await settle();await snap("codex_gongsun_sheng_en_1920")
	check(codex._port.frames==[portrait],"English canonical portrait");root.get_node("Localize").set_language("zh_CN",false)
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;codex._select("gongsun_sheng");await settle();codex._show_lore();await create_timer(.25).timeout;await settle()
			check(codex._lore_text.text==root.get_node("Localize").text(LoreData.LORE.gongsun_sheng),"retained translated lore UI "+locale+str(size.x))
			check(not codex._lore_source.text.is_empty() and fits(codex._lore_source),"actual original chapter source row "+locale+str(size.x))
			await snap("liu_lore_"+locale+"_"+str(size.x));codex._lore_scroll.scroll_vertical=10000;await settle();await snap("liu_lore_end_"+locale+"_"+str(size.x));codex._hide_lore();await create_timer(.25).timeout
	root.get_node("Localize").set_language("zh_CN",false)
	codex.queue_free();await process_frame


func exercise(b,origin: Vector2,direction: String,delta: Vector2) -> void:
	var u=b.spawn_unit("gongsun_sheng",0,origin)
	var target=b.spawn_unit("guan_dao",1,origin+delta*110.0)
	check(u!=null and target!=null,"real ordinary unit definitions exist "+direction)
	if u==null or target==null:return
	target.set_physics_process(false)
	u.auto_micro=false;u.animation_direction=direction
	check(u.setup_def.get("atk",-1)==12 and u.max_hp==165 and u.atk_cd==1.2 and u.atk_range==200 and u.is_ranged and u.base_speed==78,"ordinary base definition retained "+direction)
	check(u.art_variant.is_empty() and u.visual_art_variant().is_empty(),"ordinary daily appearance without saved-variant mutation "+direction)
	check(u.setup_def.get("abilities",[]).size()==4,"inherited four-skill kit retained, not canon-qualified "+direction)
	u.hp=100.0;u._combat_cool=6.0
	var identity: int=u.entity_id
	stage_camera(b,u);b.select_single(u,false)
	var launch:=LaunchProbe.new();launch.actor=u;launch.battle=b;launch.process_physics_priority=1000;root.add_child(launch)
	var prior_hp: float=target.hp
	u.order_attack(target,false,true)
	var deadline:=Time.get_ticks_msec()+6000
	while not launch.captured and Time.get_ticks_msec()<deadline:await physics_frame
	var attack: Array=art.unit_anim_frames("gongsun_sheng","attack",direction,"")
	var slot:=clampi(int((1.0-launch.lunge)*attack.size()),0,attack.size()-1)
	check(launch.captured and launch.frame==attack[slot] and slot==4,"actual projectile release uses sword-extension pose "+direction)
	check(launch.projectile_kind=="gong_gold" and is_equal_approx(u._swing_speed,1.9) and is_equal_approx(u._hit_at,.42),"gold-light visual and retained attack timing "+direction)
	check(u.animation_direction==direction and u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(),"native facing without extra programmatic swing "+direction)
	await snap("actual_release_"+direction)
	deadline=Time.get_ticks_msec()+3500
	while target.hp>=prior_hp and Time.get_ticks_msec()<deadline:await physics_frame
	check(target.hp<prior_hp,"real projectile flight and incoming damage "+direction)
	var dealt: float=prior_hp-target.hp
	launch.queue_free();u.set_physics_process(false);u.order_stop()
	var before_hp: float=u.hp
	u.take_damage(7,target,false,true)
	var hurt: Array=art.unit_anim_frames("gongsun_sheng","hurt",direction,"")
	check(u.hp<before_hp and u._shi_en_hurt_t>0.0 and native_frame(u,"hurt")==hurt[0],"real incoming hit starts impact "+direction)
	await snap("actual_hurt_impact_"+direction)
	var recovery:=RecoveryProbe.new();recovery.actor=u;recovery.expected=hurt[1];recovery.process_physics_priority=1000;root.add_child(recovery)
	u.set_physics_process(true);deadline=Time.get_ticks_msec()+2000
	while not recovery.captured and Time.get_ticks_msec()<deadline:await physics_frame
	check(recovery.captured and recovery.timer>0.0 and recovery.timer<u.SHI_EN_HURT_DUR*.5,"physics progresses from impact to recovery "+direction)
	await snap("actual_hurt_recover_"+direction)
	var recovered: bool=recovery.captured
	recovery.queue_free();u.set_physics_process(false)
	var facing: String=u.animation_direction
	u.take_damage(u.max_hp*20.0,null,false,true)
	check(u._dying and not b.units.has(u) and u.entity_id==identity and u.animation_direction==facing,"real lethal callback removes same actor with facing retained "+direction)
	var death:=DeathProbe.new();death.actor=u;death.process_physics_priority=1000;root.add_child(death)
	u.set_physics_process(true);deadline=Time.get_ticks_msec()+3500
	while not death.captured and is_instance_valid(u) and Time.get_ticks_msec()<deadline:await physics_frame
	check(death.captured and death.seen==[0,1,2,3],"physics traverses four authored death stages "+direction)
	if is_instance_valid(u):
		await snap("actual_terminal_"+direction)
		check(u._real_frames and u._frame_directional,"actual native corpse renderer "+direction)
		var sampled_time: float=u._death_t
		u.set_physics_process(true);deadline=Time.get_ticks_msec()+2500
		while is_instance_valid(u) and Time.get_ticks_msec()<deadline:await process_frame
		check(not is_instance_valid(u),"normal corpse fade releases node "+direction)
		runtime.append({"direction":direction,"projectile_damage":dealt,"hit_slot":slot,"recovery_seen":recovered,"death_indices":death.seen.duplicate(),"terminal_time":sampled_time,"ordinary_fixture":true})
	death.queue_free()
	if is_instance_valid(target):b.units.erase(target);target.queue_free()
	await process_frame

func daily_hud(b,origin: Vector2) -> void:
	var u=b.spawn_unit("gongsun_sheng",0,origin);u.set_physics_process(false)
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;stage_camera(b,u);b.select_single(u,false);b.hud.refresh_command();await settle()
			check(u.ui_portrait_texture()==art.portrait_texture("gongsun_sheng") and b.hud._port_tex.texture==u.ui_portrait_texture() and fits(b.hud._port_tex),"daily portrait in actual HUD "+locale+str(size.x))
			await snap("daily_hud_"+locale+"_"+str(size.x))
	root.get_node("Localize").set_language("zh_CN",false)
	b.units.erase(u);u.queue_free();await process_frame

func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")));verify_packed_textures();await identity_ui()
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	seed(5088120)
	for chapter in [0,4]:
		campaign.current=chapter
		var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
		b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
		var npc=b.find_unit("gongsun_sheng")
		check(is_instance_valid(npc),"actual chapter Gongsun actor "+str(chapter))
		if not is_instance_valid(npc):quit(3);return
		var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true)
		if chapter==0:
			check(npc.art_variant=="hn_gongsun_sheng" and npc.visual_art_variant()==npc.art_variant and npc.atk_range==26 and not npc.is_ranged and npc.setup_def.abilities.is_empty(),"actual Huangnigang merchant remains explicit pu-dao actor")
			check(npc.ui_portrait_texture().resource_path=="res://assets/characters/gongsun_sheng_merchant_20261017/portrait.png","actual Huangnigang portrait remains shirtless")
		else:
			check(npc.art_variant.is_empty() and npc.visual_art_variant()==art.GONGSUN_LATER_VARIANT,"actual later ritual appearance derived without changing stored identity")
			check(npc.ui_portrait_texture().resource_path=="res://assets/characters/art_full_20260916/gongsun_sheng_portrait_20260916.png","later ritual portrait not overwritten by early daily portrait")
			for d in ["se","sw","ne","nw"]:
				var frames: Array=art.unit_anim_frames(npc.key,"walk",d,npc.visual_art_variant())
				check(not frames.is_empty() and frames[0].atlas.resource_path=="res://assets/anim/gongsun_sheng_walk.png" and not art.unit_anim_uses_directional_source(npc.key,"walk",d,npc.visual_art_variant()),"later legacy costume remains separate "+d)
			check(art.ui_portrait_texture("liu_tang",art.GONGSUN_LATER_VARIANT)==null and art.unit_anim_frames("liu_tang","walk","se",art.GONGSUN_LATER_VARIANT).is_empty(),"later costume cannot be borrowed by foreign owner")
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;stage_camera(b,npc);b.select_single(npc,false);await settle()
			check(b.hud._port_tex.texture==npc.ui_portrait_texture() and fits(b.hud._port_tex),"actual chapter contextual HUD "+str(chapter)+str(size.x));await snap("chapter_"+str(chapter)+"_hud_"+str(size.x))
		check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==decor,"chapter actors/map/decor retained "+str(chapter))
		b.queue_free();await process_frame;await process_frame
	campaign.current=0;campaign.skirmish=true
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
	var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true);var cell:=clear_cell(b)
	check(cell.x>=0,"unobstructed ordinary test site without scenery mutation")
	if cell.x<0:quit(4);return
	var origin: Vector2=b.map.cell_to_world(cell)
	await daily_hud(b,origin);await matrix(b,origin,pack_inputs.combat);await packed_gait(b,origin);await real_walk(b,origin)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,origin,row.d,row.delta)
	check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==decor,"ordinary actors/map/decor retained after fixtures")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"scope":"Daily chapter15 body/portrait, 8-phase sword gesture including reach, real projectile release, movement/hurt/game defeat/fade, codex/HUD/lore layouts; explicit chapter1 merchant and derived chapter5 retained later costume. Inherited projectile/skills not canon-qualified; later redraw, spell audit and overall art/campaign/save/balance/performance/Steam remain open."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print("GONGSUN_DAILY ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
