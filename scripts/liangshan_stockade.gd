extends Node2D
## 使用现有手绘木寨墙图集；逻辑边界由Layout负责。
var end_local := Vector2.ZERO
var salt := 0
var height_scale := 142.0
var campaign_texture: Texture2D
var campaign_route := ""
var campaign_visible_bbox: Array = []

func _draw() -> void:
	if campaign_texture!=null:
		var source_size := campaign_texture.get_size()
		if source_size.x>0.0 and source_size.y>0.0:
			var bbox := campaign_visible_bbox if campaign_visible_bbox.size()==4 \
				else [0.0,0.0,source_size.x,source_size.y]
			var visible_w := maxf(float(bbox[2]),1.0)
			var visible_h := maxf(float(bbox[3]),1.0)
			var basis_x := end_local/visible_w
			var basis_y := Vector2(0,height_scale/visible_h)
			# Map the accepted image's visible bounds to the complete wall span while
			# still drawing the original 512px texture in one call. Transparent padding
			# stays intact and is never cropped or masked.
			var origin := -basis_x*float(bbox[0])-basis_y*(float(bbox[1])+visible_h)
			var tr := Transform2D(basis_x,basis_y,origin)
			draw_set_transform_matrix(GameMap.ISO_INV*tr)
			draw_texture_rect(campaign_texture,Rect2(Vector2.ZERO,source_size),false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
	var tex := Art.terrain_texture("palisade") as AtlasTexture
	if tex==null:
		return
	# 取无旗帜的木桩/支撑区域，避免墙上重复同一面旗。
	# 原图斜向脚线映射至墙脚，木桩保持竖直。只改变绘制，不改位图。
	var u0 := 0.12
	var u1 := 0.56
	var foot0 := 0.90-(u0-0.16)*0.573333
	var foot1 := 0.90-(u1-0.16)*0.573333
	var crop := Rect2(tex.region.position+Vector2(tex.region.size.x*u0,0),Vector2(tex.region.size.x*(u1-u0),tex.region.size.y))
	var basis_x := end_local/crop.size.x+Vector2(0,(foot0-foot1)*height_scale/crop.size.x)
	var basis_y := Vector2(0,height_scale/crop.size.y)
	var tr := Transform2D(basis_x,basis_y,Vector2(0,-foot0*height_scale))
	draw_set_transform_matrix(GameMap.ISO_INV*tr)
	draw_texture_rect_region(tex.atlas,Rect2(Vector2.ZERO,crop.size),crop,Color(0.82,0.78,0.67))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func body_overlaps(foot: Vector2) -> bool:
	var area := Rect2(Vector2.ZERO,Vector2.ZERO).expand(end_local)
	area.position.y -= height_scale * 0.45
	area.size.y += height_scale * 0.52
	return area.intersects(Rect2(foot+Vector2(-12,-38),Vector2(24,40)))
