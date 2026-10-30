extends RefCounted
## Actual-displacement-driven spokes for the adopted separated chapter16 carts. Draw into Unit's existing command list, preserving
## its body/selection/name ordering. One explicitly omitted visual angle is kept;
## no scene nodes, materials or persistent save fields are introduced.
const BODY: Texture2D = preload("res://assets/characters/tribute_cart_wheel_runtime_20261018/cart_body.png")
const RIM: Texture2D = preload("res://assets/characters/tribute_cart_wheel_runtime_20261018/rim_hub.png")
const SPOKES: Texture2D = preload("res://assets/characters/tribute_cart_wheel_runtime_20261018/spokes.png")
const FIT: Dictionary = {"se":{"region":[0,0,627,730],"rim_uniform_scale":0.6573208722741433,"rim_translation_original_native":[101.58722741433024,161.6635514018692],"rim_plane_center":[287.9614104562497,444.8633778489278],"rim_inner_plane_axes":[[-63.887203826993236,36.05441048568881],[21.720730724331936,106.04686834872263]],"spoke_plane_center":[314.4688771708603,467.65389465237575],"spoke_normalization_axes":[[-100.58802927544117,60.02104165506171],[43.50715469311171,138.7679414507356]],"spoke_end_overlap":1.06,"clip_inner_radius":1.04,"phase_sign":1,"pose":{"region":[0,0,635,661],"margin":[909.1581609195403,1211.8999999999999,1238,1212],"pivot_native":[27.341839080459764,323.96],"virtual_canvas_reference":494.0,"draw_scale":3.791497975708502,"draw_offset_px":[0,0],"visible_top":0.7607581420181526,"source":"cart_only","independent_cart":false,"cart_depth_pixels":347,"operations":"Same unchanged cart PNG/region/uniform scale at a fixed per-direction offset, shared by idle/walk/interruption. No per-frame cart motion or bitmap edits."},"body_region":[0,0,627,627],"radius_original_native":105.82866043613707},"sw":{"region":[627,0,627,730],"rim_uniform_scale":0.6509433962264151,"rim_translation_original_native":[311.13633000369964,160.2358490566038],"rim_plane_center":[1018.525280063448,492.58947159710516],"rim_inner_plane_axes":[[-51.606767515308434,-46.61344276074997],[-23.242476341069807,103.49882982956872]],"spoke_plane_center":[987.4452024055291,511.94925650001494],"spoke_normalization_axes":[[-93.16741400340166,-65.31282099845166],[-43.514148884864426,139.84018508079734]],"spoke_end_overlap":1.06,"clip_inner_radius":1.04,"phase_sign":-1,"pose":{"region":[635,0,619,661],"margin":[315.5812308055754,1152.88,1195,1153],"pivot_native":[1226.4187691944246,334.6],"virtual_canvas_reference":515.0,"draw_scale":3.5223300970873788,"draw_offset_px":[0,0],"visible_top":0.7628886438809261,"source":"cart_only","independent_cart":false,"cart_depth_pixels":353,"operations":"Same unchanged cart PNG/region/uniform scale at a fixed per-direction offset, shared by idle/walk/interruption. No per-frame cart motion or bitmap edits."},"body_region":[627,0,627,627],"radius_original_native":103.8254716981132},"ne":{"region":[0,730,627,524],"rim_uniform_scale":0.6466876971608833,"rim_translation_original_native":[180.8236690624085,323.7697160883281],"rim_plane_center":[485.17034173348605,964.6911989308896],"rim_inner_plane_axes":[[-54.80075344450778,-44.118594267338445],[-23.51409338080821,102.82055819068911]],"spoke_plane_center":[487.0163482618227,943.8925148762919],"spoke_normalization_axes":[[-91.38937732638078,-65.11278731716821],[-44.50636988537375,133.70259367876764]],"spoke_end_overlap":1.06,"clip_inner_radius":1.04,"phase_sign":1,"pose":{"region":[0,661,635,593],"margin":[532.6575733544806,318.48,533,575],"pivot_native":[51.342426645519396,1300.28],"virtual_canvas_reference":644.0,"draw_scale":1.813664596273292,"draw_offset_px":[0,0],"visible_top":0.29750000000000004,"source":"cart_only","independent_cart":false,"cart_depth_pixels":360,"operations":"Same unchanged cart PNG/region/uniform scale at a fixed per-direction offset, shared by idle/walk/interruption. No per-frame cart motion or bitmap edits."},"body_region":[0,627,627,627],"radius_original_native":102.5},"nw":{"region":[627,730,627,524],"rim_uniform_scale":0.6307692307692307,"rim_translation_original_native":[211.02274607113327,328.8461538461539],"rim_plane_center":[911.6040567282322,1012.2201929419525],"rim_inner_plane_axes":[[-64.51050844041096,37.29358405560524],[22.549247972387782,106.69216427697741]],"spoke_plane_center":[866.8403561503998,985.8646004650371],"spoke_normalization_axes":[[-98.74181303012388,64.84706095721675],[46.79709350120829,136.8272234348318]],"spoke_end_overlap":1.06,"clip_inner_radius":1.04,"phase_sign":-1,"pose":{"region":[635,661,619,593],"margin":[0.26571546732839124,360.7399999999999,558,584],"pivot_native":[1223.2342845326716,1265.4],"virtual_canvas_reference":645.0,"draw_scale":1.8248062015503876,"draw_offset_px":[0,0],"visible_top":0.34727272727272707,"source":"cart_only","independent_cart":false,"cart_depth_pixels":361,"operations":"Same unchanged cart PNG/region/uniform scale at a fixed per-direction offset, shared by idle/walk/interruption. No per-frame cart motion or bitmap edits."},"body_region":[627,627,627,627],"radius_original_native":102.5}}

