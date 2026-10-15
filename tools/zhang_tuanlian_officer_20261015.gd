extends SceneTree
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
			frame=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("zhang_tuanlian","",actor.animation_direction))
			actor.set_physics_process(false)
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured:=false
	var timer:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var frame: Texture2D=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("zhang_tuanlian","",actor.animation_direction))
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
	var base: Texture2D=art.unit_texture("zhang_tuanlian","",u.animation_direction)
	if state=="death":
		var frames: Array=art.unit_anim_frames("zhang_tuanlian","death",u.animation_direction,"")
		return frames[mini(int(u._death_t/u.DEATH_DUR*frames.size()),frames.size()-1)]
	return u._anim_frame_for_state(base)
func exercise(b,origin: Vector2,direction: String,delta: Vector2) -> void:
	var u=b.spawn_unit("zhang_tuanlian",1,origin)
	var target=b.spawn_unit("guan_dao",0,origin+delta*24.0)
	check(u!=null and target!=null,"real ordinary unit definitions exist "+direction)
	if u==null or target==null:return
	target.set_physics_process(false)
	u.auto_micro=false;u.animation_direction=direction
	check(u.setup_def.get("atk",-1)==42 and u.max_hp==1000 and u.atk_cd==0.9 and u.atk_range==28 and u.base_speed==96 and not u.is_cavalry,"ordinary combat stats retained "+direction)
	check(u.setup_def.get("abilities",[]).is_empty() and u.art_variant.is_empty(),"ordinary officer has no invented active skills "+direction)
	var identity: int=u.entity_id
	stage_camera(b,u);b._set_inspect(u)
	var hit:=HitProbe.new();hit.actor=u;hit.target=target;hit.prior_hp=target.hp;hit.process_physics_priority=1000;root.add_child(hit)
	u.order_attack(target,false,true)
	var deadline:=Time.get_ticks_msec()+6000
	while not hit.captured and Time.get_ticks_msec()<deadline:await physics_frame
	var attack: Array=art.unit_anim_frames("zhang_tuanlian","attack",direction,"")
	var slot:=clampi(int((1.0-u._hit_at)*attack.size()),0,attack.size()-1)
	check(hit.captured and target.hp<hit.prior_hp,"real normal melee damage "+direction)
	check(hit.captured and hit.frame==attack[slot] and slot==4,"actual hit uses authored strike pose "+direction)
	check(is_equal_approx(u._swing_speed,2.8) and is_equal_approx(u._hit_at,0.45),"existing attack timing retained "+direction)
	check(u.animation_direction==direction and u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(),"native facing without double swing "+direction)
	await snap("actual_hit_"+direction)
	var dealt: float=hit.prior_hp-target.hp
	hit.queue_free()
	u.set_physics_process(false);u.order_stop()
	var before_hp: float=u.hp
	u.take_damage(7,target,false,true)
	var hurt: Array=art.unit_anim_frames("zhang_tuanlian","hurt",direction,"")
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
		runtime.append({"direction":direction,"melee_damage":dealt,"hit_slot":slot,"recovery_seen":recovered,"death_indices":death.seen.duplicate(),"terminal_time":sampled_time,"ordinary_fixture":true,"actor_faction":1,"command_path":"controlled Unit.order_attack; not AI or player enemy commands"})
	death.queue_free()
	if is_instance_valid(target):b.units.erase(target);target.queue_free()
	await process_frame
