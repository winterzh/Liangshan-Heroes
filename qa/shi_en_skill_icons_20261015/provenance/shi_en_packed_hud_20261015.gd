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
			frame=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("shi_en","",actor.animation_direction))
			actor.set_physics_process(false)
class RecoveryProbe extends Node:
	var actor
	var expected: Texture2D
	var captured:=false
	var timer:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var frame: Texture2D=actor._anim_frame_for_state(get_tree().root.get_node("Art").unit_texture("shi_en","",actor.animation_direction))
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
	var base: Texture2D=art.unit_texture("shi_en","",u.animation_direction)
	if state=="death":
		var frames: Array=art.unit_anim_frames("shi_en","death",u.animation_direction,"")
		return frames[mini(int(u._death_t/u.DEATH_DUR*frames.size()),frames.size()-1)]
	return u._anim_frame_for_state(base)
func exercise(b,origin: Vector2,direction: String,delta: Vector2) -> void:
	var u=b.spawn_unit("shi_en",0,origin)
	var target=b.spawn_unit("guan_dao",1,origin+delta*24.0)
	check(u!=null and target!=null,"real ordinary unit definitions exist "+direction)
	if u==null or target==null:return
	target.set_physics_process(false)
	u.auto_micro=false;u.animation_direction=direction
	check(u.setup_def.get("atk",-1)==15 and u.max_hp==210 and u.atk_cd==0.95 and u.atk_range==26 and u.base_speed==80,"ordinary combat stats retained "+direction)
	check(u.setup_def.get("abilities",[]).size()==4 and u.art_variant.is_empty(),"ordinary four-skill identity retained "+direction)
	var identity: int=u.entity_id
	stage_camera(b,u);b.select_single(u,false)
	var hit:=HitProbe.new();hit.actor=u;hit.target=target;hit.prior_hp=target.hp;hit.process_physics_priority=1000;root.add_child(hit)
	u.order_attack(target,false,true)
	var deadline:=Time.get_ticks_msec()+6000
	while not hit.captured and Time.get_ticks_msec()<deadline:await physics_frame
	var attack: Array=art.unit_anim_frames("shi_en","attack",direction,"")
	var slot:=clampi(int((1.0-u._hit_at)*attack.size()),0,attack.size()-1)
	check(hit.captured and target.hp<hit.prior_hp,"real normal melee damage "+direction)
	check(hit.captured and hit.frame==attack[slot] and slot==4,"actual hit uses authored strike pose "+direction)
	check(is_equal_approx(u._swing_speed,2.1) and is_equal_approx(u._hit_at,0.48),"existing attack timing retained "+direction)
	check(u.animation_direction==direction and u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()) and not u._should_draw_programmatic_swing_fx(),"native facing without double swing "+direction)
	await snap("actual_hit_"+direction)
	var dealt: float=hit.prior_hp-target.hp
	hit.queue_free()
	u.set_physics_process(false);u.order_stop()
	var before_hp: float=u.hp
	u.take_damage(7,target,false,true)
	var hurt: Array=art.unit_anim_frames("shi_en","hurt",direction,"")
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
		runtime.append({"direction":direction,"melee_damage":dealt,"hit_slot":slot,"recovery_seen":recovered,"death_indices":death.seen.duplicate(),"terminal_time":sampled_time,"ordinary_fixture":true})
	death.queue_free()
	if is_instance_valid(target):b.units.erase(target);target.queue_free()
	await process_frame