const CART_POSES: Dictionary = {"chao_gai":{"se":{"pivot_native":[111.32183908045977,403.0],"virtual_canvas_reference":494.0,"draw_offset_px":[0,0]},"sw":{"pivot_native":[1138.8687691944247,417.0],"virtual_canvas_reference":515.0,"draw_offset_px":[0,0]},"ne":{"pivot_native":[147.9424266455194,1223.0],"virtual_canvas_reference":644.0,"draw_offset_px":[0,0]},"nw":{"pivot_native":[1126.4842845326716,1188.0],"virtual_canvas_reference":645.0,"draw_offset_px":[0,0]}},"wu_yong":{"se":{"pivot_native":[111.32183908045977,403.0],"virtual_canvas_reference":494.0,"draw_offset_px":[0,0]},"sw":{"pivot_native":[1138.8687691944247,417.0],"virtual_canvas_reference":515.0,"draw_offset_px":[0,0]},"ne":{"pivot_native":[147.9424266455194,1223.0],"virtual_canvas_reference":644.0,"draw_offset_px":[0,0]},"nw":{"pivot_native":[1126.4842845326716,1188.0],"virtual_canvas_reference":645.0,"draw_offset_px":[0,0]}}}

static func enabled(unit) -> bool:
	return is_instance_valid(unit) and unit.key in ["ruan_xiaoqi", "chao_gai", "wu_yong"] \
		and unit.art_variant == "hn_" + unit.key \
		and is_instance_valid(unit.map) and unit._campaign_tribute_push_active() \
		and FIT.has(unit.animation_direction)

static func _pose(unit) -> Dictionary:
	# Each actor retains its authored cart-to-hand registration. Shared wheel
	# textures must not borrow Ruan Xiaoqi's pivot or body scale.
	if CART_POSES.has(unit.key): return CART_POSES[unit.key][unit.animation_direction]
	return FIT[unit.animation_direction].pose

