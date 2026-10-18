extends SceneTree

var checks: Array = []
var failures: Array = []
var screenshots: Array = []
var observations: Array = []
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures.append(label)

class Stage extends Node2D:
	var images: Dictionary
	var fit: Dictionary
	var direction := "se"
	var travel := 0.0
	var spokes := Sprite2D.new()
	var rim := Sprite2D.new()
	var clip_material := ShaderMaterial.new()
	func _ready() -> void:
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
uniform vec2 source_center;
uniform vec2 native_size;
uniform vec4 source_inverse;
uniform float clip_radius;
void fragment() {
 vec2 q=UV*native_size-source_center;
 vec2 plane=vec2(dot(source_inverse.xy,q),dot(source_inverse.zw,q));
 if(length(plane)>clip_radius) discard;
}
"""
		clip_material.shader=shader
		spokes.texture=images.spokes;spokes.region_enabled=true;spokes.centered=false;spokes.material=clip_material
		rim.texture=images.rim_hub;rim.region_enabled=true;rim.centered=false;rim.z_index=1
		add_child(spokes);add_child(rim)
	func matrix(a: Array) -> Transform2D:
		return Transform2D(Vector2(a[0][0],a[1][0]),Vector2(a[0][1],a[1][1]),Vector2.ZERO)
	func point(panel: int, p: Vector2) -> Vector2:
		var pose: Dictionary=fit.directions[direction].original_cart_pose
		var reg: Array=pose.region
		return Vector2(360+720*panel,430)+(p-Vector2(reg[0]+reg[2]*.5,reg[1]+reg[3]*.5))*400.0/float(pose.virtual_canvas_reference)
	func paint(panel: int, image: Texture2D, region: Array) -> void:
		var unit: float=400.0/float(fit.directions[direction].original_cart_pose.virtual_canvas_reference)
		draw_texture_rect_region(image,Rect2(point(panel,Vector2(region[0],region[1])),Vector2(region[2],region[3])*unit),Rect2(region[0],region[1],region[2],region[3]))
	func configure(d: String, distance: float) -> void:
		direction=d;travel=distance
		var row: Dictionary=fit.directions[d]
		var region: Array=row.region
		var rect:=Rect2(region[0],region[1],region[2],region[3])
		var sr: float=row.rim_uniform_scale
		var unit: float=400.0/float(row.original_cart_pose.virtual_canvas_reference)
		var tr:=Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])
		var rc:=Vector2(row.rim_plane_center[0],row.rim_plane_center[1])
		var sc:=Vector2(row.spoke_plane_center[0],row.spoke_plane_center[1])
		var ar:=matrix(row.rim_inner_plane_axes)
		var inv:=matrix(row.spoke_normalization_axes).affine_inverse()
		var phase: float=row.phase_sign*distance/row.test_radius_original_native
		var basis:=ar*Transform2D(phase,Vector2.ZERO)*inv
		basis.x*=float(row.spoke_end_overlap);basis.y*=float(row.spoke_end_overlap)
		var origin:=point(1,tr+sr*(rc+basis*(rect.position-sc)))
		spokes.region_rect=rect
		spokes.transform=Transform2D(basis.x*sr*unit,basis.y*sr*unit,origin)
		rim.region_rect=rect;rim.position=point(1,tr+sr*rect.position);rim.scale=Vector2.ONE*sr*unit
		clip_material.set_shader_parameter("source_center",sc)
		clip_material.set_shader_parameter("native_size",Vector2(images.spokes.get_width(),images.spokes.get_height()))
		clip_material.set_shader_parameter("source_inverse",Vector4(inv.x.x,inv.y.x,inv.x.y,inv.y.y))
		clip_material.set_shader_parameter("clip_radius",float(row.clip_inner_radius)/float(row.spoke_end_overlap))
		queue_redraw()
	func wheel_center() -> Vector2:
		var row: Dictionary=fit.directions[direction]
		return point(1,Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])+float(row.rim_uniform_scale)*Vector2(row.rim_plane_center[0],row.rim_plane_center[1]))
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,820),Color("292824"))
		draw_string(ThemeDB.fallback_font,Vector2(30,48),direction.to_upper()+" / ADOPTED CART",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(750,48),"NATIVE SPOKE-PLANE PROTOTYPE",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		var row: Dictionary=fit.directions[direction]
		paint(0,images.original,row.original_cart_pose.region)
		paint(1,images.cart_body,row.original_cart_pose.region)
		draw_string(ThemeDB.fallback_font,Vector2(28,790),"Raw PNGs unchanged. Simulated displacement; no Unit, world motion, PCK or final rolling acceptance.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c8c0ae"))

func capture(stage: Stage, d: String, travel: float, label: String) -> Image:
	stage.configure(d,travel)
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var name:=label+".png"
	check(image.save_png("res://"+name)==OK,"save native projection "+label)
	screenshots.append(name)
	observations.append({"name":name,"direction":d,"simulated_native_travel":travel,"fixed_wheel_center":[stage.wheel_center().x,stage.wheel_center().y]})
	return image

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size=Vector2i(1440,820)
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
	var fit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://projection_fit.json"))
	var images: Dictionary={};var references: Dictionary={}
	for key in inputs.textures:
		var row: Dictionary=inputs.textures[key]
		var texture: Texture2D=load("res://"+String(row.path))
		check(texture!=null,"native texture "+String(key))
		if texture==null:continue
		var image:=texture.get_image()
		if image.is_compressed():check(image.decompress()==OK,"decompress "+String(key))
		check(image.get_size()==Vector2i(row["size"][0],row["size"][1]),"native original dimensions "+String(key))
		check(image.has_mipmaps(),"native mipmaps "+String(key))
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		references[key]={"size":[image.get_width(),image.get_height()],"format":image.get_format(),"mipmaps":image.has_mipmaps(),"data_sha256":hash.finish().hex_encode()};images[key]=texture
	if images.size()==4:
		var stage:=Stage.new();stage.images=images;stage.fit=fit;stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;root.add_child(stage)
		for d in ["se","sw","ne","nw"]:await capture(stage,d,0,"native_"+d+"_0")
		var zero: Image=await capture(stage,"se",0,"native_se_baseline")
		var center:=stage.wheel_center()
		var prior: Image=zero
		for travel in [20.75,41.5,62.25]:
			var image: Image=await capture(stage,"se",travel,"native_se_"+str(travel).replace(".","_"))
			check(stage.wheel_center().distance_to(center)<.0001,"phase does not move fitted rim center "+str(travel))
			var changed:=0;var outside:=0
			# SE fitted ellipse is bounded by this generous static square. Exact
			# pixel delta bounds are retained separately for direct review.
			var lower:=Vector2i(1440,820);var upper:=Vector2i.ZERO
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if prior.get_pixel(x,y)==image.get_pixel(x,y):continue
					changed+=1;lower=lower.min(Vector2i(x,y));upper=upper.max(Vector2i(x,y))
					if Vector2(x,y).distance_to(center)>130.0:outside+=1
			check(changed>20,"native phase changes spoke pixels "+str(travel))
			check(outside==0,"phase leaves original panel and remote body intact "+str(travel))
			observations.append({"travel":travel,"changed_pixels":changed,"outside_wheel_neighborhood":outside,"bounds":[lower.x,lower.y,upper.x,upper.y]});prior=image
		var paused: Image=await capture(stage,"se",62.25,"native_se_paused")
		check(paused.get_data()==prior.get_data(),"unchanged simulated displacement holds exact native frame")
	var report={"art_resource_preview_complete":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"observations":observations,"texture_references":references,"scope":"Independent four-original-texture Godot spoke-plane prototype with fixed rim/hub and simulated displacement. No real Unit/world movement, physical axle validation, game/PCK, production adoption or final rolling qualification."}
	FileAccess.open("res://report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("NATIVE_SPOKE_PLANE ",checks.size()," / failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
