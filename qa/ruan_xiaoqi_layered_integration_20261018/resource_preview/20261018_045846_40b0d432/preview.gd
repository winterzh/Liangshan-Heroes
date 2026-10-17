extends SceneTree

var checks: Array = []
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)

class Stage extends Node2D:
	var textures: Array = []
	var cart: Texture2D
	var direction := "se"
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("272621"))
		var labels := ["IDLE", "CONTACT A", "PASSING A", "CONTACT B", "PASSING B", "ADOPTED UNLOADED BODY"]
		for i in range(6):
			var origin := Vector2(220+(i%2)*640,160+(i/2)*230)
			var size := 122.0
			draw_string(ThemeDB.fallback_font,Vector2(18+(i%2)*640,28+(i/2)*230),direction.to_upper()+" / "+labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
			if i<5 and direction in ["ne","nw"]: paint(cart,origin,size)
			paint(textures[i],origin,size)
			if i<5 and direction in ["se","sw"]: paint(cart,origin,size)
	func paint(frame: Texture2D, origin: Vector2, body_size: float) -> void:
		var size := body_size*float(frame.get_meta("draw_scale",1.0))
		var rect := Rect2(origin+Vector2(-size*.5,-size*.82),Vector2(size,size))
		rect.position += Vector2(frame.get_meta("draw_offset_px",Vector2.ZERO))*size/float(frame.get_height())
		draw_texture_rect(frame,rect,false)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var texture_references := {}
	for path in config.textures:
		var tex: Texture2D=load("res://"+String(path))
		check(tex!=null,"native texture "+String(path))
		if tex==null:continue
		var image := tex.get_image()
		if image.is_compressed():check(image.decompress()==OK,"decompress "+String(path))
		check([image.get_width(),image.get_height()]==config.textures[path].size,"original native dimensions "+String(path))
		check(image.has_mipmaps(),"imported mipmaps "+String(path))
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		texture_references[path]={"size":[image.get_width(),image.get_height()],"format":image.get_format(),"mipmaps":image.has_mipmaps(),"data_sha256":hash.finish().hex_encode()}
	var stage:=Stage.new();stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;root.add_child(stage)
	var screenshots: Array=[]
	for d in ["se","sw","ne","nw"]:
		stage.direction=d;stage.textures=[]
		var cart_frames: SpriteFrames=load("res://assets/anim/ruan_xiaoqi_layered_20261018_parked_cart_"+d+".tres")
		stage.cart=cart_frames.get_frame_texture("default",0)
		check(not bool(stage.cart.get_meta("independent_cart",true)),"cart is one independent fixed layer "+d)
		for state in ["push_idle","push_walk"]:
			var frames: SpriteFrames=load("res://assets/anim/ruan_xiaoqi_layered_20261018_"+state+"_"+d+".tres")
			check(frames.get_frame_count("default")==m.states[state].size(),"native resource count "+state+d)
			for i in range(m.states[state].size()):
				var frame: AtlasTexture=frames.get_frame_texture("default",i)
				var pose: Dictionary=m.poses[String(m.states[state][i])+"_"+d]
				check(bool(frame.get_meta("independent_cart",false)),"body has separate cart metadata "+state+d+str(i))
				check(frame.atlas.resource_path=="res://"+String(m.sources[pose.source].path),"bound source atlas "+state+d+str(i))
				check(frame.region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"exact source region "+state+d+str(i))
				check(float(frame.get_meta("draw_scale",0.0))>=.25 and float(frame.get_meta("draw_scale",9.0))<=4,"unit display scale supported "+state+d+str(i))
				stage.textures.append(frame)
		var unloaded: SpriteFrames=load("res://"+String(config.empty_resources[d]));stage.textures.append(unloaded.get_frame_texture("default",0));stage.queue_redraw()
		for n in range(8):await process_frame
		await RenderingServer.frame_post_draw
		var name: String="layer_poses_"+d+".png"
		check(root.get_texture().get_image().save_png("res://"+name)==OK,"save raw native preview "+d)
		screenshots.append(name)
	var report={"art_resource_preview_complete":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"texture_references":texture_references,"scope":"Native imported SpriteFrames art comparison only: no production ArtDB/Unit/Battle or PCK/Steam. Four static authored walk phases, not full anatomical gait or physics playback acceptance."}
	FileAccess.open("res://report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LAYER_RESOURCE_PREVIEW ",checks.size()," / failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
