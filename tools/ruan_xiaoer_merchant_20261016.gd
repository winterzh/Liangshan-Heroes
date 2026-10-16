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
			frame=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("ruan_xiaoer",actor.visual_art_variant(),actor.animation_direction))
			actor.set_physics_process(false)
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured:=false
	var timer:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var frame: Texture2D=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("ruan_xiaoer",actor.visual_art_variant(),actor.animation_direction))
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
const SCOPE := "Actual full PCK explicit hn_ruan_xiaoer chapter16 shirtless, barefoot merchant portrait and five-state four-direction pu-dao body in current short and QA-selected unregistered legacy long chapter. Three sizes and four locales of actual stage HUD. Original generic ruan_brother alias target, other Ruan portraits, definitions, skills, actors/map/scenery retained. Frozen fixtures, explicit phase matrix and separately real movement/hit/hurt/death/fade. Not ordinary group redesign, carry/boat, full chapter/campaign/save/balance/performance/release EXE/live SDK/Steam or all-art acceptance."
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
	var base: Texture2D=art.unit_texture("ruan_xiaoer",u.visual_art_variant(),u.animation_direction)
	if state=="death":
		var frames: Array=art.unit_anim_frames("ruan_xiaoer","death",u.animation_direction,u.visual_art_variant())
		return frames[mini(int(u._death_t/u.DEATH_DUR*frames.size()),frames.size()-1)]
	return u._anim_frame_for_state(base)
