extends SceneTree

class PoseCanvas extends Node2D:
	var font: Font = ThemeDB.fallback_font
	var checks: Array = []
	var retained_resources: Array = []
	var keys := ["shi_qian", "shi_xiu", "qin_ming", "yang_lin", "huang_xin", "wang_ying", "deng_fei"]
	var individual: Dictionary = {}
	func _ready():
		if FileAccess.file_exists("res://individual_idle.json"):
			individual=JSON.parse_string(FileAccess.get_file_as_string("res://individual_idle.json"))
	func _draw():
		if not individual.is_empty():
			draw_rect(Rect2(0,0,900,320),Color("25312d"))
			draw_string(font,Vector2(24,28),String(individual.key)+" | "+String(individual.get("context","idle candidate"))+" | NOT campaign",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
			var directions := ["se","sw","ne","nw"]
			for column in range(4):
				var direction: String = directions[column]
				var path: String = "res://assets/anim/"+String(individual.character)+"_idle_"+direction+".tres"
				var sf: SpriteFrames = load(path)
				var frame: Texture2D = sf.get_frame_texture(&"default",0)
				retained_resources.append(sf)
				retained_resources.append(frame)
				var drawn_size := 232.0*float(frame.get_meta("draw_scale",1.0))
				var target := Vector2(110+column*210,270)
				var offset: Vector2 = frame.get_meta("draw_offset_px",Vector2.ZERO)
				var rect := Rect2(target+Vector2(-drawn_size*.5,-drawn_size*.82)+offset*drawn_size/frame.get_height(),Vector2.ONE*drawn_size)
				draw_line(target-Vector2(68,0),target+Vector2(68,0),Color("65776b"),1)
				draw_texture_rect(frame,rect,false)
				draw_string(font,target+Vector2(-15,24),direction.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
				checks.append({"character":individual.key,"direction":direction,"resource":path,"frame_count":sf.get_frame_count(&"default"),"directional":frame.get_meta("authored_direction4",false)})
			return
		draw_rect(Rect2(0,0,1280,1000),Color("25312d"))
		draw_string(font,Vector2(30,30),"Upright rescued idle candidates | native SpriteFrames + Unit draw metadata | NOT campaign qualification",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		var dirs := ["se", "sw", "ne", "nw"]
		for column in range(keys.size()):
			draw_string(font,Vector2(57+column*175,58),keys[column],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
		for row in range(4):
			var direction: String = dirs[row]
			for column in range(keys.size()):
				var key: String = keys[column]
				var path := "res://assets/anim/zhu_wounded_v3_"+key+"_idle_"+direction+".tres"
				var sf: SpriteFrames = load(path)
				var frame: Texture2D = sf.get_frame_texture(&"default",0)
				retained_resources.append(sf)
				retained_resources.append(frame)
				var scale_meta: float = frame.get_meta("draw_scale",1.0)
				var drawn_size := 232.0*scale_meta
				var target := Vector2(110+column*175,270+row*230)
				var offset_meta: Vector2 = frame.get_meta("draw_offset_px",Vector2.ZERO)
				var rect := Rect2(target+Vector2(-drawn_size*.5,-drawn_size*.82)+offset_meta*drawn_size/frame.get_height(),Vector2.ONE*drawn_size)
				draw_line(target-Vector2(68,0),target+Vector2(68,0),Color("65776b"),1)
				draw_line(target-Vector2(0,8),target+Vector2(0,8),Color("9bc985"),1)
				draw_texture_rect(frame,rect,false)
				draw_string(font,target+Vector2(-15,24),direction.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
				checks.append({"character":key,"direction":direction,"resource":path,"frame_count":sf.get_frame_count(&"default"),"texture_size":[frame.get_width(),frame.get_height()],"directional":frame.get_meta("authored_direction4",false),"draw_scale":scale_meta,"offset":[offset_meta.x,offset_meta.y]})

func _initialize(): call_deferred("_run")
func _run():
	var vp := SubViewport.new()
	vp.size=Vector2i(900,320) if FileAccess.file_exists("res://individual_idle.json") else Vector2i(1280,1000)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas := PoseCanvas.new()
	vp.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var code := img.save_png("res://idle_matrix_v3.png")
	var f := FileAccess.open("res://preview_result.json",FileAccess.WRITE)
	var scope := "Individual character x four idle directions" if not canvas.individual.is_empty() else "Seven characters x four idle directions"
	f.store_string(JSON.stringify({"passed":code==OK,"checks":canvas.checks,"scope":scope+" rendered through real SpriteFrames/Unit metadata. No continuous gait or actual campaign qualification."},"  "))
	quit(0 if code==OK else 1)