func matrix(b,origin: Vector2,manifest: Dictionary) -> void:
	var u=b.spawn_unit("zhang_tuanlian",0,origin);u.set_physics_process(false);u.auto_micro=false
	stage_camera(b,u);b.select_single(u,false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await process_frame;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["attack","hurt","death"]:
				var frames: Array=art.unit_anim_frames("zhang_tuanlian",state,d,"")
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
			var frames: Array=art.unit_anim_frames("zhang_tuanlian",state,d,"")
			check(frames.size()==(1 if state=="idle" else 4) and frames[0].atlas.resource_path.begins_with("res://assets/characters/zhang_tuanlian_officer_20261015/"),"officer gait bound "+state+d)
	b.units.erase(u);u.queue_free();await process_frame
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
func packed_gait(b,origin: Vector2) -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await process_frame
	var u=b.spawn_unit("zhang_tuanlian",0,origin);u.set_physics_process(false);stage_camera(b,u);b.select_single(u,false)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("zhang_tuanlian",state,d,"")
			for index in range(frames.size()):
				u._move_blend=1.0 if state=="walk" else 0.0;u._anim_t=TAU*(float(index)+.1)/float(frames.size());u._idle_t=0
				var pose: Dictionary=pack_inputs.gait.poses[String(pack_inputs.gait.states[state][index])+"_"+d]
				check(native_frame(u,state)==frames[index] and frames[index].region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"packed Unit selects officer gait pose "+state+d+str(index))
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
	var portrait: Texture2D=art.portrait_texture("zhang_tuanlian")
	check(portrait!=null and portrait.resource_path=="res://assets/characters/zhang_tuanlian_officer_20261015/portrait.png","officer bearded cloth portrait resolved")
	check(art.ui_portrait_texture("zhang_tuanlian","jiang_menshen_fists")==null,"foreign portrait owner remains rejected")
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("zhang_tuanlian")
		for index in range(4):
			codex._on_direction_selected(index);await settle();var d: String=["se","sw","ne","nw"][index]
			check(codex._port.frames==[portrait] and fits(codex._port),"real codex officer portrait fits "+str(size.x)+d)
			check(codex._walk.frames==art.unit_anim_frames("zhang_tuanlian","walk",d) and codex._atk.frames==art.unit_anim_frames("zhang_tuanlian","attack",d),"real codex matching cloth bodies "+str(size.x)+d)
			await snap("codex_zhang_tuanlian_"+str(size.x)+"_"+d)
		if size.x==960:
			codex._detail_scroll.scroll_vertical=320;await settle();check(fits(codex._atk),"narrow officer attack preview scrolls fully into view");await snap("codex_zhang_tuanlian_960_attack_scrolled")
	root.get_node("Localize").set_language("en",false);codex._select("zhang_tuanlian");await settle();await snap("codex_zhang_tuanlian_en_1920")
	check(codex._port.frames==[portrait],"English officer portrait");root.get_node("Localize").set_language("zh_CN",false)
	for other in ["shi_en","jiang_menshen","zhang_tuanlian"]:
		codex._select(other);await settle()
		check(codex._port.frames==[art.portrait_texture(other)],"distinct real codex portrait "+other)
		await snap("codex_identity_compare_"+other)
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size;root.content_scale_size=size;codex._select("zhang_tuanlian");await settle();codex._show_lore();await create_timer(0.3).timeout;await settle()
			check(codex._lore_text.text==root.get_node("Localize").text(LoreData.LORE["zhang_tuanlian"]),"actual localized full officer lore "+locale+str(size.x))
			check(["29","30","31"].all(func(n):return n in codex._lore_source.text) and fits(codex._lore_source),"actual original chapter references visible "+locale+str(size.x))
			await snap("officer_lore_"+locale+"_"+str(size.x))
			codex._lore_scroll.scroll_vertical=10000;await settle();await snap("officer_lore_end_"+locale+"_"+str(size.x));codex._hide_lore();await create_timer(0.3).timeout
	root.get_node("Localize").set_language("zh_CN",false)
	codex.queue_free();await process_frame

func real_walk(b,origin: Vector2) -> void:
	var u=b.spawn_unit("zhang_tuanlian",0,origin);u.set_physics_process(false);u.auto_micro=false;b.select_single(u,false);stage_camera(b,u)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop();u.set_physics_process(true);u.order_move(origin+row.delta*52.0)
		for tick in range(12):await physics_frame
		u.set_physics_process(false);check(u.position.distance_to(origin)>2.0 and u.animation_direction==row.d,"real physics chooses officer walking facing "+String(row.d))
		u.queue_redraw();await snap("real_walk_"+String(row.d));check(u._frame_directional,"real walking renderer uses authored facing "+String(row.d))
		check(u.art_variant.is_empty(),"walking never changes saved variant "+String(row.d))
	b.units.erase(u);u.queue_free();await process_frame

func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")));verify_packed_textures();await identity_ui()
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=6;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	check(b.level.id()=="level7","existing original Level7 still loads")
	var npc=b.level.shi
	check(npc.key=="shi_en" and npc.setup_def.atk==0 and npc.setup_def.noncombat and npc.setup_def.abilities.is_empty(),"unrelated original Shi En stays noncombat with empty skills")
	var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate()
	stage_camera(b,npc);b.select_single(npc,false);await settle()
	check(npc.ui_portrait_texture()==art.portrait_texture("shi_en") and npc.ui_portrait_texture()!=art.portrait_texture("zhang_tuanlian"),"original NPC cannot receive new officer portrait")
	await snap("original_level7_shi_en_unchanged")
	check(fingerprint(b)==original and Array(b.map.grid)==grid,"original story actors and map unchanged")
	b.queue_free();await process_frame;await process_frame;campaign.skirmish=true
	b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame;b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b);b.fog=false
	original=fingerprint(b);grid=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true);var cell:=clear_cell(b)
	check(cell.x>=0,"existing unobstructed surface without hiding scenery")
	if cell.x<0:quit(3);return
	var origin: Vector2=b.map.cell_to_world(cell);root.size=Vector2i(1280,720);root.content_scale_size=root.size
	await officer_hud(b,origin);await matrix(b,origin,pack_inputs.combat);await packed_gait(b,origin);await real_walk(b,origin)
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:await exercise(b,origin,row.d,row.delta)
	check(fingerprint(b)==original and Array(b.map.grid)==grid and b.map.decor==decor,"existing ordinary units map and scenery unchanged after fixtures")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"fixture_cell":[cell.x,cell.y],"scope":"Actual full resource PCK: 15 native ordinary officer body atlases and portrait, conservative game design with original chapter29–31 lore boundary. Real codex four directions/three sizes, four-language lore panel, three-size actual HUD and explicit shared dialogue portrait fixtures; original Level7 Shi En regression. Real ordinary movement/hit/hurt/death/fade, original participants and Battle frozen, fog disabled only in ordinary fixtures. Explicit pose matrix. No implemented chapter31 banquet/chair/death scene, pointer full chapter, full restore, normal performance, balance, release EXE, live SDK, Steam or whole art completion."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print("ZHANG_TUANLIAN_OFFICER ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func officer_hud(b,origin: Vector2) -> void:
	var u=b.spawn_unit("zhang_tuanlian",1,origin);u.set_physics_process(false);stage_camera(b,u);b._set_inspect(u)
	var p: Texture2D=art.portrait_texture("zhang_tuanlian")
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;await settle()
		check(u.ui_portrait_texture()==p and b.hud._port_tex.texture==p and fits(b.hud._port_tex),"actual officer HUD portrait "+str(size.x))
		await snap("officer_hud_"+str(size.x))
		# Deliberate shared-dialogue UI fixture, not an authored or newly implemented plot.
		b.hud.show_intro([{"who":"张团练","key":"zhang_tuanlian","text":"张团练。孟州团练，勾结蒋门神，构陷武松。"}]);await settle()
		check(b.hud._intro_port_tex.texture==p and fits(b.hud._intro_port_tex),"shared dialogue portrait fixture "+str(size.x))
		await snap("officer_dialogue_fixture_"+str(size.x));b.hud._intro_root.hide()
	b._set_inspect(null);b.units.erase(u);u.queue_free();await process_frame
