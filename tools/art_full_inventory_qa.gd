extends SceneTree
## Resource and presentation inventory; missing art remains an open item.
const DIRS := ["se", "sw", "ne", "nw"]
const STATES := ["idle", "walk", "attack", "hurt", "death"]
var output := ""
var checks: Array = []
var failures: Array = []
var screenshots: Array = []
var art

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)

func source(tex) -> String:
	if tex == null: return ""
	if tex is AtlasTexture: return tex.atlas.resource_path
	return tex.resource_path

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "screenshot " + name)
	screenshots.append({"path":name + ".png","sha256":FileAccess.get_sha256(path)})

func gallery(rows: Array, prefix: String) -> void:
	for page in range(ceili(rows.size() / 12.0)):
		var canvas := Control.new()
		canvas.theme = UITheme.shared()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("25271e")
		bg.size = Vector2(1280,720)
		canvas.add_child(bg)
		for i in range(12):
			var index := page * 12 + i
			if index >= rows.size(): break
			var row: Dictionary = rows[index]
			var origin := Vector2((i % 4) * 320, (i / 4) * 235)
			var label := Label.new()
			label.text = row.label
			label.position = origin + Vector2(8,4)
			label.size = Vector2(304,26)
			label.clip_text = true
			label.add_theme_font_size_override("font_size",16)
			canvas.add_child(label)
			var textures: Array = row.textures
			for j in range(textures.size()):
				var box := TextureRect.new()
				box.texture = textures[j]
				box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				box.position = origin + Vector2(6+j*154,30)
				box.size = Vector2(150,185)
				canvas.add_child(box)
		await snap(prefix + "_" + str(page+1))
		canvas.queue_free()
		await process_frame

