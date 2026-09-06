extends SceneTree
## 只对 imagegen 产物做确定性切片、统一比例和透明画布对齐，不绘制或镜像任何角色。
const DIR := "res://assets/campaign/"
const SIZE := 256
const FOOT := 0.82
var report: Dictionary = {"tool":"Godot deterministic slice", "mirrored":false, "frames":[], "objects":[]}

func _initialize() -> void:
	_run.call_deferred()

func _load_image(path: String) -> Image:
	var im := Image.load_from_file(path)
	if im == null or im.is_empty():
		push_error("Missing campaign art source: " + path)
		return Image.new()
	im.convert(Image.FORMAT_RGBA8)
	return im

func _bounds(im: Image, threshold := 0.39) -> Rect2i:
	var left := im.get_width()
	var top := im.get_height()
	var right := -1
	var bottom := -1
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			if im.get_pixel(x,y).a > threshold:
				left = mini(left,x); top = mini(top,y)
				right = maxi(right,x); bottom = maxi(bottom,y)
	if right < left: return Rect2i()
	return Rect2i(left,top,right-left+1,bottom-top+1)

func _frame(source: Image, box: Rect2i, scale: float, size := SIZE) -> Image:
	var safe := box.grow(2).intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	var part := source.get_region(safe)
	var ground := float(box.end.y-safe.position.y)
	part.resize(maxi(1,roundi(safe.size.x*scale)),maxi(1,roundi(safe.size.y*scale)),Image.INTERPOLATE_LANCZOS)
	var dst := Image.create(size,size,false,Image.FORMAT_RGBA8)
	dst.fill(Color.TRANSPARENT)
	var at := Vector2i(roundi((size-part.get_width())*0.5), roundi(size*FOOT-ground*scale))
	dst.blit_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),at)
	return dst

func _save_strip(variant: String,state: String,direction: String,images: Array,portrait_rect := Rect2i(56,0,144,144)) -> void:
	if images.is_empty(): return
	var strip := Image.create(SIZE*images.size(),SIZE,false,Image.FORMAT_RGBA8)
	strip.fill(Color.TRANSPARENT)
	for i in range(images.size()):
		strip.blit_rect(images[i],Rect2i(0,0,SIZE,SIZE),Vector2i(i*SIZE,0))
	var path := DIR+"anim/%s_%s_%s.png" % [variant,state,direction]
	var error := strip.save_png(path)
	report.frames.append({"variant":variant,"state":state,"direction":direction,"count":images.size(),"size":SIZE,"anchor":[0.5,FOOT],"error":error})
	if state=="idle" and direction=="se":
		var portrait: Image = images[0].get_region(portrait_rect)
		portrait.resize(SIZE,SIZE,Image.INTERPOLATE_LANCZOS)
		portrait.save_png(DIR+"portraits/%s.png"%variant)

func _run() -> void:
	for folder in ["anim","objects","portraits"]: DirAccess.make_dir_recursive_absolute(DIR+folder)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"slice_manifest.json"))
	var source := _load_image(DIR+"source/wu_song_mengzhou.png")
	var rows: Array = manifest.wu_song_rows
	var dirs := ["se","sw","ne","nw"]
	for si in range(4):
		var state: String = ["idle","walk","attack","hurt"][si]
		for di in range(4):
			var row: Array = rows[si*2+(1 if di>=2 else 0)]
			var frames: Array = []
			for fi in range(4):
				var b: Array = row[(di%2)*4+fi]
				frames.append(_frame(source,Rect2i(b[0],b[1],b[2],b[3]),1.25))
			_save_strip("wu_song_mengzhou",state,dirs[di],frames)
	for di in range(2):
		var frames: Array = []
		for fi in range(4):
			var b: Array = rows[8][di*4+fi]
			frames.append(_frame(source,Rect2i(b[0],b[1],b[2],b[3]),1.25))
		_save_strip("wu_song_mengzhou","down",dirs[di],frames)
	if manifest.has("wu_song_down_back_rows"):
		var back := _load_image(DIR+"source/wu_song_down_back_final.png")
		var back_rows: Array = manifest.wu_song_down_back_rows
		var scale := 183.0 / float(back_rows[0][0][3])
		for di in range(2):
			var frames: Array = []
			for fi in range(4):
				var b: Array = back_rows[di][fi]
				frames.append(_frame(back,Rect2i(b[0],b[1],b[2],b[3]),scale))
			_save_strip("wu_song_mengzhou","down",dirs[di+2],frames)
	for object_key in manifest.objects:
		var spec: Array = manifest.objects[object_key]
		var original := _load_image(DIR+"source/"+String(spec[0]))
		var a: Array = spec[1]
		var region := Rect2i(a[0],a[1],a[2],a[3]).intersection(Rect2i(Vector2i.ZERO,original.get_size()))
		var cut := original.get_region(region)
		var box := _bounds(cut)
		var max_height := float(box.size.y)
		var max_width := float(box.size.x)
		if String(object_key).begins_with("cuiyun_tower"): max_height=700.0;max_width=570.0
		if String(object_key).begins_with("prison_gate"): max_height=500.0;max_width=600.0
		if String(object_key).begins_with("official_warship"): max_height=565.0;max_width=579.0
		var scale := minf(450.0/max_width,395.0/max_height)
		var result := _frame(cut,box,scale,512)
		var name := String(object_key)
		if not name.ends_with("_default") and not name.ends_with("_signal") and not name.ends_with("_open") and not name.ends_with("_damaged") and not name.ends_with("_flooding") and not name.ends_with("_disabled") and not name.ends_with("_engaged"):
			name += "_default"
		var error := result.save_png(DIR+"objects/"+name+".png")
		report.objects.append({"key":object_key,"error":error,"source":spec[0],"anchor":[0.5,FOOT]})
	if manifest.has("story_sheets"):
		for sheet in manifest.story_sheets:
			_slice_story(sheet)
	var qa := FileAccess.open(DIR+"slice_qa.json",FileAccess.WRITE)
	qa.store_string(JSON.stringify(report,"\t"))
	print("[campaign_art_slice] frames=%d objects=%d" % [report.frames.size(),report.objects.size()])
	quit()

func _slice_story(spec: Dictionary) -> void:
	var image := _load_image(DIR+"source/"+String(spec.source))
	var dirs: Array = spec.get("directions",["se","sw","ne","nw"])
	var rows: Array = spec.rows
	var scale := float(spec.get("scale",1.0))
	for variant in spec.variants:
		var states: Dictionary = spec.variants[variant]
		for state in states:
			for di in range(dirs.size()):
				var frames: Array = []
				for row_index in states[state]:
					var cell: Variant = rows[int(row_index)][di]
					var b: Array = cell.box if cell is Dictionary else cell
					var frame_source: Image = image
					var frame_scale := scale
					# 补画的另一步可来自独立图集；只选源区域，仍不镜像或绘制像素。
					if cell is Dictionary:
						frame_source = _load_image(DIR+"source/"+String(cell.get("source",spec.source)))
						frame_scale = float(cell.get("scale",scale))
					frames.append(_frame(frame_source,Rect2i(b[0],b[1],b[2],b[3]),frame_scale))
				var pr: Array = spec.get("portrait_regions",{}).get(variant,[56,0,144,144])
				_save_strip(variant,state,dirs[di],frames,Rect2i(pr[0],pr[1],pr[2],pr[3]))
