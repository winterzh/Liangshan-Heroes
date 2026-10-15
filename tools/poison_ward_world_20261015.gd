extends SceneTree
class WardDriver extends Node:
	var battle
	var elapsed:=0.0
	func _physics_process(delta: float) -> void:
		elapsed+=delta
		battle._grid_build();battle._tick_pending_casts();battle._ward_pass(delta);battle._fog_pass(delta)
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var observations: Array=[]
var out:=""
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func snap(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var p:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(p)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(p),"size":[root.size.x,root.size.y]})
func fingerprint(units: Array) -> Array:
	var rows: Array=[]
	for u in units:
		if is_instance_valid(u):rows.append([u.entity_id,u.key,u.position.x,u.position.y,u.hp,u.faction])
	return rows
func clear_cell(b) -> Vector2i:
	for x in range(10,b.map.w-10):
		for y in range(10,b.map.h-10):
			var c:=Vector2i(x,y);var p: Vector2=b.map.cell_to_world(c)
			if b.units.any(func(u):return is_instance_valid(u) and u.position.distance_to(p)<340):continue
			if b.map.decor.any(func(row):return b.map.cell_to_world(row[1]).distance_to(p)<maxf(250.0,float(row[2]))):continue
			var valid:=true
			for d in [Vector2.ZERO,Vector2(-96,0),Vector2(0,96),Vector2(64,0),Vector2(0,-260)]:
				if not b.map.is_open_world(p+d):valid=false
			if valid:return c
	return Vector2i(-1,-1)
func ward_node(b):
	for child in b.fx_root.get_children():
		var names: Array=[]
		for p in child.get_property_list():names.append(String(p.name))
		if names.has("banner_kind") and names.has("rad") and names.has("life"):return child
	return null