func _run() -> void:
	output = OS.get_environment("ART_FULL_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	art = root.get_node("Art")
	check(source(art.avatar_texture("guan_zhanchuan")).contains("official_warship_default"),"warship icon is its own ship")
	for direction in DIRS:
		check(source(art.unit_texture("guan_zhanchuan","",direction)).ends_with("official_warship_default_"+direction+".png"),"warship directional body "+direction)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://tools/contracts/art_full_20260915/environment.json"))
	for row in manifest.resources:
		var state: String = row.get("state","default")
		for level in row.levels:
			var tex = CampaignEnvironmentArt.object(level,row.key,state) if row.resolver=="object" else CampaignEnvironmentArt.overlay(level,row.key)
			check(tex is AtlasTexture and source(tex)=="res://"+row.source,"new scoped atlas "+row.key+state+level)
		check(CampaignEnvironmentArt.object("skirmish",row.key,state)==null and CampaignEnvironmentArt.overlay("skirmish",row.key)==null,"campaign atlas cannot leak to skirmish "+row.key)
	var inventory: Array = []
	var cards: Array = []
	var defs = load("res://scripts/defs.gd")
	var keys: Array = defs.UNITS.keys()
	keys.sort()
	for key in keys:
		var d: Dictionary = defs.UNITS[key]
		var item := {"key":key,"name":d.name,"hero":d.get("hero",false),"building":d.get("building",false),"resource":d.get("resource",false),"portrait":source(art.portrait_texture(key)),"avatar":source(art.avatar_texture(key)),"body":source(art.unit_texture(key)),"states":{}}
		for state in STATES:
			var states := {}
			for direction in DIRS:
				var path: String = art._resolve_generic_directional_path(key,state,direction)
				var frames: Array = art._load_generic_directional_frames(path)
				states[direction] = {"exact_frames":frames.size(),"source":source(frames[0]) if not frames.is_empty() else ""}
			item.states[state] = states
		inventory.append(item)
		var body = art.unit_texture(key,"","se")
		if body == null: body = art.building_texture(key)
		if body == null: body = art.object_texture(key)
		cards.append({"label":d.name+" / "+key,"textures":[art.avatar_texture(key),body]})
	await gallery(cards,"units")
	var env_cards: Array = []
	var environments: Array = []
	for table_name in ["object","overlay","static_flag"]:
		var table: Dictionary = CampaignEnvironmentArt.OBJECT_ROUTES if table_name == "object" else (CampaignEnvironmentArt.OVERLAY_ROUTES if table_name == "overlay" else CampaignEnvironmentArt.STATIC_FLAG_ROUTES)
		for key in table:
			var level: String = table[key].levels[0]
			for state in table[key].paths:
				var tex = CampaignEnvironmentArt.object(level,key,state) if table_name == "object" else (CampaignEnvironmentArt.overlay(level,key) if table_name == "overlay" else CampaignEnvironmentArt.static_flag(level,key))
				environments.append({"resolver":table_name,"key":key,"level":level,"state":state,"source":source(tex)})
				env_cards.append({"label":level+" "+key+" "+state,"textures":[tex]})
	await gallery(env_cards,"environment")
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	for key in ["dong_chao","xue_ba"]:
		check(art.unit_texture(key) != null, key+" directionless body has a real reference")
		var portrait: String = "res://assets/characters/art_full_20260915/"+key+".png"
		check(source(art.avatar_texture(key,key+"_escort")) == portrait,key+" campaign HUD portrait")
		check(art.avatar_texture("lin_chong",key+"_escort") == null,key+" variant cannot cross identity")
		codex._select(key)
		check(source(codex._port.frames[0]) == portrait,key+" actual codex portrait")
		for di in range(4):
			codex._direction_picker.item_selected.emit(di)
			await process_frame
			var direction: String = DIRS[di]
			check(not codex._direction_picker.disabled and codex._direction_index == di,key+" direction picker "+direction)
			for state in ["idle","walk"]:
				var frames: Array = art.unit_anim_frames(key,state,direction)
				var expected: String = "res://assets/campaign/anim/"+key+"_escort_"+state+"_"+direction+".png"
				check(frames.size() == (1 if state == "idle" else 4),key+state+direction+" frame count")
				for frame in frames: check(source(frame) == expected,key+state+direction+" exact same-person source")
			check(art._load_generic_directional_frames(art._resolve_generic_directional_path(key,"attack",direction)).is_empty(),key+direction+" missing attack remains a gap")
			await snap(key+"_codex_"+direction)
	codex.queue_free()
	await process_frame
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await snap("main_menu")
	menu.queue_free()
	await process_frame
	var icon_cards: Array = []
	for file in DirAccess.get_files_at("res://assets/ui/skills_v2"):
		if file.ends_with(".png"): icon_cards.append({"label":file,"textures":[load("res://assets/ui/skills_v2/"+file)]})
	for file in ["fx_items.png","fx_kit2.png","fx_ability_impacts.png","fx_ability_projectiles.png"]:
		icon_cards.append({"label":file,"textures":[load("res://assets/"+file)]})
	await gallery(icon_cards,"icons_fx")
	var world_rows: Array = await world_views()
	var result := {"world":world_rows,"passed":failures.is_empty(),"checks":checks,"failures":failures,"units":inventory,"environment":environments,"screenshots":screenshots,"scope":"All-definition inventory, codex, menu, icon sheets and eight chapter visual fixtures; no gameplay, frame rate or human quality acceptance."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("ART_FULL_QA ",checks.size()," checks; ",failures.size()," failures; ",inventory.size()," definitions")
	quit(0 if failures.is_empty() else 1)

func world_views() -> Array:
	var results: Array = []
	var campaign = root.get_node("Campaign")
	for level_index in range(8):
		campaign.current = level_index
		for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: campaign.set(key,false)
		root.get_node("Settings").auto_micro_level = 0
		seed(5088120)
		var battle = load("res://scenes/main.tscn").instantiate()
		root.add_child(battle)
		current_scene = battle
		await process_frame
		battle.hud._intro_root.hide()
		battle._on_intro_done()
		battle._on_start_battle()
		await process_frame
		await snap("level"+str(level_index+1)+"_opening")
		# Explicit visual fixture: freeze actors and lift fog for local art inspection only.
		battle.set_physics_process(false)
		for unit in battle.units:
			if is_instance_valid(unit): unit.set_physics_process(false)
		battle.fog = false
		if battle._fog_layer != null: battle._fog_layer.hide()
		battle.camera.zoom = Vector2.ONE * 1.8
		battle.camera.set_process(false)
		battle.camera.set_physics_process(false)
		battle.camera.position_smoothing_enabled = false
		var routes: Array = []
		var seen: Array = []
		for node in battle.find_children("*", "Node2D", true, false):
			if not node.has_meta("campaign_environment_route"): continue
			var key: String = node.get_meta("campaign_environment_route")
			routes.append(key)
			if key=="heyang_wine_sign" and node.has_method("_campaign_environment_texture"):
				check(node._campaign_environment_texture() is AtlasTexture,"real wine sign accepts measured blank cloth")
			var tex = CampaignEnvironmentArt.object("level"+str(level_index+1),key)
			if tex == null: tex = CampaignEnvironmentArt.overlay("level"+str(level_index+1),key)
			if not tex is AtlasTexture or not source(tex).contains("art_full_20260915") or key in seen: continue
			seen.append(key)
			battle.center_camera_cell(battle.map.world_to_cell(node.position))
			for scenery in battle.find_children("*", "Node2D", true, false):
				if scenery.has_method("_refresh_fog_visibility"): scenery._refresh_fog_visibility()
			await create_timer(0.1).timeout
			check(node.visible,"world art visible "+str(level_index+1)+" "+key)
			if node.has_method("_campaign_environment_texture"):
				node.queue_redraw()
				await RenderingServer.frame_post_draw
				check(node.has_meta("campaign_environment_label_y"),"new building label above painted roof "+key)
			await snap("level"+str(level_index+1)+"_"+key)
			if key=="cuiyun_tower":
				var scenery = node.get_parent()
				scenery.set_story_object_state(key,"signal")
				check(source(node.tex)==source(tex) and node.tex.region!=tex.region,"cuiyun real state switches atlas region")
				await snap("level8_cuiyun_tower_signal")
				scenery.set_story_object_state(key,"default")
		results.append({"level":level_index+1,"routes":routes,"new_art_captures":seen})
		battle.queue_free()
		await process_frame
		await process_frame
	current_scene = null
	return results
