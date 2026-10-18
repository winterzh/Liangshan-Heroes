extends SceneTree
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:failures.append(label)

class Stage extends Node2D:
	var frames: Dictionary
	var poses: Array
	var direction := "se"
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,620),Color("292824"))
		draw_string(ThemeDB.fallback_font,Vector2(24,38),"CH54 GONGSUN SHENG / UNBOUND SOURCE CANDIDATES / "+direction.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
		var keys: Array=["idle_padded","contact_a","passing_a","contact_b","passing_b_v2"]
		var idle: Dictionary={}
		for row: Dictionary in poses:
			if row.key=="idle_padded" and row.direction==direction:idle=row
		# One fixed per-direction scale for all five poses. Do not conceal
		# source body-size/head-height variation with per-frame rescaling.
		var scale_native: float=300.0/(idle.strong_local[3]-idle.strong_local[1]+1.0)
		for i in range(keys.size()):
			var row: Dictionary={}
			for p: Dictionary in poses:
				if p.key==keys[i] and p.direction==direction:row=p
			var x: float=144.0+i*288.0
			var origin:=Vector2(x-313.5*scale_native,485.0-float(row.strong_local[3])*scale_native)
			draw_texture_rect(frames[row.resource],Rect2(origin,Vector2.ONE*627.0*scale_native),false)
			draw_line(Vector2(x-125,486),Vector2(x+125,486),Color("5a5548"),1)
			draw_string(ThemeDB.fallback_font,Vector2(x-125,530),String(keys[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(24,585),"Fixed source scale + grounding only. Anatomy, gait timing, rein/sword continuity and chapter routing remain unqualified.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d3c5a9"))

func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,620)
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
	var references: Dictionary={};var images: Dictionary={};var frames: Dictionary={}
	for key in inputs.textures:
		var row: Dictionary=inputs.textures[key]
		var texture: Texture2D=load("res://"+String(row.path));check(texture!=null,"native original texture "+key)
		if texture==null:continue
		var image:=texture.get_image()
		if image.is_compressed():check(image.decompress()==OK,"decompress "+key)
		check(image.get_size()==Vector2i(1254,1254),"native original dimensions "+key)
		check(image.has_mipmaps(),"native mipmaps "+key)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		references[key]={"size":[image.get_width(),image.get_height()],"format":image.get_format(),"mipmaps":image.has_mipmaps(),"data_sha256":hash.finish().hex_encode()};images[key]=image
	for row: Dictionary in inputs.poses:
		var texture: AtlasTexture=load("res://"+String(row.resource));check(texture!=null,"selected pose loads "+row.resource)
		if texture==null:continue
		var rect: Array=row.region
		check(texture.region==Rect2(rect[0],rect[1],rect[2],rect[3]),"exact original selected region "+row.resource)
		check(texture.get_width()==627 and texture.get_height()==627,"source virtual canvas preserved "+row.resource)
		var image: Image=images[row.key]
		var corners: Array=[Vector2i(rect[0],rect[1]),Vector2i(rect[0]+rect[2]-1,rect[1]),Vector2i(rect[0],rect[1]+rect[3]-1),Vector2i(rect[0]+rect[2]-1,rect[1]+rect[3]-1)]
		var transparent:=true
		for point: Vector2i in corners:transparent=transparent and image.get_pixelv(point).a==0.0
		check(transparent,"native selected corners alpha zero "+row.resource);frames[row.resource]=texture
	var screenshots: Array=[]
	if frames.size()==20:
		var stage:=Stage.new();stage.frames=frames;stage.poses=inputs.poses;stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;root.add_child(stage)
		for d in ["se","sw","ne","nw"]:
			stage.direction=d;stage.queue_redraw()
			for i in range(8):await process_frame
			await RenderingServer.frame_post_draw
			var name: String="mounted_candidates_"+d+".png";check(root.get_texture().get_image().save_png("res://"+name)==OK,"capture five-pose comparison "+d);screenshots.append(name)
	var report={"art_resource_preview_complete":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"texture_references":references,"scope":"Standalone five-original/20-selected-region native source comparison. Whole-cell alpha audit still has two failures, preserved separately; selected regions avoid these unused corners without bitmap edits. No production mounted Unit, anatomy/gait/attack/novel/chapter binding, PCK or final art acceptance. One fixed scale per direction intentionally exposes source size variation."}
	FileAccess.open("res://report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("MOUNTED_RESOURCE_PREVIEW ",checks.size()," / failures ",failures.size());quit(0 if failures.is_empty() else 1)