static func phase_delta(unit, actual_delta: Vector2, body_size: float) -> float:
	if not enabled(unit) or not unit.is_inside_tree() or not unit.get_parent() is Node2D:
		return 0.0
	# Recoil and action timers cannot spin a parked wheel. An off-tree sampling
	# position is not movement, nor is camera scrolling/zooming.
	if unit._lunge > 0.0 or unit._cast_t > 0.0 or unit._shi_en_hurt_t > 0.0 or unit._flinch.length_squared() > 1.0:
		return 0.0
	if not actual_delta.is_finite() or not is_finite(body_size) or body_size <= 0.0:
		return 0.0
	var row: Dictionary=FIT[unit.animation_direction]
	var parent_to_world: Transform2D=unit.get_parent().get_global_transform()
	var old_position: Vector2=unit.position-actual_delta
	var height_delta: float=unit.map.height_at(unit.position)-unit.map.height_at(old_position)
	var paint_delta: Vector2=actual_delta-Vector2.ONE*height_delta
	var distance: float=(parent_to_world.x*paint_delta.x+parent_to_world.y*paint_delta.y).length()
	var billboard_to_world: Transform2D=unit.get_global_transform()*unit.map.ISO_INV
	var local_radius: float=float(row.radius_original_native)*body_size/float(_pose(unit).virtual_canvas_reference)
	var radius: float=(billboard_to_world.y*local_radius).length()
	if not is_finite(distance) or not is_finite(radius) or radius <= 0.0001:
		return 0.0
	# Only a transient visual angle advances. Original gait, dust and their RNG
	# cadence remain unchanged. Save restore rebuilds this cache at angle zero.
	return distance/radius

static func _matrix(values: Array) -> Transform2D:
	return Transform2D(Vector2(values[0][0],values[1][0]),Vector2(values[0][1],values[1][1]),Vector2.ZERO)

static func _point(geometry: Dictionary, native: Vector2, scale_native: float) -> Vector2:
	var pose: Dictionary=geometry.get("pose", geometry)
	var pivot: Array=pose.pivot_native
	var offset: Array=pose.draw_offset_px
	return (native-Vector2(pivot[0],pivot[1])+Vector2(offset[0],offset[1]))*scale_native

static func draw_cart(unit, body_size: float, tint: Color) -> void:
	var row: Dictionary=FIT[unit.animation_direction]
	var pose: Dictionary=_pose(unit)
	var scale_native: float=body_size/float(pose.virtual_canvas_reference)
	var alpha:=Color(1,1,1,tint.a)
	unit.draw_set_transform_matrix(unit.map.ISO_INV)
	var body: Array=row.body_region
	unit.draw_texture_rect_region(BODY,Rect2(_point(pose,Vector2(body[0],body[1]),scale_native),Vector2(body[2],body[3])*scale_native),Rect2(body[0],body[1],body[2],body[3]),alpha)
	var sr: float=row.rim_uniform_scale
	var tr:=Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])
	var rc:=Vector2(row.rim_plane_center[0],row.rim_plane_center[1])
	var sc:=Vector2(row.spoke_plane_center[0],row.spoke_plane_center[1])
	var ar:=_matrix(row.rim_inner_plane_axes)
	var source_plane:=_matrix(row.spoke_normalization_axes)
	var theta: float=fposmod(float(unit._tribute_wheel_angle)*float(row.phase_sign),TAU)
	var inverse_rotation:=Transform2D(-theta,Vector2.ZERO)
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	var native_size:=Vector2(SPOKES.get_width(),SPOKES.get_height())
	# Affine UVs on a convex ellipse clip the rotating source without changing
	# Unit.material, creating child canvases or drawing over Unit's later HUD.
	for i in range(64):
		var angle:=TAU*float(i)/64.0
		var q:=Vector2(cos(angle),sin(angle))*float(row.clip_inner_radius)
		points.append(_point(pose,tr+sr*(rc+ar*q),scale_native))
		uv.append((sc+source_plane*(inverse_rotation*q/float(row.spoke_end_overlap)))/native_size)
	unit.draw_colored_polygon(points,alpha,uv,SPOKES)
	var region: Array=row.region
	unit.draw_texture_rect_region(RIM,Rect2(_point(pose,tr+sr*Vector2(region[0],region[1]),scale_native),Vector2(region[2],region[3])*sr*scale_native),Rect2(region[0],region[1],region[2],region[3]),alpha)
