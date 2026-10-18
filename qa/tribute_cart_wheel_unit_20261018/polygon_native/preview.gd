extends SceneTree
const Wheel=preload("res://scripts/tribute_cart_wheel_visual.gd")
class MapStub extends RefCounted:
	var ISO_INV:=Transform2D.IDENTITY
class CartPaint extends Node2D:
	var map=MapStub.new()
	var animation_direction:="se"
	var _anim_t:=0.0
	func _draw() -> void: Wheel.draw_cart(self,240.0,Color.WHITE)
var carts: Array=[]
var checks: Array=[]
var shots: Array=[]
var failures: Array=[]
func check(ok: bool,name: String) -> void:
	checks.append({"name":name,"passed":ok})
	if not ok:failures.append(name)
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> Image:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var path:="res://"+name+".png"
	check(image.save_png(path)==OK,"capture "+name)
	shots.append(name+".png")
	return image
func wheel_bounds(cart) -> Rect2i:
	var row: Dictionary=Wheel.FIT[cart.animation_direction]
	var sc:=240.0/float(row.pose.virtual_canvas_reference)
	var tr:=Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])
	var rc:=Vector2(row.rim_plane_center[0],row.rim_plane_center[1])
	var ar:=Wheel._matrix(row.rim_inner_plane_axes)
	var result:=Rect2(cart.position+Wheel._point(row,tr+row.rim_uniform_scale*rc,sc),Vector2.ZERO)
	for i in range(64):
		var a:=TAU*float(i)/64.0
		var q:=Vector2(cos(a),sin(a))*float(row.clip_inner_radius)
		result=result.expand(cart.position+Wheel._point(row,tr+row.rim_uniform_scale*(rc+ar*q),sc))
	return Rect2i(result.position.floor(),result.size.ceil()).grow(3)
func run() -> void:
	root.size=Vector2i(1280,1000);root.position=Vector2i(30000,30000)
	RenderingServer.set_default_clear_color(Color("293036"))
	var label:=Label.new();label.text="Independent cart paint pipeline: original body + fixed rim + polygon UV spokes\nNo real Unit, mission, displacement, saves or gameplay qualification";label.position=Vector2(24,16);root.add_child(label)
	for i in range(4):
		var cart:=CartPaint.new();cart.animation_direction=["se","sw","ne","nw"][i]
		cart.position=Vector2([120,740][i%2],[350,820][i/2]);root.add_child(cart);carts.append(cart)
		var title:=Label.new();title.text=cart.animation_direction;title.position=cart.position+Vector2(0,-250);root.add_child(title)
	for tex: Texture2D in [Wheel.BODY,Wheel.RIM,Wheel.SPOKES]:
		check(tex.get_size()==Vector2(1254,1254),"native source1254 "+tex.resource_path)
		check(tex.get_image().get_mipmap_count()>0,"native mipmaps "+tex.resource_path)
	var base: Image=await capture("polygon_phase_0")
	var still: Image=await capture("polygon_phase_0_still")
	check(base.get_data()==still.get_data(),"unchanged phase is pixel-identical with no timer-driven spin")
	for phase: float in [.61,1.37]:
		for cart in carts:cart._anim_t=phase*Wheel.GAIT_PER_WHEEL;cart.queue_redraw()
		var current: Image=await capture("polygon_phase_"+str(phase).replace(".","_"))
		var changed:=PackedInt32Array([0,0,0,0]);var outside:=0
		var bounds: Array=[]
		for cart in carts:bounds.append(wheel_bounds(cart))
		for y in range(base.get_height()):
			for x in range(base.get_width()):
				if base.get_pixel(x,y)==current.get_pixel(x,y):continue
				var found:=false
				for i in range(4):
					if bounds[i].has_point(Vector2i(x,y)):changed[i]+=1;found=true
				if not found:outside+=1
		check(outside==0,"rotating spokes preserve all pixels outside wheel clips "+str(phase))
		for i in range(4):check(changed[i]>10,"actual polygon pixels change "+carts[i].animation_direction+" "+str(phase))
	var file:=FileAccess.open("res://report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":shots,"art_resource_preview_complete":failures.is_empty(),"scope":"Independent new polygon paint pipeline only. CartPaint is an explicit stand-in; no actual Unit, displacement or game qualification."},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
