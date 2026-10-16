extends SceneTree
class WalkProbe extends Node:
	var actor
	var frames: Array=[]
	var seen: Array=[]
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var a=get_tree().root.get_node("Art")
		var index: int=frames.find(actor._anim_frame_for_state(a.unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction)))
		if index>=0 and not seen.has(index):seen.append(index)
		if seen.size()==4:captured=true;actor.set_physics_process(false)
class HitProbe extends Node:
	var actor
	var target
	var prior_hp: float
	var captured:=false
	var frame: Texture2D
	var lunge:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor) or not is_instance_valid(target):return
		if target.hp<prior_hp:
			captured=true;lunge=actor._lunge
			frame=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("liu_tang",actor.visual_art_variant(),actor.animation_direction))
			actor.set_physics_process(false)
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured:=false
	var timer:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var frame: Texture2D=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("liu_tang",actor.visual_art_variant(),actor.animation_direction))
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
var fixture_skin:=""
var fixture_context:="ordinary"
var shot_prefix:=""
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
	label=shot_prefix+label
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
	var base: Texture2D=art.unit_texture("liu_tang",u.visual_art_variant(),u.animation_direction)
	if state=="death":
		var frames: Array=art.unit_anim_frames("liu_tang","death",u.animation_direction,u.visual_art_variant())
		return frames[mini(int(u._death_t/u.DEATH_DUR*frames.size()),frames.size()-1)]
	return u._anim_frame_for_state(base)
func exercise(b,origin: Vector2,direction: String,delta: Vector2) -> void:
	var u=b.spawn_unit("liu_tang",0,origin)
	var target=b.spawn_unit("guan_dao",1,origin+delta*24.0)
	check(u!=null and target!=null,"real ordinary unit definitions exist "+direction)
	if u==null or target==null:return
	target.set_physics_process(false)
	u.auto_micro=false;u.animation_direction=direction
	check(u.setup_def.get("atk",-1)==22 and u.max_hp==210 and u.atk_cd==0.8 and u.atk_range==26 and not u.is_ranged and u._weapon_kind()==u.WK.SWORD and u.base_speed==86,"corrected ordinary melee definition "+direction)
	check((u.setup_def.get("abilities",[]).size()==4 and u.art_variant.is_empty()) if fixture_skin.is_empty() else (u.setup_def.get("abilities",[]).is_empty() and u.art_variant==fixture_skin),"ordinary four-skill identity retained "+direction)
	if fixture_skin.is_empty():u.ability_slots[2].rank=3;u._recompute_hero_stats()
	u.hp=100.0;u._combat_cool=6.0
	var identity: int=u.entity_id
	stage_camera(b,u);b.select_single(u,false)
	var hit:=HitProbe.new();hit.actor=u;hit.target=target;hit.prior_hp=target.hp;hit.process_physics_priority=1000;root.add_child(hit)
	u.order_attack(target,false,true)
	var deadline:=Time.get_ticks_msec()+6000
	while not hit.captured and Time.get_ticks_msec()<deadline:await physics_frame
	var attack: Array=art.unit_anim_frames("liu_tang","attack",direction,fixture_skin)
	var slot:=clampi(int((1.0-u._hit_at)*attack.size()),0,attack.size()-1)
	check(hit.captured and target.hp<hit.prior_hp,"real normal melee damage "+direction)
	check(is_equal_approx(u.hp,100.0),"real normal hit does not add lifesteal "+direction)
	check(hit.captured and hit.frame==attack[slot] and slot==4,"actual hit uses authored strike pose "+direction)
	check(is_equal_approx(u._swing_speed,2.1) and is_equal_approx(u._hit_at,0.48),"existing attack timing retained "+direction)
	check(u.animation_direction==direction and u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(),"native facing without double swing "+direction)
	await snap("actual_hit_"+direction)
	var dealt: float=hit.prior_hp-target.hp
	hit.queue_free()
	u.set_physics_process(false);u.order_stop()
	var before_hp: float=u.hp
	u.take_damage(7,target,false,true)
	var hurt: Array=art.unit_anim_frames("liu_tang","hurt",direction,fixture_skin)
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
		runtime.append({"direction":direction,"melee_damage":dealt,"hit_slot":slot,"recovery_seen":recovered,"death_indices":death.seen.duplicate(),"terminal_time":sampled_time,"fixture_skin":fixture_skin,"fixture_context":fixture_context,"transient_definition_fixture":true})
	death.queue_free()
	if is_instance_valid(target):b.units.erase(target);target.queue_free()
	await process_frame
