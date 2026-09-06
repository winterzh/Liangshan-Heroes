extends RefCounted
## 第5关渲染高度场。寻路/射程/伤害仍使用原二维坐标。
## CPU投影和GPU地面共用格点高度，避免人、地面与点击采用不同高度。
const MAX_HEIGHT := 96.0
const CELL := 32.0
var width := 0
var height := 0
var samples := PackedFloat32Array()
var texture: ImageTexture

func build(w: int, h: int, terrain: PackedInt32Array) -> void:
	width = w + 1
	height = h + 1
	samples.resize(width * height)
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in range(height):
		for x in range(width):
			var value := _profile(Vector2(x, y))
			# 水格的四角必须同在零水位，禁止山脚插值把港面抬成斜坡。
			for dy in [-1,0]:
				for dx in [-1,0]:
					var cx: int = x+dx
					var cy: int = y+dy
					if cx>=0 and cx<w and cy>=0 and cy<h and terrain[cy*w+cx]==0:
						value = 0.0
			samples[y * width + x] = value
			img.set_pixel(x, y, Color(value / MAX_HEIGHT, 0, 0, 1))
	texture = ImageTexture.create_from_image(img)

func _profile(p: Vector2) -> float:
	# 寨院位于一整片平地，厅堂仅使用建筑贴图自带的台基。
	# 高差在寨墙以外消化，南侧进寨路为缓坡，不在厅前堆小山。
	var east_west := smoothstep(6.0, 10.0, p.x) * (1.0 - smoothstep(23.0, 27.0, p.x))
	var north_south := smoothstep(22.0, 27.0, p.y) * (1.0 - smoothstep(41.0, 46.0, p.y))
	var courtyard := 18.0 * east_west * north_south
	# 后山用宽缓的连续山脊，绝不抬高院内；与水面相接处提前收至零。
	var north := 92.0 * _hill(p,Vector2(14,13),Vector2(17,14))
	var west := 70.0 * _hill(p,Vector2(3,27),Vector2(7,17))
	var edge_fade := smoothstep(0.0,6.0,p.x) * smoothstep(0.0,6.0,p.y)
	return maxf(courtyard,maxf(north,west)*edge_fade)

func _hill(p: Vector2, center: Vector2, radius: Vector2) -> float:
	var distance := ((p-center)/radius).length()
	return 1.0-smoothstep(0.0,1.0,distance)

func at(p: Vector2) -> float:
	var c := p / CELL
	if c.x < 0.0 or c.x >= width-1 or c.y < 0.0 or c.y >= height-1:
		return 0.0
	var x := int(floor(c.x))
	var y := int(floor(c.y))
	var f := c - Vector2(x, y)
	var i := y * width + x
	return lerpf(lerpf(samples[i], samples[i + 1], f.x),
		lerpf(samples[i + width], samples[i + width + 1], f.x), f.y)
