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
	check(refs.size()==22,"portrait, twenty reused body sources and legacy sheet referenced")
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
	if u.faction==1:b._set_inspect(u)
	else:b.select_single(u,false)
	b.camera.position=b.to_screen(u.position)+Vector2(0,-20);b.camera.zoom=Vector2.ONE*2.8;b.camera.force_update_scroll()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;await settle()
		check(u.ui_portrait_texture()==portrait and b.hud._port_tex.texture==portrait,"actual Unit and HUD use new identity portrait "+prefix+str(size.x))
		check(fits(b.hud._port_tex) and b.hud._port_tex.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"actual portrait fits without aspect stretch "+prefix+str(size.x))
		await snap(prefix+"_"+str(size.x))
		observations.append({"case":prefix,"width":size.x,"portrait_rect":[b.hud._port_tex.size.x,b.hud._port_tex.size.y],"path":b.hud._port_tex.texture.resource_path})

func frame_path(frame: Texture2D) -> String:
	return frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path

func run() -> void:
	out=OS.get_environment("JIANG_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	verify_textures();var art=root.get_node("Art");portrait=art.portrait_texture("jiang_menshen")
	check(portrait!=null and portrait.resource_path=="res://assets/characters/jiang_menshen_canon_20261015/portrait.png","standalone canonical portrait resolved")
	check(art.ui_portrait_texture("jiang_menshen","jiang_menshen_fists")==portrait and art.ui_portrait_texture("jiang_menshen")==portrait,"ordinary and story UI share canonical face")
	check(art.ui_portrait_texture("wu_song","jiang_menshen_fists")==null,"foreign portrait owner rejected")
	check(art.avatar_texture("jiang_menshen","jiang_menshen_fists")!=portrait,"source body preview remains distinct from UI portrait")
	for direction in ["se","sw","ne","nw"]:
		for state in ["idle","walk","attack","hurt","down"]:
			var ordinary: Array=art.unit_anim_frames("jiang_menshen",state,direction)
			var story: Array=art.unit_anim_frames("jiang_menshen",state,direction,"jiang_menshen_fists")
			check(not ordinary.is_empty() and ordinary==story,"same accepted body frames "+state+direction)
			check(not ordinary.is_empty() and frame_path(ordinary[0])=="res://assets/campaign/anim/jiang_menshen_fists_"+state+"_"+direction+".png","exact canonical source "+state+direction)
			check(art.unit_anim_uses_directional_source("jiang_menshen",state,direction),"directional frame prevents mirroring "+state+direction)
		check(frame_path(art.unit_texture("jiang_menshen","",direction))=="res://assets/campaign/anim/jiang_menshen_fists_idle_"+direction+".png","ordinary still body correct "+direction)
		check(art.unit_anim_frames("jiang_menshen","death",direction).is_empty(),"living down never reused as authored death "+direction)
	check(art.unit_anim_frames("jiang_menshen","idle","invalid").is_empty(),"invalid direction rejected")
	check(art.unit_anim_frames("jiang_menshen","idle")==art.unit_anim_frames("jiang_menshen","idle","se"),"legacy empty direction has canonical SE preview")
	var neighbour: Texture2D=art.portrait_texture("shi_en");check(neighbour!=null and neighbour!=portrait,"neighbour portrait distinct")
	var codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;codex._select("jiang_menshen")
		await settle()
		var scroll_rect: Rect2=codex._detail_scroll.get_global_rect()
		for box in [codex._port,codex._walk,codex._atk]:
			var rect: Rect2=box.get_global_rect()
			check(rect.position.x>=scroll_rect.position.x and rect.end.x<=scroll_rect.end.x,"codex preview horizontal bounds "+str(size.x)+str(box==codex._atk))
		check(codex._sub_lbl.size.x<=codex._detail_scroll.size.x,"codex stats wrap within detail width "+str(size.x))
		if size.x==960:check(codex._atk.position.y+codex._atk.get_parent().position.y>codex._port.position.y+codex._port.get_parent().position.y,"narrow image row wraps attack preview")
		for index in range(4):
			codex._on_direction_selected(index);await settle();var d: String=["se","sw","ne","nw"][index]
			check(codex._port.frames==[portrait] and fits(codex._port),"actual codex portrait fits "+str(size.x)+d)
			check(codex._walk.frames==art.unit_anim_frames("jiang_menshen","walk",d) and codex._atk.frames==art.unit_anim_frames("jiang_menshen","attack",d),"actual codex canonical body previews "+str(size.x)+d)
			await snap("codex_jiang_"+str(size.x)+"_"+d)
		if size.x==960:
			codex._detail_scroll.scroll_vertical=280;await settle()
			check(fits(codex._atk),"narrow attack preview accessible by vertical scrolling");await snap("codex_jiang_960_attack_scrolled")
			codex._detail_scroll.scroll_vertical=0
	root.get_node("Localize").set_language("en",false);codex._select("jiang_menshen");await snap("codex_jiang_en_1920")
	check(codex._port.frames==[portrait],"English codex retains identity");root.get_node("Localize").set_language("zh_CN",false)
	codex.queue_free();await process_frame
	root.get_node("Localize").set_language("en",false);root.size=Vector2i(960,540);root.content_scale_size=root.size
	codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;codex._select("jiang_menshen");await settle()
	check(codex._list_scroll.custom_minimum_size.x==340,"actual fresh English scene uses wider list")
	var english_rect: Rect2=codex._detail_scroll.get_global_rect()
	for box in [codex._port,codex._walk,codex._atk]:
		check(box.get_global_rect().end.x<=english_rect.end.x,"English narrow preview horizontal bounds")
	check(codex._sub_lbl.size.x<=english_rect.size.x,"English narrow stats wrap")
	await snap("codex_jiang_en_960");codex._detail_scroll.scroll_vertical=280;await settle()
	check(fits(codex._atk),"English narrow attack preview accessible by scroll");await snap("codex_jiang_en_960_attack_scrolled")
	codex.queue_free();await process_frame;root.get_node("Localize").set_language("zh_CN",false)
	codex=load("res://scenes/codex.tscn").instantiate();root.add_child(codex);current_scene=codex;await settle()
	for size in [Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size
		for key in ["wu_song","hu_yanzhuo","shi_en","hall"]:
			codex._select(key);await settle();var bounds: Rect2=codex._detail_scroll.get_global_rect()
			for box in [codex._port,codex._walk,codex._atk]:
				check(box.get_global_rect().end.x<=bounds.end.x,"shared layout representative preview fits "+key+str(size.x)+str(box==codex._atk))
			check(codex._sub_lbl.size.x<=bounds.size.x,"shared layout representative stats fit "+key+str(size.x))
			await snap("codex_layout_"+key+"_"+str(size.x))
	codex.queue_free();await process_frame
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=6;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	check(b.level.id()=="level7","actual original Level7")
	var npc=b.level.menshen;var units: Array=b.units.duplicate();var original:=fingerprint(units);var grid: Array=Array(b.map.grid).duplicate()
	check(npc.faction==1 and npc.max_hp==800 and npc.setup_def.atk==22 and npc.defeat_outcome=="subdued" and npc.art_variant=="jiang_menshen_fists","original story enemy and nonlethal contract retained")
	await panel_cases(b,npc,"level7_jiang_inspect")
	check(b.selection.is_empty() and b._inspect_unit==npc,"enemy inspection is read-only")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	for direction in ["se","sw","ne","nw"]:
		npc.animation_direction=direction;npc.queue_redraw();await snap("level7_jiang_idle_"+direction)
	check(fingerprint(units)==original and Array(b.map.grid)==grid,"UI sampling preserves original actors health positions and terrain")
	check(npc.resolve_story("subdued"),"real living subdued transition accepted")
	check(npc.hp>0 and not npc._dying and npc.story_outcome=="subdued","subdued character alive")
	check(b.level.st==b.level.RETURN_SHOP,"original chapter callback reaches return-shop stage")
	check(not npc._story_animation_frames().is_empty() and frame_path(npc._story_animation_frames()[0]).contains("_down_"),"actual living outcome draws authored down pose")
	npc.queue_redraw();await snap("level7_jiang_subdued_alive")
	var live_hp: float=npc.hp;npc.take_damage(9999.0,b.level.wu);check(npc.hp==live_hp and not npc._dying,"post-subdual damage does not kill story character")
	b.queue_free();await process_frame;await process_frame
	campaign.skirmish=true;b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame;freeze(b)
	units=b.units.duplicate();original=fingerprint(units);grid=Array(b.map.grid).duplicate()
	var center: Vector2=b.map.cell_to_world(Vector2i(24,27));var hero=b.spawn_unit("jiang_menshen",0,center);hero.set_physics_process(false)
	check(hero.art_variant.is_empty() and hero.setup_def.atk==53 and hero.max_hp==1870 and hero.atk_cd==0.88,"ordinary stored variant and combat definition unchanged")
	await panel_cases(b,hero,"ordinary_jiang")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var deltas: Array=[Vector2(48,0),Vector2(0,48),Vector2(0,-48),Vector2(-48,0)]
	for index in range(4):
		var direction: String=["se","sw","ne","nw"][index];hero.position=center;hero.order_stop();hero.set_physics_process(true);hero.order_move(center+deltas[index])
		for tick in range(12):await physics_frame
		check(hero.position.distance_to(center)>2.0 and hero.animation_direction==direction,"real ordinary movement chooses direction "+direction)
		hero.set_physics_process(false);hero.queue_redraw();await snap("ordinary_jiang_move_"+direction)
		check(hero._frame_directional,"rendered ordinary movement uses authored direction "+direction)
		hero.order_stop()
	hero.position=center;hero.animation_direction="se";hero._begin_cosmetic_swing(Vector2(1,0));hero._lunge=0.6;hero.queue_redraw();await snap("ordinary_jiang_attack_visual_fixture")
	check(hero._frame_directional,"ordinary cosmetic attack draws canonical directional body")
	check(not hero._should_draw_programmatic_swing_fx(),"ordinary bare-handed body has no inferred spear trail")
	hero._lunge=0.0;hero.take_damage(100000.0,null,false,true);hero.queue_redraw();await snap("ordinary_jiang_death_visual_fixture")
	check(hero._dying and hero.story_outcome.is_empty(),"ordinary death retains fatal outcome rather than living down")
	check(fingerprint(units)==original and Array(b.map.grid)==grid,"original skirmish actors and terrain unchanged")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"observations":observations,"scope":"Full resource PCK in native editor; 22 texture pixel/mipmap references; actual codex directions/three sizes, original Level7 enemy inspection and direct living-subdual callback, ordinary actual movement and cosmetic attack/fatal damage fixtures. Existing actors and Battle frozen, APIs invoked directly. No pointer delivery, actual attack damage, full chapter, new multi-frame gait, release EXE, SDK, Steam, performance or whole-art acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print("JIANG_CANON ",checks.size()," checks; ",failures.size()," failures")
	b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
