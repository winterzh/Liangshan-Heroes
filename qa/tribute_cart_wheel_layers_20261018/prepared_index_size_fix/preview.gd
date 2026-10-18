extends SceneTree

var checks: Array = []
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)

class Stage extends Node2D:
	var original: Texture2D
	var body: Texture2D
	var wheel: Texture2D
	var layout: Dictionary
	var direction := "se"
	func paint_native(tex: Texture2D, region: Array, origin: Vector2, scale_native := 1.0, translation := Vector2.ZERO) -> void:
		var p: Dictionary = layout.directions[direction].original_cart_pose
		var reference := float(p.virtual_canvas_reference)
		var top := Vector2(float(region[0]),float(region[1]))*scale_native+translation
		var size := Vector2(float(region[2]),float(region[3]))*scale_native
		var pivot := Vector2(float(p.pivot_native[0]),float(p.pivot_native[1]))
		var offset := Vector2(float(p.draw_offset_px[0]),float(p.draw_offset_px[1]))
		var rect := Rect2(origin+(top-pivot+offset)*270.0/reference,size*270.0/reference)
		draw_texture_rect_region(tex,rect,Rect2(region[0],region[1],region[2],region[3]))
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("272621"))
		var row: Dictionary=layout.directions[direction]
		draw_string(ThemeDB.fallback_font,Vector2(24,34),direction.to_upper()+" / ADOPTED CART",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(660,34),"BODY + SEPARATE WHEEL / CANDIDATE",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		paint_native(original,row.original_cart_pose.region,Vector2(120,440))
		paint_native(body,row.body_region,Vector2(760,440))
		paint_native(wheel,row.wheel_region,Vector2(760,440),float(row.wheel_uniform_scale),Vector2(float(row.wheel_translation_original_native[0]),float(row.wheel_translation_original_native[1])))
		draw_string(ThemeDB.fallback_font,Vector2(24,680),"Static layer fit only. No actor, world motion, wheel rotation or final acceptance.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c9c6be"))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,720)
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://component_layout.json"))
	var textures: Dictionary={}
	var references: Dictionary={}
	for key in inputs.textures:
		var row: Dictionary=inputs.textures[key]
		var tex: Texture2D=load("res://"+String(row.path))
		check(tex!=null,"native texture "+String(key))
		if tex==null: continue
		var im:=tex.get_image()
		if im.is_compressed():check(im.decompress()==OK,"decompress "+String(key))
		var expected_size: Array=row["size"]
		check(im.get_width()==int(expected_size[0]) and im.get_height()==int(expected_size[1]),"native original dimensions "+String(key))
		check(im.has_mipmaps(),"native mipmaps "+String(key))
		var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(im.get_data())
		references[key]={"size":[im.get_width(),im.get_height()],"format":im.get_format(),"mipmaps":im.has_mipmaps(),"data_sha256":h.finish().hex_encode()}
		textures[key]=tex
	var screenshots: Array=[]
	if textures.size()==3:
		var stage:=Stage.new();stage.original=textures.original;stage.body=textures.cart_body;stage.wheel=textures.wheel_only;stage.layout=layout;stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;root.add_child(stage)
		for d in ["se","sw","ne","nw"]:
			stage.direction=d;stage.queue_redraw()
			for i in range(8):await process_frame
			await RenderingServer.frame_post_draw
			var name: String="cart_layers_"+d+".png"
			check(root.get_texture().get_image().save_png("res://"+name)==OK,"save static native layer fit "+d)
			screenshots.append(name)
	var report={"art_resource_preview_complete":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"texture_references":references,"scope":"Standalone static cart-body/wheel layer fit only. No production SpriteFrames, Unit, physics, actual rolling, final original-cart geometry, game/PCK or Steam qualification."}
	FileAccess.open("res://report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("CART_LAYER_PREVIEW ",checks.size()," / failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
