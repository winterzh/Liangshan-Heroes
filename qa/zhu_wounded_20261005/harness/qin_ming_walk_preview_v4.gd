extends SceneTree

class GaitCanvas extends Node2D:
	var font: Font = ThemeDB.fallback_font
	var resources: Dictionary = {}
	var directions := ["se", "sw", "ne", "nw"]
	var matrix := false
	var moving := false
	var phase := 0.0
	var seen: Dictionary = {}
	var samples: Array = []
	var full_phase_matrix := false
	var display_label := "Qin Ming gait candidate"
	func _ready():
		var character := "zhu_wounded_v3_shi_xiu_gait"
		if FileAccess.file_exists("res://gait_character.json"):
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://gait_character.json"))
			character=String(config.character)
			display_label=String(config.get("display_label",display_label))
			full_phase_matrix=bool(config.get("full_phase_matrix",false))
		for direction in directions:
			for state in ["idle", "walk"]:
				var sf: SpriteFrames = load("res://assets/anim/"+character+"_"+state+"_"+direction+".tres")
				resources[state+"_"+direction] = sf
	func _process(delta: float):
		if moving: phase += delta*9.5*0.66*(82.0/72.0)
		queue_redraw()
	func draw_pose(frame: Texture2D, target: Vector2, size: float):
		var scale_meta: float = frame.get_meta("draw_scale", 1.0)
		var drawn_size := size*scale_meta
		var offset: Vector2 = frame.get_meta("draw_offset_px",Vector2.ZERO)
		var rect := Rect2(target+Vector2(-drawn_size*.5,-drawn_size*.82)+offset*drawn_size/frame.get_height(),Vector2.ONE*drawn_size)
		draw_line(target-Vector2(70,0),target+Vector2(70,0),Color("65776b"),1)
		draw_line(target-Vector2(0,7),target+Vector2(0,7),Color("9bc985"),1)
		draw_texture_rect(frame,rect,false)
	func _draw():
		draw_rect(Rect2(0,0,900,1000),Color("25312d"))
		draw_string(font,Vector2(24,28),display_label+" | SpriteFrames | NOT Unit/campaign",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		if matrix:
			var columns := 5 if full_phase_matrix else 3
			var stride := 180 if full_phase_matrix else 280
			var labels := ["IDLE", "STEP A", "PASS A", "STEP B", "PASS B"] if full_phase_matrix else ["IDLE", "STEP A", "STEP B"]
			for column in range(columns):
				draw_string(font,Vector2(50+column*stride if full_phase_matrix else 110+column*stride,58),labels[column],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
			for row in range(4):
				var direction: String = directions[row]
				var idle: SpriteFrames = resources["idle_"+direction]
				var walk: SpriteFrames = resources["walk_"+direction]
				for column in range(columns):
					var frame: Texture2D = idle.get_frame_texture(&"default",0) if column==0 else walk.get_frame_texture(&"default",column-1 if full_phase_matrix else 0 if column==1 else 2)
					var target := Vector2(90+column*stride if full_phase_matrix else 150+column*stride,270+row*230)
					draw_pose(frame,target,200.0 if full_phase_matrix else 232.0)
					draw_string(font,target+Vector2(-15,23),direction.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		else:
			for column in range(4):
				var direction: String = directions[column]
				var state := "walk" if moving else "idle"
				var sf: SpriteFrames = resources[state+"_"+direction]
				var index := int(fposmod(phase,TAU)/TAU*sf.get_frame_count(&"default"))%sf.get_frame_count(&"default") if moving else 0
				var frame: Texture2D = sf.get_frame_texture(&"default",index)
				seen[state+"_"+direction+"_"+str(index)] = true
				draw_pose(frame,Vector2(115+column*220,270),232.0)
				draw_string(font,Vector2(60+column*220,302),direction.to_upper()+" "+state+" "+str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	func sample(time: float, capture: String):
		var indexes: Array = []
		for direction in directions:
			var state := "walk" if moving else "idle"
			var sf: SpriteFrames = resources[state+"_"+direction]
			indexes.append(int(fposmod(phase,TAU)/TAU*sf.get_frame_count(&"default"))%sf.get_frame_count(&"default") if moving else 0)
		samples.append({"time_seconds":time,"moving":moving,"phase":phase,"indexes":indexes,"capture":capture})

func _initialize(): call_deferred("_run")
func _run():
	var vp := SubViewport.new()
	vp.size=Vector2i(900,340)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas := GaitCanvas.new()
	vp.add_child(canvas)
	var start := Time.get_ticks_msec()
	var saved := true
	for i in range(64):
		canvas.moving = i>=5 and i<38 or i>=44 and i<58
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		var path := "live_%03d.png"%i
		saved = saved and vp.get_texture().get_image().save_png("res://"+path)==OK
		canvas.sample((Time.get_ticks_msec()-start)/1000.0,path)
	canvas.set_process(false)
	canvas.matrix=true
	vp.size=Vector2i(900,1000)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	saved=saved and vp.get_texture().get_image().save_png("res://walk_matrix_v3.png")==OK
	var coverage := true
	for direction in canvas.directions:
		coverage=coverage and canvas.seen.has("idle_"+direction+"_0")
		for i in range(4): coverage=coverage and canvas.seen.has("walk_"+direction+"_"+str(i))
	var f := FileAccess.open("res://preview_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":saved and coverage,"captures":canvas.samples,"seen":canvas.seen.keys(),"scope":"Real process-clock SpriteFrames cycle/start/stop render using Unit phase and draw-metadata formulas only; no actual Unit physics, secondary motion or campaign. Visual acceptance separate."},"  "))
	quit(0 if saved and coverage else 1)