func matrix(b,origin: Vector2,manifest: Dictionary) -> void:
	var u=b.spawn_unit("shi_en",0,origin);u.set_physics_process(false);u.auto_micro=false
	stage_camera(b,u);b.select_single(u,false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await process_frame;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["attack","hurt","death"]:
				var frames: Array=art.unit_anim_frames("shi_en",state,d,"")
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
					u.queue_redraw();await snap(str(size.x)+"x"+str(size.y)+"_"+phase+"_"+d)
	# Existing gait is checked against the exact previously adopted source family.
	u._dying=false;u._lunge=0;u._shi_en_hurt_t=0;u._flinch=Vector2.ZERO
	for d in ["se","sw","ne","nw"]:
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("shi_en",state,d,"")
			check(frames.size()==(1 if state=="idle" else 4) and frames[0].atlas.resource_path.begins_with("res://assets/characters/shi_en_gait_runtime_20261015/"),"previously adopted gait preserved "+state+d)
	b.units.erase(u);u.queue_free();await process_frame
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art")
	pack_inputs=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")))
	verify_packed_textures()
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=6;root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame
	check(b.level.id()=="level7","original Level7 scene")
	var npc=b.level.shi
	check(npc.setup_def.atk==0 and npc.setup_def.noncombat and npc.setup_def.abilities.is_empty(),"original Level7 noncombat Shi En retained")
	freeze(b)
	var original:=fingerprint(b);var grid: Array=Array(b.map.grid).duplicate()
	stage_camera(b,npc);b.select_single(npc,false);await snap("original_noncombat_shi_en")
	check(fingerprint(b)==original and Array(b.map.grid)==grid,"original Level7 NPCs and terrain unchanged")
	b.queue_free();await process_frame;await process_frame
	# Combat belongs to the real ordinary skirmish definitions, rather than
	# changing the original chapter NPC's atk=0/noncombat definition.
	campaign.skirmish=true
	b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame
	freeze(b);b.fog=false
	check(int(b._defs.shi_en.atk)==15 and b._defs.has("guan_dao"),"real skirmish ordinary combat definitions")
	original=fingerprint(b);grid=Array(b.map.grid).duplicate()
	var original_decor: Array=b.map.decor.duplicate(true)
	var cell:=clear_cell(b)
	check(cell.x>=0,"existing unobstructed skirmish surface")
	if cell.x<0:quit(3);return
	var origin: Vector2=b.map.cell_to_world(cell)
	var directions: Array=[{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]
	for row in directions:await exercise(b,origin,row.d,row.delta)
	var manifest: Dictionary=pack_inputs.combat
	await matrix(b,origin,manifest)
	await packed_gait(b,origin)
	await hud_layout_cases(b,origin)
	check(fingerprint(b)==original and Array(b.map.grid)==grid,"all original skirmish units and terrain unchanged after controlled fixtures")
	check(b.map.decor==original_decor,"original scenery retained and not hidden or moved")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"runtime":runtime,"hud_events":hud_events,"fixture_cell":[cell.x,cell.y],
		"scope":"Original Level7 unchanged noncombat NPC, then real skirmish ordinary definitions with explicitly spawned combat fixtures. Real normal melee damage, incoming-damage impact/recovery physics and lethal/death/fade callbacks. Frozen original participants and Battle simulation, fog hidden for fixture visibility; explicit pose sampling at three sizes. Loaded actual full resource PCK from clean runtime without source PNGs; imported texture data matched source-import references. Hero HUD layout and Viewport button events checked. No world-pointer/full-chapter/release-EXE/live-SDK/Steam/full-art acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("SHI_EN_PACKED_HUD ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func verify_packed_textures() -> void:
	var references: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(references.size()==pack_inputs.textures.size(),"all character and skill native sources referenced")
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
	var u=b.spawn_unit("shi_en",0,origin);u.set_physics_process(false);stage_camera(b,u);b.select_single(u,false)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["idle","walk"]:
			var frames: Array=art.unit_anim_frames("shi_en",state,d,"")
			for index in range(frames.size()):
				u._move_blend=1.0 if state=="walk" else 0.0;u._anim_t=TAU*(float(index)+.1)/float(frames.size());u._idle_t=0
				var pose: Dictionary=pack_inputs.gait.poses[String(pack_inputs.gait.states[state][index])+"_"+d]
				check(native_frame(u,state)==frames[index] and frames[index].region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"packed Unit selects original gait pose "+state+d+str(index))
				u.queue_redraw()
				if index==0:await snap("packed_gait_"+state+"_"+d)
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
func click(control: Control,point: Vector2,label: String) -> void:
	check(fits(control) and control.get_global_rect().has_point(point),"actual UI hit area inside viewport "+label)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true);await process_frame
	await settle()
	hud_events.append({"label":label,"point":[point.x,point.y],"kind":"real Viewport GUI events"})
func hud_layout_cases(b,origin: Vector2) -> void:
	var u=b.spawn_unit("shi_en",0,origin);u.set_physics_process(false);b.select_single(u,false);stage_camera(b,u)
	var identity: int=u.entity_id;var hp: float=u.hp
	var localize=root.get_node("Localize")
	for locale in ["zh_CN","en"]:
		localize.set_language(locale,false)
		check(localize.locale==locale,"requested language is actually active "+locale)
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
			root.size=size;root.content_scale_size=size;await settle()
			var label: String=String(locale)+"_"+str(size.x)+"x"+str(size.y)
			check(b.hud._desktop_hero_dense==(size.x<1100),"resize selects and restores hero layout "+label)
			var inventory: Control=b.hud._inventory_toggle if size.x<1400 else b.hud._inventory_inline
			for control in [b.hud.minimap,b.hud._port_holder,b.hud._info_box,b.hud._info_toggle,inventory]:
				check(fits(control),"visible hero HUD control "+str(control.name)+label)
			if size.x<1100:check(is_equal_approx(b.hud.minimap.size.x,b.hud.minimap.size.y),"compact minimap keeps square proportions "+label)
			if size.x>=1400:
				check(b.hud._inventory_grid.get_child_count()==6,"wide layout retains all six inline item slots "+label)
				for item in b.hud._inventory_grid.get_children():check(fits(item),"wide inline item slot visible "+label+str(item.get_index()))
			var slots: Array=[]
			for button in b.hud._skill_bar.get_children():
				if button.is_queued_for_deletion():continue
				check(fits(button),"all hero commands visible "+str(button.get_index())+label)
				if button.get_property_list().any(func(property):return String(property.name)=="slot"):
					slots.append(button.slot)
					var skill_id: String=String(u.ability_slots[button.slot].id)
					var icon: Texture2D=button._ability_art_icon(skill_id)
					check(icon!=null and icon.resource_path=="res://"+String(pack_inputs.skill_icons[skill_id]),"actual HUD uses painted skill icon "+skill_id+label)
					check(button.hotkey==root.get_node("Settings").command_key_labels()[button.slot],"original command hotkey retained "+label+str(button.slot))
			check(slots==[0,1,2,3],"all four original skill indices retained "+label)
			if size.x==960:
				await click(b.hud._inventory_toggle,b.hud._inventory_toggle.get_global_rect().get_center(),"inventory "+label)
				check(b.hud._inventory_popup.visible,"real item popup opens "+label)
				check(fits(b.hud._inventory_popup),"full six-slot item popup inside viewport "+label)
				await click(b.hud._inventory_toggle,b.hud._inventory_toggle.get_global_rect().get_center(),"close inventory "+label)
				var expanded: bool=b.hud._info_expanded
				await click(b.hud._info_toggle,b.hud._info_toggle.get_global_rect().get_center(),"information "+label)
				check(b.hud._info_expanded!=expanded,"real information toggle responds "+label)
				await click(b.hud._info_toggle,b.hud._info_toggle.get_global_rect().get_center(),"restore information "+label)
			await snap("hud_"+label+"_"+str(shots.size()))
	# The same drawn plus geometry must still deliver a real skill learning click.
	var first=b.hud._skill_bar.get_child(0)
	var rank: int=u.ability_slots[0].rank
	var prior_cd: float=float(u.ability_slots[0].get("cd_t",0.0))
	check(u.can_learn(0),"real level-one hero can learn Q")
	await click(first,first.get_global_transform()*first._learn_plus_center(),"original Q learn hotspot")
	check(int(u.ability_slots[0].rank)==rank+1,"native Q learn hotspot learns exactly one rank")
	check(is_equal_approx(float(u.ability_slots[0].get("cd_t",0.0)),prior_cd) and b._ability_armed.is_empty(),"learning does not cast or arm the newly learned skill")
	check(u.entity_id==identity and u.hp==hp,"HUD layout keeps actor identity and health")
	# Draw actual learned/passive/cooldown overlays on the production buttons.
	# Slot rank/timer are fixture inputs; no gameplay definition or cast is changed.
	for size in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=size;root.content_scale_size=size
		for i in range(4):u.ability_slots[i].rank=1;u.ability_slots[i].cd_t=0.0
		await settle();await snap("skills_learned_"+str(size.x))
		for i in [0,1,3]:u.ability_slots[i].cd_t=u.slot_cd(i)*0.6
		await settle();await snap("skills_cooldown_"+str(size.x))
		for i in range(4):u.ability_slots[i].cd_t=0.0
	root.size=Vector2i(960,540);root.content_scale_size=root.size;await settle()
	var peers: Array=[]
	for i in range(7):
		var peer=b.spawn_unit("liang_dao",0,origin+Vector2(32+i*8,32));peer.set_physics_process(false);peers.append(peer)
	b.select_members([u]+peers,false);await settle()
	check(b.active_unit()==u and b.hud._sel_grid.get_child_count()==8,"all multi-selection members retained with hero active")
	var scroll: ScrollContainer=b.hud._selection_scroll
	check(fits(scroll),"multi-selection scroll remains inside bottom bar")
	var point:=scroll.get_global_rect().get_center()
	var wheel_steps:=0
	for i in range(12):
		if fits(b.hud._sel_grid.get_child(7)):break
		var wheel:=InputEventMouseButton.new();wheel.position=point;wheel.global_position=point;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;root.push_input(wheel,true);await process_frame
		wheel_steps+=1
	await settle()
	check(scroll.scroll_vertical>0,"real wheel input scrolls the compact selection grid")
	check(fits(b.hud._sel_grid.get_child(7)),"last selected member remains reachable")
	check(is_equal_approx(float(u.ability_slots[0].get("cd_t",0.0)),prior_cd) and b._ability_armed.is_empty(),"selection wheel does not cast or arm a skill")
	hud_events.append({"label":"selection wheel","steps":wheel_steps,"scroll_value":scroll.scroll_vertical,"bar_max":scroll.get_v_scroll_bar().max_value,"bar_page":scroll.get_v_scroll_bar().page,"configured_cooldown":u.slot_cd(0),"remaining_cooldown":u.ability_slots[0].get("cd_t",0.0),"armed":b._ability_armed})
	await snap("hud_960_multiselection_scrolled")
	for peer in peers:b.units.erase(peer);peer.queue_free()
	localize.set_language("zh_CN",false)
	b.units.erase(u);u.queue_free();await process_frame
