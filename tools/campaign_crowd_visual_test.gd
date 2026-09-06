extends SceneTree
## Static crowd resource and real-render checks. Does not drive fights or measure FPS.
## Reserve the GPU, import the four town variants, then run without --headless.
const CampaignArt := preload("res://scripts/campaign_art.gd")
const VIEW_SIZE := Vector2i(1280, 720)
var scenery_script: GDScript
var map_script: GDScript
var output_dir := ""
var gallery_captured := false
var checks: Array[Dictionary] = []
var assets: Array[Dictionary] = []
var scenes: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()

func _check(label: String, passed: bool) -> void:
	checks.append({"check":label,"passed":passed})
	print("[crowd-check] ","PASS " if passed else "FAIL ",label)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	if DisplayServer.get_name() == "headless":
		push_error("Crowd visual evidence requires a real graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("CROWD_VISUAL_OUT")
	if output_dir.is_empty(): output_dir = ProjectSettings.globalize_path("res://qa/web_chatgpt_art_20260831/crowd_visual")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Liangshan static crowd QA · 1280×720"
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	# Delay loading the scenery and its Unit/GameMap dependencies until autoloads exist.
	scenery_script = load("res://scripts/campaign_scenery.gd")
	map_script = load("res://scripts/game_map.gd")
	_check("scenery script loads after autoload startup",scenery_script != null and scenery_script.can_instantiate())
	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	await _check_resources()
	if checks.all(func(item): return item.passed):
		await _capture_gallery()
		for id in ["level2", "level8"]: await _capture_scene(id)
	_check("gallery and both real scenes completed",gallery_captured and scenes.size() == 2)
	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_now := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	_check("campaign.cfg existence and bytes unchanged", save_existed == save_exists_now and save_before == save_now)
	var passed: bool = checks.all(func(item): return item.passed)
	var report := {"passed":passed,"checks":checks,"assets":assets,"scenes":scenes,"viewport":[1280,720],
		"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),
		"scope":"Static rendering and resource contracts; no dynamic civilian escape, combat, FPS or human acceptance claim."}
	_write_json(output_dir.path_join("report.json"),report)
	print("[crowd-summary] ",JSON.stringify({"passed":passed,"checks":checks.size(),"scenes":scenes.size()}))
	quit(0 if passed else 1)

func _check_resources() -> void:
	var art = root.get_node("Art")
	for variant in scenery_script.StoryCrowd.ART_VARIANTS:
		var images: Array[Image] = []
		var hashes: Array[String] = []
		for direction in scenery_script.StoryCrowd.DIRECTIONS:
			var exists: bool = art.campaign_variant_has_direction(variant,direction)
			_check("%s %s real direction exists"%[variant,direction],exists)
			if not exists: continue
			var frames: Array = art.unit_anim_frames("","idle",direction,variant)
			var cached: Array = art.unit_anim_frames("","idle",direction,variant)
			var cache_ok: bool = not frames.is_empty() and not cached.is_empty() and frames[0] == cached[0]
			_check("%s %s first idle frame cached"%[variant,direction],cache_ok)
			if not cache_ok: continue
			var image: Image = frames[0].get_image()
			var clear := 0
			var visible_pixels := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var alpha := image.get_pixel(x,y).a
					if alpha <= 0.01: clear += 1
					if alpha >= 0.5: visible_pixels += 1
			var alpha_ok: bool = image.get_size() == Vector2i(256,256) and clear > 10000 and visible_pixels > 1000
			for corner in [Vector2i(0,0),Vector2i(255,0),Vector2i(0,255),Vector2i(255,255)]:
				alpha_ok = alpha_ok and image.get_pixelv(corner).a <= 0.01
			_check("%s %s 256px genuine alpha cutout"%[variant,direction],alpha_ok)
			var hasher := HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(image.get_data())
			var digest := hasher.finish().hex_encode()
			images.append(image)
			hashes.append(digest)
			assets.append({"variant":variant,"direction":direction,"path":CampaignArt.animation_path(variant,"idle",direction),
				"frame_size":str(image.get_size()),"clear_pixels":clear,"visible_pixels":visible_pixels,"sha256_pixels":digest})
			await process_frame
		var distinct := images.size() == 4
		for a in range(images.size()):
			for b in range(a+1,images.size()):
				distinct = distinct and hashes[a] != hashes[b] and not _is_exact_mirror(images[a],images[b])
		_check("%s four distinct directions, no exact mirrored duplicate"%variant,distinct)

func _is_exact_mirror(first: Image,second: Image) -> bool:
	if first.get_size() != second.get_size(): return false
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			if not first.get_pixel(x,y).is_equal_approx(second.get_pixel(first.get_width()-x-1,y)): return false
	return true

func _capture_gallery() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var plate := GalleryPlate.new()
	layer.add_child(plate)
	var iso := Node2D.new()
	iso.transform = map_script.ISO
	layer.add_child(iso)
	var cache_consistent := true
	for person in range(4):
		for facing in range(4):
			for magnification in [1.0,3.0]:
				var crowd = scenery_script.StoryCrowd.new()
				crowd.variant = person + facing*4
				var foot := Vector2(64+facing*310+(0 if magnification == 1.0 else 128),175+person*164)
				crowd.position = map_script.ISO_INV * foot
				crowd.scale = Vector2.ONE*magnification
				iso.add_child(crowd)
				var frames: Array = root.get_node("Art").unit_anim_frames("","idle",crowd.idle_direction(),crowd.art_variant_key())
				cache_consistent = cache_consistent and not frames.is_empty() and crowd._idle_texture == frames[0]
	_check("gallery uses cached StoryCrowd first frames at native and 3x sizes",cache_consistent)
	await process_frame
	await RenderingServer.frame_post_draw
	gallery_captured = root.get_texture().get_image().save_png(output_dir.path_join("crowd_gallery_1280.png")) == OK
	_check("16-direction gallery PNG",gallery_captured)
	layer.queue_free()
	await process_frame
	await process_frame

func _capture_scene(id: String) -> void:
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: campaign.set(mode,false)
	campaign.current = campaign.index_for_id(id)
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	var scenery = battle.map.sample_scenery
	var crowds: Array = scenery.get_children().filter(func(child): return child.get_script() == scenery_script.StoryCrowd)
	var expected: Array = battle.map.decor.filter(func(item): return item[0] == "crowd")
	var unit_count: int = battle.units.size()
	var grid_before: Array = Array(battle.map.grid).duplicate(true)
	var positions: Array = []
	var directions: Dictionary = {}
	var valid: bool = crowds.size() == expected.size() and crowds.size() == (8 if id == "level2" else 4)
	for index in range(crowds.size()):
		var crowd = crowds[index]
		valid = valid and not crowd.has_method("take_damage") and not crowd in battle.units and crowd.get_child_count() == 0
		valid = valid and crowd.position == battle.map.cell_to_world(expected[index][1]) and crowd.variant == int(expected[index][3])
		valid = valid and crowd._idle_texture != null and crowd.scale == Vector2.ONE and crowd.material == null
		directions[crowd.idle_direction()] = int(directions.get(crowd.idle_direction(),0))+1
		positions.append({"cell":str(expected[index][1]),"variant":crowd.art_variant_key(),"direction":crowd.idle_direction(),"idle_instance":crowd._idle_texture.get_instance_id() if crowd._idle_texture != null else 0})
	_check(id+" original crowd count, world feet, cache and non-unit scenery",valid)
	_check(id+" real decor uses all four directions",directions.size() == 4)
	var views: Array = [{"name":"overview","cell":Vector2i(29,20) if id == "level2" else Vector2i(31,24),"zoom":1.15},
		{"name":"detail","cell":Vector2i(29,18) if id == "level2" else Vector2i(33,21),"zoom":2.0}]
	for view in views:
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(view.cell))
		battle.camera.zoom = Vector2.ONE*float(view.zoom)
		battle.camera.force_update_scroll()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(id+" "+String(view.name)+" PNG",image.get_size() == VIEW_SIZE and image.save_png(output_dir.path_join(id+"_crowd_"+String(view.name)+"_1280.png")) == OK)
	_check(id+" static capture does not change units or terrain",battle.units.size() == unit_count and Array(battle.map.grid) == grid_before)
	scenes.append({"id":id,"crowd_count":crowds.size(),"unit_count":unit_count,"directions":directions,"crowds":positions,"stage":"deployment"})
	battle.queue_free()
	await process_frame
	await process_frame

func _write_json(path: String,data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()

class GalleryPlate extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("424b43"))
		draw_string(ThemeDB.fallback_font,Vector2(22,26),"Static scenery · native 50 px canvas + 3x inspection · real alpha / feet at guide",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		for person in range(4):
			for facing in range(4):
				var box := Rect2(20+facing*310,43+person*164,286,150)
				draw_rect(box,Color("768273") if (person+facing)%2 == 0 else Color("8e826b"))
				var label: String = ["vendor","porter","woman","elder"][person]+" / "+["se","sw","ne","nw"][facing]
				draw_string(ThemeDB.fallback_font,box.position+Vector2(8,21),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("18241d"))
				draw_line(Vector2(box.position.x+8,175+person*164),Vector2(box.end.x-8,175+person*164),Color(0.9,0.95,0.9,0.35),1.0)
