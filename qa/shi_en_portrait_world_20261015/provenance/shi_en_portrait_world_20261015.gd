extends SceneTree
var out:=""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var observations: Array=[]
var portrait: Texture2D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func settle() -> void:
	for i in range(6):await process_frame
func snap(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var p:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(p)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(p),"size":[root.size.x,root.size.y]})
func fits(c: Control) -> bool:
	var area:=Rect2(Vector2.ZERO,Vector2(root.size));var parent=c.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:area=area.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	return c.is_visible_in_tree() and area.encloses(c.get_global_rect())
func fingerprint(units: Array) -> Array:
	var rows: Array=[]
	for u in units:
		if is_instance_valid(u):rows.append([u.entity_id,u.key,u.position.x,u.position.y,u.hp,u.faction,u.art_variant])
	return rows
func freeze(b) -> void:
	for u in b.units:u.set_physics_process(false)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false);b.camera.set_physics_process(false);b.camera.position_smoothing_enabled=false
func verify_textures() -> void:
	var refs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(refs.size()==3,"new portrait, body identity and original portrait sheet referenced")
	for p in refs:
		check(not FileAccess.file_exists("res://"+String(p)),"native PNG absent from PCK "+p)
		var tex: Texture2D=load("res://"+String(p));check(tex!=null,"packed texture loads "+p)
		if tex==null:continue
		var image:=tex.get_image()
		if image.is_compressed():check(image.decompress()==OK,"packed texture decompress "+p)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
		check(digest.finish().hex_encode()==String(refs[p].data_sha256),"complete pixels/mipmaps equal native import "+p)
		check(image.get_width()==int(refs[p].size[0]) and image.get_height()==int(refs[p].size[1]),"packed dimensions "+p)
func panel_cases(b,u,prefix: String) -> void:
	b.select_single(u,false);b.camera.position=b.to_screen(u.position)+Vector2(0,-20);b.camera.zoom=Vector2.ONE*2.8;b.camera.force_update_scroll()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;await settle()
		check(u.ui_portrait_texture()==portrait and b.hud._port_tex.texture==portrait,"actual Unit and HUD use new identity portrait "+prefix+str(size.x))
		check(fits(b.hud._port_tex) and b.hud._port_tex.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"actual portrait fits without aspect stretch "+prefix+str(size.x))
		await snap(prefix+"_"+str(size.x))
		observations.append({"case":prefix,"width":size.x,"portrait_rect":[b.hud._port_tex.size.x,b.hud._port_tex.size.y],"path":b.hud._port_tex.texture.resource_path})
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	verify_textures();var art=root.get_node("Art");portrait=art.portrait_texture("shi_en")
	check(portrait!=null and portrait.resource_path=="res://assets/characters/shi_en_portrait_20261015/shi_en.png","Art resolves standalone Shi En portrait")
	check(art.ui_portrait_texture("shi_en")==portrait and art.avatar_texture("shi_en")==portrait,"common UI and avatar routes share same identity")
	check(art.ui_portrait_texture("shi_en","daming_bound_lu_junyi")==null,"foreign story identity cannot borrow Shi En portrait")
	var neighbour: Texture2D=art.portrait_texture("jiang_menshen");var existing: Texture2D=art.portrait_texture("wu_song")
	check(neighbour!=null and existing!=null and neighbour!=portrait and existing!=portrait,"neighbour and existing standalone heroes retain their own portraits")
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("shi_en");await settle()
		check(codex._cur=="shi_en" and codex._port.frames==[portrait],"actual codex selects new portrait "+str(size.x))
		check(fits(codex._port),"codex portrait fully visible "+str(size.x))
		check(not codex._walk.frames.is_empty() and not codex._atk.frames.is_empty(),"original body previews retained "+str(size.x))
		await snap("codex_shi_en_"+str(size.x))
	root.get_node("Localize").set_language("en",false);codex._select("shi_en");await snap("codex_shi_en_en_1920")
	check(codex._port.frames==[portrait],"English codex retains same portrait identity")
	root.get_node("Localize").set_language("zh_CN",false);codex.queue_free();await process_frame
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=6;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	check(b.level.id()=="level7","actual original Level7")
	var npc=b.level.shi;var units: Array=b.units.duplicate();var original:=fingerprint(units);var grid: Array=Array(b.map.grid).duplicate()
	check(npc.setup_def.atk==0 and npc.setup_def.noncombat and npc.setup_def.abilities.is_empty(),"original story Shi En remains noncombat with no skills")
	await panel_cases(b,npc,"level7_shi_en")
	var lines: Array=b.level.intro_lines();var authored: Array=lines.filter(func(line):return String(line.get("key",""))=="shi_en")
	check(authored.size()==1,"one original authored Shi En intro line")
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;b.hud.show_intro(authored);await settle()
		check(b.hud._intro_root.visible and b.hud._intro_port_tex.texture==portrait,"actual authored dialogue uses new portrait "+str(size.x))
		check(fits(b.hud._intro_port_tex),"actual dialogue portrait fits "+str(size.x))
		await snap("level7_shi_en_dialogue_"+str(size.x));b.hud._intro_root.hide()
	check(fingerprint(units)==original and Array(b.map.grid)==grid,"Level7 identity, positions, health and terrain unchanged by portrait/UI sampling")
	b.queue_free();await process_frame;await process_frame
	campaign.skirmish=true
	b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	units=b.units.duplicate();original=fingerprint(units);grid=Array(b.map.grid).duplicate()
	var center: Vector2=b.map.cell_to_world(Vector2i(24,27));var hero=b.spawn_unit("shi_en",0,center);hero.set_physics_process(false)
	check(hero.setup_def.atk==15 and hero.max_hp==210 and hero.setup_def.abilities.size()==4,"ordinary combat Shi En definition unchanged")
	await panel_cases(b,hero,"skirmish_shi_en")
	b.hud._refresh_hero_bar();await settle()
	var chips: Array=b.hud._hero_bar.get_children().filter(func(chip):return chip.hero==hero or chip.roster_key=="shi_en")
	check(not chips.is_empty(),"real hero bar includes ordinary Shi En")
	for chip in chips:
		check(chip._last_drawn_portrait_path==portrait.resource_path and fits(chip),"actual rendered hero chip uses new portrait")
	check(fingerprint(units)==original and Array(b.map.grid)==grid,"original skirmish actors and terrain unchanged")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"observations":observations,"scope":"Actual full resource PCK in native editor. Real codex selection, original Level7 NPC/HUD and authored dialogue, ordinary skirmish HUD/hero chip. Existing actors and Battle simulation frozen; selection/intro APIs called directly, not mouse event/end-to-end chapter acceptance. No release EXE, SDK, Steam, performance, full identity/all art acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("SHI_EN_PORTRAIT ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