func matrix(b,origin: Vector2,manifest: Dictionary) -> void:
	var u=b.spawn_unit("liu_tang",0,origin);u.set_physics_process(false);u.auto_micro=false
	stage_camera(b,u);b.select_single(u,false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await process_frame;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["attack","hurt","death"]:
				var frames: Array=art.unit_anim_frames("liu_tang",state,d,fixture_skin)
				check(frames.size()==(8 if state=="attack" else 2 if state=="hurt" else 4),"frame count "+str(size)+state+d)
				var unique: Array=[]
				for index in range(frames.size()):
					var phase: String=manifest.states[state][index]
					if unique.has(phase):continue
					unique.append(phase)
					if size.x!=1280 and index!=(2 if state=="attack" else 0 if state=="hurt" else 3):continue
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
			var frames: Array=art.unit_anim_frames("liu_tang",state,d,fixture_skin)
			check(frames.size()==(1 if state=="idle" else 4) and frames[0].atlas.resource_path=="res://"+String(manifest.sources[manifest.poses[String(manifest.states[state][0])+"_"+d].source].path),"canonical gait bound "+state+d)
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
	var u=b.spawn_unit("liu_tang",0,origin);u.set_physics_process(false);stage_camera(b,u);b.select_single(u,false)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("liu_tang",state,d,fixture_skin)
			for index in range(frames.size()):
				u._move_blend=1.0 if state=="walk" else 0.0;u._anim_t=TAU*(float(index)+.1)/float(frames.size());u._idle_t=0
				var gait: Dictionary=pack_inputs.gait if fixture_skin.is_empty() else pack_inputs.merchant
				var pose: Dictionary=gait.poses[String(gait.states[state][index])+"_"+d]
				check(native_frame(u,state)==frames[index] and frames[index].atlas.resource_path=="res://"+String(gait.sources[pose.source].path) and frames[index].region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"packed Unit selects canonical gait pose "+state+d+str(index))
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

func identity_ui() -> void:
	var portrait: Texture2D=art.portrait_texture("liu_tang")
	check(portrait!=null and portrait.resource_path=="res://assets/characters/liu_tang_pudao_20261016/portrait.png","canonical bearded cloth portrait resolved")
	check(art.ui_portrait_texture("liu_tang","jiang_menshen_fists")==null,"foreign portrait owner remains rejected")
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("liu_tang")
		for index in range(4):
			codex._on_direction_selected(index);await settle();var d: String=["se","sw","ne","nw"][index]
			check(codex._port.frames==[portrait] and fits(codex._port),"real codex canonical portrait fits "+str(size.x)+d)
			check(codex._walk.frames==art.unit_anim_frames("liu_tang","walk",d) and codex._atk.frames==art.unit_anim_frames("liu_tang","attack",d),"real codex matching cloth bodies "+str(size.x)+d)
			await snap("codex_liu_tang_"+str(size.x)+"_"+d)
		if size.x==960:
			codex._detail_scroll.scroll_vertical=320;await settle();check(fits(codex._atk),"narrow canonical attack preview scrolls fully into view");await snap("codex_liu_tang_960_attack_scrolled")
	root.get_node("Localize").set_language("en",false);codex._select("liu_tang");await settle();await snap("codex_liu_tang_en_1920")
	check(codex._port.frames==[portrait],"English canonical portrait");root.get_node("Localize").set_language("zh_CN",false)
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;codex._select("liu_tang");await settle();codex._show_lore();await create_timer(.25).timeout;await settle()
			check(codex._lore_text.text==root.get_node("Localize").text(LoreData.LORE.liu_tang),"full translated identity and game-design boundary "+locale+str(size.x))
			check("14" in codex._lore_source.text and "16" in codex._lore_source.text and fits(codex._lore_source),"actual original chapter source row "+locale+str(size.x))
			await snap("liu_lore_"+locale+"_"+str(size.x));codex._lore_scroll.scroll_vertical=10000;await settle();await snap("liu_lore_end_"+locale+"_"+str(size.x));codex._hide_lore();await create_timer(.25).timeout
	root.get_node("Localize").set_language("zh_CN",false)
	codex.queue_free();await process_frame

func real_walk(b,origin: Vector2) -> void:
	var u=b.spawn_unit("liu_tang",0,origin);u.set_physics_process(false);u.auto_micro=false;b.select_single(u,false);stage_camera(b,u)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop()
		var probe:=WalkProbe.new();probe.actor=u;probe.frames=art.unit_anim_frames("liu_tang","walk",row.d,fixture_skin);probe.process_physics_priority=1000;root.add_child(probe)
		u.set_physics_process(true);u.order_move(origin+row.delta*82.0)
		var deadline:=Time.get_ticks_msec()+4000
		while not probe.captured and Time.get_ticks_msec()<deadline:await physics_frame
		u.set_physics_process(false)
		check(u.position.distance_to(origin)>2.0 and u.animation_direction==row.d,"real physics chooses pudao walking facing "+String(row.d))
		check(probe.captured and probe.seen.size()==4,"real motion traverses all four authored gait phases "+String(row.d))
		u.queue_redraw();await snap("real_walk_"+String(row.d));check(u._frame_directional,"real walking renderer uses authored facing "+String(row.d))
		check(u.art_variant==fixture_skin,"walking never changes saved variant "+String(row.d))
		runtime.append({"actual_gait_direction":row.d,"observed_phase_indices":probe.seen.duplicate(),"manual_phase_sampling":false,"fixture_skin":fixture_skin,"fixture_context":fixture_context});probe.queue_free()
	b.units.erase(u);u.queue_free();await process_frame

func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")));verify_packed_textures();await identity_ui()
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	check(b.level.id()=="level1","actual current Huangnigang chapter loads")
	var npc=b.find_unit("liu_tang")
	check(is_instance_valid(npc) and npc.art_variant=="hn_liu_tang" and npc.setup_def.abilities.is_empty() and not npc.is_ranged,"actual merchant role retains explicit variant and empty kit")
	check(npc.atk_range==26 and npc.max_hp==210,"chapter inherits corrected close reach and existing base health")
	var merchant: Array=art.unit_anim_frames("liu_tang","walk","se",npc.art_variant)
	check(not merchant.is_empty() and merchant!=art.unit_anim_frames("liu_tang","walk","se",""),"merchant body never borrows ordinary russet coat")
	var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;stage_camera(b,npc);b.select_single(npc,false);await settle()
		check(npc.ui_portrait_texture().resource_path=="res://assets/characters/liu_tang_merchant_20261016/portrait.png" and b.hud._port_tex.texture==npc.ui_portrait_texture(),"actual chapter HUD uses owned standard identity portrait "+str(size.x))
		await snap("actual_merchant_hud_"+str(size.x))
	var merchant_cell:=clear_cell(b);check(merchant_cell.x>=0,"actual chapter unobstructed surface for merchant fixtures")
	if merchant_cell.x<0:quit(3);return
	var merchant_origin: Vector2=b.map.cell_to_world(merchant_cell)
	fixture_skin="hn_liu_tang";fixture_context="current_short";shot_prefix="merchant_"
	await matrix(b,merchant_origin,pack_inputs.merchant);await packed_gait(b,merchant_origin);await real_walk(b,merchant_origin)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,merchant_origin,row.d,row.delta)
	fixture_skin="";shot_prefix=""
	check(art.unit_anim_frames("li_kui","walk","se","hn_liu_tang").is_empty() and art.ui_portrait_texture("li_kui","hn_liu_tang")==null,"foreign owner cannot borrow merchant identity")
	check(art.unit_anim_frames("liu_tang","down","se","hn_liu_tang").is_empty(),"merchant death is not silently repurposed as nonfatal story down")
	check(fingerprint(b)==original and Array(b.map.grid)==grid,"original merchant actors and map unchanged after UI and transient actual-definition fixtures")
	b.queue_free();await process_frame;await process_frame
	# A frozen QA-only Battle subclass selects the actual saved legacy level.
	# Production _ready/map/defs/deploy/start remain untouched, not reconstructed.
	b=load("res://scenes/main.tscn").instantiate()
	b.set_script(load(OS.get_environment("RUAN_LEGACY_SCRIPT")))
	root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
	check(b.level.get_script().resource_path=="res://scripts/levels/level1_huangnigang.gd","actual legacy long Level1 selected by QA factory")
	check(b._gameplay_rng_issue.is_empty(),"legacy actual new-game setup has no RNG stop")
	check(b.get_meta("qa_legacy_mission_adapter",false) and b._official_context.get("mode","")!="campaign","legacy harness supplies mission service without granting official campaign eligibility")
	var legacy_npc=b.find_unit("liu_tang")
	check(is_instance_valid(legacy_npc) and legacy_npc.art_variant=="hn_liu_tang" and legacy_npc.setup_def.abilities.is_empty(),"actual long chapter actor retains merchant definition")
	original=fingerprint(b);grid=Array(b.map.grid).duplicate();var legacy_decor: Array=b.map.decor.duplicate(true)
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;stage_camera(b,legacy_npc);b.select_single(legacy_npc,false);await settle()
		check(legacy_npc.ui_portrait_texture().resource_path=="res://assets/characters/liu_tang_merchant_20261016/portrait.png" and b.hud._port_tex.texture==legacy_npc.ui_portrait_texture(),"actual long HUD stage portrait fits "+str(size.x))
		await snap("legacy_hud_"+str(size.x))
	var legacy_cell:=clear_cell(b);check(legacy_cell.x>=0,"long chapter existing unobstructed fixture surface")
	if legacy_cell.x<0:quit(3);return
	var legacy_origin: Vector2=b.map.cell_to_world(legacy_cell)
	fixture_skin="hn_liu_tang";fixture_context="legacy_long";shot_prefix="legacy_"
	await matrix(b,legacy_origin,pack_inputs.merchant);await packed_gait(b,legacy_origin);await real_walk(b,legacy_origin)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,legacy_origin,row.d,row.delta)
	fixture_skin="";fixture_context="ordinary";shot_prefix=""
	check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==legacy_decor,"long original actors map scenery unchanged by transient fixtures")
	b.queue_free();await process_frame;await process_frame;campaign.skirmish=true
	b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame;b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
	original=fingerprint(b);grid=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true);var cell:=clear_cell(b)
	check(cell.x>=0,"existing unobstructed surface without hiding scenery")
	if cell.x<0:quit(3);return
	var origin: Vector2=b.map.cell_to_world(cell);root.size=Vector2i(1280,720);root.content_scale_size=root.size
	await pudao_skills(b,origin);await pudao_hud(b,origin);await matrix(b,origin,pack_inputs.combat);await packed_gait(b,origin);await real_walk(b,origin)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,origin,row.d,row.delta)
	check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==decor,"existing ordinary units map and scenery unchanged after fixtures")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"fixture_cell":[cell.x,cell.y],"scope":"Actual full PCK. Liu Tang explicit chapter16 shirtless merchant portrait, idle/walk/attack/hurt/death in actual current short and QA-selected unregistered legacy long level, alongside ordinary NE holding-side gait correction and existing physical kit regression. Three sizes/four locales for ordinary UI, three sizes for stage portrait. Frozen controlled fixtures, real movement/hit/hurt/death/fade, explicit pose matrix. Original actors/map/scenery unchanged. Generic optional gameplay defeat is not novel fate. Not full campaign, save continuation, balance, performance, release EXE, live SDK, Steam or all-art acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print("LIU_TANG_MERCHANT ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func pudao_hud(b,origin: Vector2) -> void:
	var u=b.spawn_unit("liu_tang",0,origin);u.set_physics_process(false);u.auto_micro=false
	for i in range(4):u.ability_slots[i].rank=1
	u._recompute_hero_stats();b.select_single(u,false);stage_camera(b,u)
	var localize=root.get_node("Localize")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	for locale in ["zh_CN","zh_TW","en","ja"]:
		localize.set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;b.hud.refresh_command();await settle()
			var label: String=locale+"_"+str(size.x)
			var seen: Array=[]
			for button in b.hud._skill_bar.get_children():
				if button.is_queued_for_deletion() or not button.get_property_list().any(func(p):return String(p.name)=="slot"):continue
				var aid: String=u.ability_slots[button.slot].id
				seen.append(button.slot)
				var tex: Texture2D=button._ability_art_icon(aid)
				check(fits(button) and tex!=null and tex.resource_path=="res://"+String(pack_inputs.skill_icons[aid]),"native pudao icon fits "+label+aid)
				check(button.hotkey==root.get_node("Settings").command_key_labels()[button.slot],"pudao hotkey unchanged "+label+aid)
				var ad: Dictionary=b._abilities[aid]
				check(localize.text(ad.name)==ad.name if locale=="zh_CN" else catalog.has(ad.name) and catalog[ad.name].has(locale) and localize.text(ad.name)==String(catalog[ad.name][locale]),"pudao name matches catalog "+label+aid)
				check(localize.text(ad.desc)==ad.desc if locale=="zh_CN" else catalog.has(ad.desc) and catalog[ad.desc].has(locale) and localize.text(ad.desc)==String(catalog[ad.desc][locale]),"pudao description matches catalog "+label+aid)
				if size.x==960:
					button._on_hover_in();await settle()
					check(fits(b.hud._tip_panel) and b.hud._tip_title.text==localize.text(ad.name),"real localized pudao hover card fits "+label+aid)
					check(not "{v}" in b.hud._tip_body.text and not ["血怒","赤血祭","嗜血","裂血","blood sacrifice","lifesteal","blood magic","吸血","血祭"].any(func(term):return term in b.hud._tip_body.text),"actual pudao tooltip resolves values without old supernatural text "+label+aid)
					await snap("pudao_tooltip_"+label+aid);button._on_hover_out();await process_frame
			check(seen==[0,1,2,3],"pudao four slots visible "+label)
			await snap("pudao_hud_"+label)
	localize.set_language("zh_CN",false);b.units.erase(u);u.queue_free();await process_frame