func exercise(b,origin: Vector2,direction: String,delta: Vector2) -> void:
	var u=b.spawn_unit("ruan_xiaoer",0,origin)
	var target=b.spawn_unit("guan_dao",1,origin+delta*24.0)
	check(u!=null and target!=null,"real stage unit definitions exist "+direction)
	if u==null or target==null:return
	target.set_physics_process(false)
	u.auto_micro=false;u.animation_direction=direction
	check(u.setup_def.get("atk",-1)==14 and u.max_hp==130 and u.atk_cd==0.9 and u.atk_range==26 and not u.is_ranged and u._weapon_kind()==u.WK.SWORD and u.base_speed==92,"existing stage melee definition retained "+direction)
	check(u.setup_def.get("abilities",[]).is_empty() and u.art_variant==fixture_skin,"stage empty skill identity retained "+direction)
	u.hp=100.0;u._combat_cool=6.0
	var identity: int=u.entity_id
	stage_camera(b,u);b.select_single(u,false)
	var hit:=HitProbe.new();hit.actor=u;hit.target=target;hit.prior_hp=target.hp;hit.process_physics_priority=1000;root.add_child(hit)
	u.order_attack(target,false,true)
	var deadline:=Time.get_ticks_msec()+6000
	while not hit.captured and Time.get_ticks_msec()<deadline:await physics_frame
	var attack: Array=art.unit_anim_frames("ruan_xiaoer","attack",direction,fixture_skin)
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
	var hurt: Array=art.unit_anim_frames("ruan_xiaoer","hurt",direction,fixture_skin)
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
	var u=b.spawn_unit("ruan_xiaoer",0,origin);u.set_physics_process(false);u.auto_micro=false
	stage_camera(b,u);b.select_single(u,false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await process_frame;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["attack","hurt","death"]:
				var frames: Array=art.unit_anim_frames("ruan_xiaoer",state,d,fixture_skin)
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
			var frames: Array=art.unit_anim_frames("ruan_xiaoer",state,d,fixture_skin)
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
	var u=b.spawn_unit("ruan_xiaoer",0,origin);u.set_physics_process(false);stage_camera(b,u);b.select_single(u,false)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("ruan_xiaoer",state,d,fixture_skin)
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

func real_walk(b,origin: Vector2) -> void:
	var u=b.spawn_unit("ruan_xiaoer",0,origin);u.set_physics_process(false);u.auto_micro=false;b.select_single(u,false);stage_camera(b,u)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop()
		var probe:=WalkProbe.new();probe.actor=u;probe.frames=art.unit_anim_frames("ruan_xiaoer","walk",row.d,fixture_skin);probe.process_physics_priority=1000;root.add_child(probe)
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

func stage_hud(b,npc,label: String) -> void:
	var localize=root.get_node("Localize")
	for locale in ["zh_CN","zh_TW","en","ja"]:
		localize.set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;stage_camera(b,npc);b.select_single(npc,false);b.hud.refresh_command();await settle()
			check(npc.ui_portrait_texture().resource_path=="res://assets/characters/ruan_xiaoer_merchant_20261016/portrait.png" and b.hud._port_tex.texture==npc.ui_portrait_texture() and fits(b.hud._port_tex),"owned stage portrait fits "+label+locale+str(size.x))
			check(npc.setup_def.abilities.is_empty() and npc.ability_slots.is_empty(),"chapter empty kit retained "+label+locale+str(size.x))
			await snap(label+"_hud_"+locale+"_"+str(size.x))
	localize.set_language("zh_CN",false)
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")));verify_packed_textures()
	var generic_portrait: Texture2D=art.portrait_texture("ruan_brother")
	var generic_walk: Array=art.unit_anim_frames("ruan_brother","walk","se","")
	check(generic_portrait!=null and not generic_walk.is_empty() and generic_walk[0].atlas.resource_path=="res://assets/anim/ruan_brother_walk.png","generic group retains legacy portrait and walk source")
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	for legacy in [false,true]:
		var b=load("res://scenes/main.tscn").instantiate()
		if legacy:b.set_script(load(OS.get_environment("RUAN_LEGACY_SCRIPT")))
		root.add_child(b);current_scene=b;await process_frame;b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
		if legacy:
			check(b.level.get_script().resource_path=="res://scripts/levels/level1_huangnigang.gd" and b.get_meta("qa_legacy_mission_adapter",false) and b._official_context.get("mode","")!="campaign","unregistered legacy QA selection retains custom eligibility")
		else:check(b.level.id()=="level1","actual current short chapter selected")
		check(b._gameplay_rng_issue.is_empty(),"actual chapter RNG setup completes")
		var npc=b.find_unit("ruan_xiaoer")
		check(is_instance_valid(npc) and npc.art_variant=="hn_ruan_xiaoer" and npc.max_hp==130 and npc.atk==14 and npc.atk_cd==0.9 and npc.atk_range==26 and npc.base_speed==92 and npc.setup_def.abilities.is_empty(),"actual stage definition and base stats retained")
		check(art._ra("ruan_xiaoer")=="ruan_brother","existing runtime group alias retained")
		var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true)
		fixture_skin="hn_ruan_xiaoer";fixture_context="legacy_long" if legacy else "current_short";shot_prefix="legacy_" if legacy else "merchant_"
		await stage_hud(b,npc,"stage")
		var cell:=clear_cell(b);check(cell.x>=0,"existing unobstructed stage fixture surface")
		if cell.x<0:quit(3);return
		var origin: Vector2=b.map.cell_to_world(cell)
		await matrix(b,origin,pack_inputs.merchant);await packed_gait(b,origin);await real_walk(b,origin)
		for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,origin,row.d,row.delta)
		check(art.unit_anim_frames("ruan_brother","walk","se",fixture_skin).is_empty() and art.ui_portrait_texture("ruan_brother",fixture_skin)==null,"generic alias target cannot borrow individual stage identity")
		check(art.unit_anim_frames("ruan_xiaowu","walk","se",fixture_skin).is_empty() and art.ui_portrait_texture("ruan_xiaoqi",fixture_skin)==null,"other brothers cannot borrow Ruan2 identity")
		check(art.unit_anim_frames("ruan_xiaoer","down","se",fixture_skin).is_empty(),"generic defeat not reused for nonfatal story down")
		check(art.portrait_texture("ruan_brother")==generic_portrait and art.unit_anim_frames("ruan_brother","walk","se","")==generic_walk,"generic group identity stays unchanged with runtime alias active")
		check(art.ui_portrait_texture("ruan_xiaowu","hn_ruan_xiaowu").resource_path=="res://assets/characters/ruan_xiaowu_merchant_20261016/portrait.png" and art.ui_portrait_texture("ruan_xiaoqi","hn_ruan_xiaoqi").resource_path=="res://assets/characters/ruan_xiaoqi_merchant_20261016/portrait.png","other Ruan stage portraits remain distinct")
		check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==decor,"original actors map and scenery retained after transient fixtures")
		b.queue_free();await process_frame;await process_frame
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"scope":SCOPE}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print("RUAN_XIAOER_MERCHANT ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
