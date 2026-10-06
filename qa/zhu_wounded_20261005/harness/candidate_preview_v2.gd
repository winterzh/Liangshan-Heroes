extends SceneTree

class PoseCanvas extends Node2D:
	var font: Font = ThemeDB.fallback_font
	var checks: Array = []
	var retained_resources: Array = []
	func _draw():
		draw_rect(Rect2(0,0,1280,1000),Color("25312d"))
		draw_string(font,Vector2(35,36),"Shi Qian adult proportion candidates | native SpriteFrames + Unit draw metadata",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
		var dirs = ["se","sw","ne","nw"]
		for row in range(4):
			var direction: String = dirs[row]
			for column in range(3):
				var state := "idle" if column==0 else "walk"
				var resource_path := "res://assets/anim/zhu_wounded_shi_qian_"+state+"_"+direction+".tres"
				var sf: SpriteFrames = load(resource_path)
				var index := 0 if column<2 else 2
				var frame: Texture2D = sf.get_frame_texture(&"default",index)
				# RenderingServer consumes queued draw commands after _draw returns.
				# Retain both the frame and its atlas until the captured render finishes.
				retained_resources.append(sf)
				retained_resources.append(frame)
				var s := 248.0
				var scale_meta: float = frame.get_meta("draw_scale",1.0)
				var drawn_size := s*scale_meta
				var target := Vector2(230+column*390,275+row*230)
				var offset_meta: Vector2 = frame.get_meta("draw_offset_px",Vector2.ZERO)
				var rect := Rect2(target+Vector2(-drawn_size*.5,-drawn_size*.82)+offset_meta*drawn_size/frame.get_height(),Vector2.ONE*drawn_size)
				draw_line(target-Vector2(85,0),target+Vector2(85,0),Color("65776b"),1)
				draw_line(target-Vector2(0,8),target+Vector2(0,8),Color("9bc985"),1)
				draw_texture_rect(frame,rect,false)
				draw_string(font,target+Vector2(-95,30),direction.to_upper()+" "+["IDLE / passing","STEP A","STEP B"][column],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
				checks.append({"direction":direction,"state":state,"index":index,"texture_size":[frame.get_width(),frame.get_height()],"directional":frame.get_meta("authored_direction4",false),"draw_scale":scale_meta,"offset":[offset_meta.x,offset_meta.y]})

func _initialize():call_deferred("_run")
func _run():
	var vp:=SubViewport.new()
	vp.size=Vector2i(1280,1000)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas:=PoseCanvas.new()
	vp.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var img:=vp.get_texture().get_image()
	var code:=img.save_png("res://pose_matrix.png")
	var f:=FileAccess.open("res://preview_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":code==OK,"checks":canvas.checks,"scope":"Twelve candidate poses rendered with real SpriteFrames and Unit metadata. Isolated art preview, no campaign rescue or continuous gait qualification."},"  "))
	quit(0 if code==OK else 1)