func pudao_skills(b,origin: Vector2) -> void:
	var graph=load("res://scripts/run_visual_graph.gd").new(load("res://scripts/run_state_value_codec.gd"),b.get_script(),load("res://scripts/unit.gd"))
	var baseline_wards: int=b._wards.size();var baseline_dots: int=b._ground_dots.size()
	for direction in ["se","sw","ne","nw"]:
		var delta: Vector2={"se":Vector2.RIGHT,"sw":Vector2.DOWN,"ne":Vector2.UP,"nw":Vector2.LEFT}[direction]
		for rank in [1,2,3]:
			var u=b.spawn_unit("liu_tang",0,origin);u.auto_micro=false;u.set_physics_process(false);u.animation_direction=direction
			for i in range(4):u.ability_slots[i].rank=rank;u.ability_slots[i].cd_t=0.0
			u._recompute_hero_stats();u._cd=100.0
			check(is_equal_approx(u.max_hp,210) and is_equal_approx(u.atk,22+2*rank) and is_equal_approx(u.base_speed,86),"ranked E retains attack only and base speed unchanged "+direction+str(rank))
			var steal: Dictionary=u.lifesteal_frac()
			check(steal.ok and is_zero_approx(steal.value) and not u.slot_ready(2),"E noncastable with no lifesteal "+direction+str(rank))
			for aid in ["liu_tang_w","liu_tang_r","liu_cleave"]:
				check(is_equal_approx(b._scaled_ability(b._abilities[aid],1.8,1.5).radius,b._abilities[aid].radius),"hero multipliers cannot extend physical reach "+direction+str(rank)+aid)
			var near=b.spawn_unit("guan_dao",1,origin+delta*24.0);var far=b.spawn_unit("guan_dao",1,origin+delta*105.0);var ally=b.spawn_unit("guan_dao",0,origin+delta.rotated(PI/2.0)*20.0)
			for actor in [near,far,ally]:actor.set_physics_process(false);actor.max_hp=1000;actor.hp=1000
			b.select_single(u,false);stage_camera(b,u)
			for slot in [0,1,3]:
				var aid: String=u.ability_slots[slot].id
				var label: String=direction+"_r"+str(rank)+"_"+aid
				near.position=origin+delta*24.0;near.hp=1000;near._stun_t=0;near.temp_speed=1.0;near._temp_speed_t=0
				near._silence_t=0;near._dmg_amp=0;near._dmg_amp_t=0
				u.ability_slots[slot].cd_t=0.0;u.animation_direction=direction;u._cd=100.0
				var old_fx: Array=b.fx_root.get_children();var before: float=near.hp
				b.cast_ability(u,slot)
				check(b.is_cast_pending(u,slot) and u._cast_t>0 and u.animation_direction==direction,"production windup begins in requested direction "+label)
				check(native_frame(u,"attack")==art.unit_anim_frames("liu_tang","attack",direction,"")[0],"physical skill windup uses authored ready pose "+label)
				u.set_physics_process(true)
				var deadline:=Time.get_ticks_msec()+2500
				while u.ability_slots[slot].cd_t<=0.0 and Time.get_ticks_msec()<deadline:
					await physics_frame;b._tick_pending_casts()
				u.set_physics_process(false)
				check(u.ability_slots[slot].cd_t>0 and b._ability_armed.is_empty(),"self cast settles and starts cooldown "+label)
				check(is_equal_approx(u.slot_cd(slot),10.0 if slot==0 else 12.0 if slot==1 else 30.0),"retained ranked cooldown "+label)
				check(far.hp==1000 and ally.hp==1000,"far enemy and nearby ally unharmed "+label)
				check(is_zero_approx(near._silence_t) and is_zero_approx(near._dmg_amp),"no magical silence or wound amplification "+label)
				if slot==0:
					check(near.hp==before and is_equal_approx(u.temp_atkspeed,1.5) and is_equal_approx(u.temp_atk,1.3) and u._temp_atkspeed_t>8.9 and u._temp_atk_t>8.9,"Q personal attack/speed buff only "+label)
				elif slot==1:
					check(near.hp<before and is_equal_approx(near.temp_speed,1.0) and is_zero_approx(near._stun_t),"W close cut without former blood rune or silence "+label)
				else:
					check(near.hp<before and is_equal_approx(near.temp_speed,0.5) and is_equal_approx(near._temp_speed_t,3.0),"R close chop retains three-second slow "+label)
				if slot in [1,3]:
					check(u._pending_done and is_equal_approx(u._lunge,0.48) and native_frame(u,"attack")==art.unit_anim_frames("liu_tang","attack",direction,"")[4],"settled chop strike without ordinary hit queued "+label)
				check(b._wards.size()==baseline_wards and b._ground_dots.size()==baseline_dots,"no autonomous ward or persistent damage "+label)
				var added: Array=b.fx_root.get_children().filter(func(fx):return not old_fx.has(fx))
				var motion: Array=added.filter(func(fx):return graph._kind(fx)=="staff_motion")
				check(motion.size()==1 and not added.any(func(fx):return fx.get_script() in [b.PoisonCloudFx,b.FlameburstFx,b.AbilityProjectileFx,b.AbilityFx,b.AbilityImpactFx]),"physical dust replaces blood magic/projectile "+label)
				if motion.size()==1:
					var fx=motion[0];fx.set_process(false);fx.t=0.14
					var values: Dictionary=graph._values(fx,"staff_motion")
					check(graph._values_check(values,"staff_motion").ok,"actual dust FX fields validate "+label)
					var copy=graph._new("staff_motion");copy.set_meta("_run_restore_prepared",true)
					for field in values:copy.set(field,values[field])
					b.fx_root.add_child(copy);copy.set_process(false)
					check(graph._kind(copy)=="staff_motion" and graph._values(copy,"staff_motion")==values,"dust FX partial field roundtrip "+label)
					copy.queue_free();await process_frame
					if rank==1:await snap("pudao_cast_"+label)
					fx.set_process(true)
				if slot in [1,3]:
					var settled_hp: float=near.hp
					u.set_physics_process(true)
					for tick in range(20):await physics_frame
					u.set_physics_process(false)
					check(near.hp==settled_hp and is_zero_approx(u._lunge),"followthrough expires without second damage "+label)
				if slot==0 and direction=="se":
					u._cd=100;u.set_physics_process(true);deadline=Time.get_ticks_msec()+11000
					while (u._temp_atkspeed_t>0 or u._temp_atk_t>0) and Time.get_ticks_msec()<deadline:await physics_frame
					u.set_physics_process(false);check(is_equal_approx(u.temp_atkspeed,1.0) and is_equal_approx(u.temp_atk,1.0),"actual nine-second personal buff expires "+label)
				runtime.append({"pudao_cast":aid,"direction":u.animation_direction,"requested_direction":direction,"rank":rank,"damage":before-near.hp,"ward_count":b._wards.size(),"ground_dot_count":b._ground_dots.size()})
			for actor in [u,near,far,ally]:b.units.erase(actor);actor.queue_free()
			await process_frame
	# Explicit legacy-slot fixture: normal selection has the retained Q/W/E/R IDs.
	var u=b.spawn_unit("liu_tang",0,origin);u.auto_micro=false;u.set_physics_process(false);u._cd=100
	u.ability_slots[0].id="liu_cleave";u.ability_slots[0].rank=1;u.ability_slots[0].cd_t=0
	var foe=b.spawn_unit("guan_dao",1,origin+Vector2.RIGHT*24);foe.set_physics_process(false);foe.hp=1000;foe.max_hp=1000
	b.select_single(u,false);b.cast_ability(u,0);var deadline:=Time.get_ticks_msec()+2500
	u.set_physics_process(true)
	while u.ability_slots[0].cd_t<=0 and Time.get_ticks_msec()<deadline:await physics_frame;b._tick_pending_casts()
	u.set_physics_process(false)
	check(foe.hp<1000 and is_equal_approx(foe.temp_speed,0.5) and is_equal_approx(u.slot_cd(0),8.0),"legacy pu dao self cast retains damage/slow/cooldown with fixed close reach")
	check(String(b._abilities.liu_cleave.visual.delivery)=="staff","legacy path has physical presentation too")
	for actor in [u,foe]:b.units.erase(actor);actor.queue_free()
	await process_frame;graph=null
