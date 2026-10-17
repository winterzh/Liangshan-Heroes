extends SceneTree

class ArtStage extends Node2D:
	var config: Dictionary
	var pictures: Dictionary
	var variant := 0
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("272621"))
		var font := ThemeDB.fallback_font
		var dirs := ["se", "sw", "ne", "nw"]
		var size := 124.0 if variant == 0 else 176.0
		for i in range(4):
			var d: String = dirs[i]
			var center := 160.0 + i * 320.0
			draw_string(font, Vector2(center-100, 26), d.to_upper()+" - ART PREVIEW ONLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			if variant == 0:
				_pair(d, Vector2(center, 192), size, Vector2.ZERO)
				draw_string(font, Vector2(center-110, 226), "Fixed cart: original offset", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbcda5"))
				_pair(d, Vector2(center, 410), size, Vector2(config.cart_offset[d][0], config.cart_offset[d][1])*size)
				draw_string(font, Vector2(center-110, 444), "Fixed cart: grip-fit candidate", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbcda5"))
				_sprite("empty", config.empty[d], Vector2(center, 646), size)
				draw_string(font, Vector2(center-110, 680), "Adopted unloaded body", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbcda5"))
			else:
				_pair(d, Vector2(center, 327), size, Vector2(config.cart_offset[d][0], config.cart_offset[d][1])*size)
				_sprite("empty", config.empty[d], Vector2(center, 635), size)
				draw_string(font, Vector2(center-100, 366), "New actor + unchanged cart", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbcda5"))
				draw_string(font, Vector2(center-100, 677), "Old body at same unit size", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbcda5"))
		draw_line(Vector2(0, 470 if variant == 0 else 388), Vector2(1280, 470 if variant == 0 else 388), Color("655f4d"), 1)
	func _sprite(key: String, pose: Dictionary, root: Vector2, size: float) -> void:
		var region := Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3])
		var scale_factor := size / float(pose.reference)
		var target := Rect2(root+(region.position-Vector2(pose.pivot[0],pose.pivot[1]))*scale_factor, region.size*scale_factor)
		draw_texture_rect_region(pictures[key], target, region)
	func _pair(d: String, root: Vector2, size: float, cart_offset: Vector2) -> void:
		if d in ["ne", "nw"]: _sprite("cart",config.cart[d],root+cart_offset,size)
		_sprite("actor",config.actor[d],root,size)
		if d in ["se", "sw"]: _sprite("cart",config.cart[d],root+cart_offset,size)

func _initialize() -> void:
	call_deferred("run_preview")

func run_preview() -> void:
	root.size = Vector2i(1280,720)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config.json"))
	var stage := ArtStage.new()
	stage.config = config
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var references: Array = []
	for key in ["actor","cart","empty"]:
		var picture := Image.load_from_file("res://"+key+".png")
		if picture == null or picture.is_empty():
			push_error("Cannot load "+key)
			quit(2)
			return
		stage.pictures[key] = ImageTexture.create_from_image(picture)
		references.append({"key":key,"size":[picture.get_width(),picture.get_height()],"raw_image_texture":true,"imported_mipmap_verified":false})
	root.add_child(stage)
	var screenshots: Array = []
	for i in range(2):
		stage.variant = i
		stage.queue_redraw()
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var filename := "idle_layer_alignment.png" if i == 0 else "idle_body_comparison.png"
		var error := root.get_texture().get_image().save_png("res://"+filename)
		if error != OK:
			push_error("PNG save error "+str(error))
			quit(3)
			return
		screenshots.append(filename)
	var report := {"art_preview_complete":true,"native_game_launched":false,"battle_scene":false,"exported_pack":false,"source_import_mipmap_acceptance":false,"screenshots":screenshots,"textures":references,"scope":"Native Godot CanvasItem art preview; same logical body size, raw PNG ImageTextures, idle only. Not normal game, physics, mission, imported/exported texture or final visual acceptance."}
	var file := FileAccess.open("res://report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("RUAN_LAYER_ART_PREVIEW_COMPLETE")
	quit(0)
