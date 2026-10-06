extends SceneTree
## Static 12-pose comparison only. No walking animation or original Unit routing.
class PairCanvas extends Node2D:
	var font: Font=ThemeDB.fallback_font
	var character: String=""
	var checks: Array=[]
	var retained: Array=[]
	func _ready() -> void:
		var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://contact_pair_config.json"))
		character=String(config.character)
	func _draw() -> void:
		draw_rect(Rect2(0,0,900,860),Color("25312d"))
		draw_string(font,Vector2(18,27),"Shi Qian | 12 native poses | DIAGNOSTIC contacts; no passing or full gait",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		var directions:=["se","sw","ne","nw"]
		var rows:=[["idle",0,"IDLE"],["walk",0,"SUPPORT A"],["walk",1,"SUPPORT B"]]
		for row in range(3):
			draw_string(font,Vector2(18,65+row*265),String(rows[row][2]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
			for column in range(4):
				var d: String=directions[column]
				var state: String=rows[row][0]
				var index: int=rows[row][1]
				var path: String="res://assets/anim/"+character+"_"+state+"_"+d+".tres"
				var sf: SpriteFrames=load(path)
				var frame: Texture2D=sf.get_frame_texture(&"default",index)
				retained.append(sf)
				retained.append(frame)
				var scale_value: float=float(frame.get_meta("draw_scale",1.0))
				var drawn_size: float=232.0*scale_value
				var target:=Vector2(110+column*210,270+row*265)
				var offset: Vector2=frame.get_meta("draw_offset_px",Vector2.ZERO)
				var rect:=Rect2(target+Vector2(-drawn_size*.5,-drawn_size*.82)+offset*drawn_size/frame.get_height(),Vector2.ONE*drawn_size)
				draw_line(target-Vector2(70,0),target+Vector2(70,0),Color("65776b"),1)
				draw_line(target-Vector2(0,6),target+Vector2(0,6),Color("9bc985"),1)
				draw_texture_rect(frame,rect,false)
				draw_string(font,target+Vector2(-15,24),d.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
				checks.append({"direction":d,"state":state,"index":index,"resource":path,
					"frame_count":sf.get_frame_count(&"default"),"directional":frame.get_meta("authored_direction4",false),
					"draw_scale":scale_value,"offset":[offset.x,offset.y]})
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var vp:=SubViewport.new()
	vp.size=Vector2i(900,860)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas:=PairCanvas.new()
	vp.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var code:=vp.get_texture().get_image().save_png("res://contact_pair_matrix_v4.png")
	var f:=FileAccess.open("res://contact_pair_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":code==OK,"checks":canvas.checks,"diagnostic_only":true,
		"scope":"Real SpriteFrames static idle/A/B comparison; no passing, continuous animation, actual Unit, Battle or campaign qualification"},"  "))
	quit(0 if code==OK else 1)
