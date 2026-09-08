extends Node2D
## 使用现有手绘木寨墙图集；逻辑边界由Layout负责。
var end_local := Vector2.ZERO
var salt := 0
var height_scale := 78.0 # Height of the upright posts, excluding transparent padding.
var campaign_texture: Texture2D
var campaign_route := ""
var campaign_visible_bbox: Array = []

# The accepted 512px source's two end-post feet. Its baseline falls to the
# right; a bounding-box fit would add that slope to the map's own diagonal.
const CAMPAIGN_LEFT_FOOT := Vector2(185,264)
const CAMPAIGN_RIGHT_FOOT := Vector2(331,342)
const CAMPAIGN_POST_HEIGHT := 98.0

static func panel_count(projected_span: Vector2, post_height: float) -> int:
	# A panel's 78px foot rise represents a 2:1 map run. Match its natural
	# width to the chosen post height instead of squeezing every height into
	# the same three cells. The caller still keeps both original endpoints.
	var width := 2.0*(CAMPAIGN_RIGHT_FOOT.y-CAMPAIGN_LEFT_FOOT.y)*post_height/CAMPAIGN_POST_HEIGHT
	return maxi(1,roundi(absf(projected_span.x)/maxf(width,1.0)))

func source_transform() -> Transform2D:
	var scale := campaign_texture.get_size()/512.0
	var left := CAMPAIGN_LEFT_FOOT*scale
	var right := CAMPAIGN_RIGHT_FOOT*scale
	return _fit_feet(left,right,height_scale/(CAMPAIGN_POST_HEIGHT*scale.y))

func _fit_feet(left: Vector2,right: Vector2,vertical_scale: float) -> Transform2D:
	# Traversing the same world wall in reverse must not change its picture.
	# Match the source's upper foot to the upper world end before fitting.
	if end_local.y*(right.y-left.y)<0.0 or (end_local.y==0.0 and end_local.x<0.0):
		var swap := left
		left=right
		right=swap
	var y_axis := Vector2(0,vertical_scale)
	var x_axis := (end_local-y_axis*(right.y-left.y))/(right.x-left.x)
	return Transform2D(x_axis,y_axis,-x_axis*left.x-y_axis*left.y)

func _draw() -> void:
	if campaign_texture!=null:
		var source_size := campaign_texture.get_size()
		if source_size.x>0.0 and source_size.y>0.0:
			# Retain the entire original bitmap and its alpha. Calibrate the wall
			# feet rather than the image bounds; vertical posts stay vertical.
			var tr := source_transform()
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
	# Legacy fallback is retained only when the accepted source is unavailable.
	var tr := _fit_feet(Vector2(0,foot0*crop.size.y),Vector2(crop.size.x,foot1*crop.size.y),height_scale/crop.size.y)
	draw_set_transform_matrix(GameMap.ISO_INV*tr)
	draw_texture_rect_region(tex.atlas,Rect2(Vector2.ZERO,crop.size),crop,Color(0.82,0.78,0.67))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func body_overlaps(foot: Vector2) -> bool:
	var area := Rect2(Vector2.ZERO,Vector2.ZERO).expand(end_local)
	area.position.y -= height_scale
	area.size.y += height_scale+12
	return area.intersects(Rect2(foot+Vector2(-12,-38),Vector2(24,40)))