func verify_textures() -> void:
	var refs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(refs.size()==3,"native poison, icon and original ward sheet references")
	for p in refs:
		check(not FileAccess.file_exists("res://"+String(p)),"source PNG absent from actual resource pack "+p)
		var tex: Texture2D=load("res://"+String(p));check(tex!=null,"packed texture loads "+p)
		if tex==null:continue
		var im:=tex.get_image()
		if im.is_compressed():check(im.decompress()==OK,"packed texture decompress "+p)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(im.get_data())
		check(digest.finish().hex_encode()==String(refs[p].data_sha256),"actual texture pixels/mipmaps equal native reference "+p)
		check(im.get_width()==int(refs[p].size[0]) and im.get_height()==int(refs[p].size[1]),"packed dimensions "+p)
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	verify_textures()
	var art=root.get_node("Art");var poison: Texture2D=art.ward_texture("poison")
	check(poison!=null and poison.resource_path=="res://assets/fx/poison_ward_20261015/poison_ward.png","real Art poison route uses new crystal stake")
	check(art.ward_is_upright("poison") and not art.ward_is_upright("heal") and not art.ward_is_upright("death"),"only native poison is upright")
	for style in ["heal","death"]:
		var legacy: Texture2D=art.ward_texture(style)
		check(legacy is AtlasTexture and legacy.atlas==load("res://assets/wards.png"),"legacy atlas retained "+style)
	check(art.ward_texture("banner")==null and art.ward_texture("unknown")==null,"procedural banner and unknown fallback retained")
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.skirmish=true;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame
	var original_units: Array=b.units.duplicate();var original:=fingerprint(original_units);var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true)
	for u in b.units:u.set_physics_process(false)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false);b.camera.set_physics_process(false);b.camera.position_smoothing_enabled=false
	b.fog=true
	var cell:=clear_cell(b);check(cell.x>=0,"original terrain has clear isolated fixture site")
	if cell.x<0:quit(3);return
	var center: Vector2=b.map.cell_to_world(cell)
	var caster=b.spawn_unit("shi_en",0,center+Vector2(-96,0));caster.auto_micro=false;caster.set_stance(3)
	var enemy=b.spawn_unit("guan_dao",1,center+Vector2(0,96));enemy.set_physics_process(false)
	var outside=b.spawn_unit("guan_dao",1,center+Vector2(0,-260));outside.set_physics_process(false)
	var ally=b.spawn_unit("liang_dao",0,center+Vector2(64,0));ally.set_physics_process(false)
	var enemy_hp: float=enemy.hp;var outside_hp: float=outside.hp;var ally_hp: float=ally.hp
	b.select_single(caster,false);b.camera.position=b.to_screen(center)+Vector2(0,-20);b.camera.zoom=Vector2.ONE*2.0;b.camera.force_update_scroll()
	check(caster.can_learn(1),"real Shi En can learn W at level one")
	b.learn_slot(caster,1);check(int(caster.ability_slots[1].rank)==1,"original W learning API learns rank one")
	var driver:=WardDriver.new();driver.battle=b;driver.process_physics_priority=1000;root.add_child(driver)
	check(b._ai_cast_slot(caster,1,center),"original cast API starts poison ward windup")
	check(caster._cast_t>0.0 and b._wards.is_empty(),"ward not created before actual windup")
	var deadline:=Time.get_ticks_msec()+5000
	while b._wards.is_empty() and Time.get_ticks_msec()<deadline:await physics_frame
	check(b._wards.size()==1,"real windup and pending-cast settlement creates one model ward")
	var ward=ward_node(b);check(ward!=null,"real cast creates actual WardFx")
	if ward==null:quit(4);return
	caster.set_physics_process(false)
	var data: Dictionary=b._wards[0];var ward_pos: Vector2=data.pos
	check(data.mode=="poison" and data.r==220.0 and data.pulse==0.5 and data.dmg==12.0 and data.slow==0.5 and data.slow_dur==1.5,"original rank-one gameplay parameters retained")
	check(ward.style=="poison" and ward.life==8.0 and ward.rad==220.0 and ward.position==ward_pos,"original visual state and snapped gameplay anchor retained")
	check(float(caster.ability_slots[1].cd_t)>13.0 and caster.slot_cd(1)==14.0,"original W cooldown applied")
	while enemy.hp==enemy_hp and Time.get_ticks_msec()<deadline:await physics_frame
	check(enemy.hp<enemy_hp and enemy.temp_speed==0.5 and enemy._temp_speed_t>0.0,"actual ward pulse damages and slows in-range enemy")
	check(outside.hp==outside_hp and ally.hp==ally_hp,"out-of-range enemy and ally remain unhurt")
	check(b.fog and b.target_visible_to(caster,enemy),"ordinary fog remains on and nearby enemy is visible")
	observations.append({"ward_pos":[ward_pos.x,ward_pos.y],"life":ward.life,"radius":ward.rad,"first_damage":enemy_hp-enemy.hp,"slow":enemy.temp_speed,"configured_cd":caster.slot_cd(1),"remaining_cd":caster.ability_slots[1].cd_t})
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size
		for zoom in [1.0,2.8]:
			b.camera.zoom=Vector2.ONE*zoom;b.camera.force_update_scroll()
			await snap("poison_ward_"+str(size.x)+"_zoom_"+str(zoom))
			check(is_instance_valid(ward) and ward.position==ward_pos and ward.rad==220.0,"resize and zoom preserve actual ward anchor "+str(size.x)+str(zoom))
	ward.lite=true;await snap("poison_ward_lite_1920")
	check(ward.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"actual new WardFx uses mipmapped sampling")
	check(ward.style=="poison" and ward.position==ward_pos,"lite rendering retains style and model location")
	while is_instance_valid(ward) and ward.t>0.25 and driver.elapsed<12.0:await physics_frame
	await snap("poison_ward_fade")
	while (is_instance_valid(ward) or not b._wards.is_empty()) and driver.elapsed<13.0:await physics_frame
	check(not is_instance_valid(ward) and b._wards.is_empty(),"actual visual fade and original eight-second model expire")
	check(outside.hp==outside_hp and ally.hp==ally_hp,"full life keeps outside enemy and ally safe")
	check(fingerprint(original_units)==original and Array(b.map.grid)==grid and b.map.decor==decor,"original units, map and scenery unchanged")
	check(b._gameplay_rng_issue.is_empty(),"no gameplay RNG fault")
	driver.queue_free()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"observations":observations,"scope":"Actual full resource PCK, ordinary skirmish Shi En learning/cast/windup and autonomous ward pulses. Original world participants and Battle simulation frozen; driver calls original grid, pending-cast, ward and fog passes at real physics delta. Fixture enemies frozen. Three sizes/two zooms, lite render flag and natural eight-second fade. No release EXE, live SDK, Steam, full chapter/restoration/performance/all-art acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("POISON_WARD_WORLD ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
