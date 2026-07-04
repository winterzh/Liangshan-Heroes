extends SceneTree

const CELL := 64
const GRID := 4
const PROJECTILES := [
	"hammer", "axe", "stone", "dagger",
	"arrow", "spear", "fire_orb", "ice_shard",
	"poison_vial", "thunder_orb", "shadow_orb", "water_drop",
	"rune", "claw", "chain", "banner",
]
const IMPACTS := [
	"ground_crack", "heavy_slam", "fire_burst", "ice_burst",
	"poison_splash", "thunder_hit", "blood_hit", "dust_ring",
	"shadow_burst", "water_splash", "holy_flash", "leaf_snare",
	"armor_crack", "roar", "hex_puff", "speed_wind",
]


func _init() -> void:
	_make_sheet(PROJECTILES, "res://assets/fx_dota_projectiles.png", true)
	_make_sheet(IMPACTS, "res://assets/fx_dota_impacts.png", false)
	print("[generate_dota_fx] wrote %d projectile cells and %d impact cells" % [PROJECTILES.size(), IMPACTS.size()])
	quit()


func _make_sheet(names: Array, path: String, projectile: bool) -> void:
	var img := Image.create(CELL * GRID, CELL * GRID, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(names.size()):
		var ox := int(i % GRID) * CELL
		var oy := int(i / GRID) * CELL
		var name := String(names[i])
		if projectile:
			_draw_projectile(img, name, ox, oy)
		else:
			_draw_impact(img, name, ox, oy)
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("save_png failed: %s err=%d" % [path, err])


func _draw_projectile(img: Image, name: String, ox: int, oy: int) -> void:
	var c := Vector2(ox + 32, oy + 32)
	match name:
		"hammer":
			_line(img, c + Vector2(-17, 14), c + Vector2(13, -16), 5.0, Color("6b4a2c"))
			_rect(img, Rect2(c + Vector2(6, -25), Vector2(20, 14)), Color("8d8a7e"))
			_rect(img, Rect2(c + Vector2(5, -26), Vector2(22, 4)), Color("d9d2b1"))
		"axe":
			_line(img, c + Vector2(-18, 17), c + Vector2(12, -16), 4.0, Color("704b2b"))
			_circle(img, c + Vector2(14, -17), 11.0, Color("d7d7c8"))
			_circle(img, c + Vector2(7, -17), 8.0, Color(0, 0, 0, 0.8), true)
			_line(img, c + Vector2(11, -25), c + Vector2(22, -9), 3.0, Color("ffffff"))
		"stone":
			_circle(img, c, 13.0, Color("8b7f68"))
			_circle(img, c + Vector2(-4, -5), 5.0, Color("c2b899"))
			_line(img, c + Vector2(-7, 5), c + Vector2(8, -3), 1.6, Color("554b3e"))
		"dagger":
			_poly(img, [c + Vector2(-22, 12), c + Vector2(12, -22), c + Vector2(22, -12), c + Vector2(-12, 22)], Color("d9e0e0"))
			_line(img, c + Vector2(-17, 17), c + Vector2(15, -15), 2.0, Color("ffffff"))
			_line(img, c + Vector2(-22, 22), c + Vector2(-9, 9), 5.0, Color("5f3327"))
		"arrow":
			_line(img, c + Vector2(-22, 9), c + Vector2(18, -9), 3.0, Color("d0b36e"))
			_poly(img, [c + Vector2(22, -11), c + Vector2(9, -15), c + Vector2(14, -2)], Color("f6f0cf"))
			_line(img, c + Vector2(-22, 9), c + Vector2(-29, 2), 2.0, Color("88c6e8"))
			_line(img, c + Vector2(-22, 9), c + Vector2(-14, 16), 2.0, Color("88c6e8"))
		"spear":
			_line(img, c + Vector2(-24, 17), c + Vector2(17, -14), 3.5, Color("8a5b33"))
			_poly(img, [c + Vector2(24, -19), c + Vector2(10, -18), c + Vector2(17, -4)], Color("eef4ef"))
			_line(img, c + Vector2(10, -18), c + Vector2(17, -4), 1.3, Color("9fb1b0"))
		"fire_orb":
			_circle(img, c, 14.0, Color("ff5b1a"))
			_circle(img, c + Vector2(-3, -2), 8.0, Color("ffd45a"))
			_poly(img, [c + Vector2(-6, -15), c + Vector2(2, -30), c + Vector2(10, -10)], Color("ff8a1e"))
		"ice_shard":
			_poly(img, [c + Vector2(0, -27), c + Vector2(15, -4), c + Vector2(5, 24), c + Vector2(-13, 7)], Color("8ee9ff"))
			_poly(img, [c + Vector2(0, -23), c + Vector2(6, -2), c + Vector2(-8, 6)], Color("e8fbff"))
		"poison_vial":
			_rect(img, Rect2(c + Vector2(-8, -18), Vector2(16, 28)), Color("4ee64b"))
			_rect(img, Rect2(c + Vector2(-6, -24), Vector2(12, 8)), Color("d6c28a"))
			_circle(img, c + Vector2(0, 1), 9.0, Color("81ff58"))
			_circle(img, c + Vector2(-4, -4), 2.2, Color("ffffff"))
		"thunder_orb":
			_circle(img, c, 14.0, Color("64ccff"))
			_poly(img, [c + Vector2(1, -21), c + Vector2(-7, 1), c + Vector2(3, -1), c + Vector2(-2, 22), c + Vector2(15, -6), c + Vector2(4, -4)], Color("ffffff"))
		"shadow_orb":
			_circle(img, c, 15.0, Color("5b2a9a"))
			_circle(img, c + Vector2(5, -4), 9.0, Color("1c122c"))
			_circle(img, c + Vector2(-5, 6), 4.0, Color("b88cff"))
		"water_drop":
			_poly(img, [c + Vector2(0, -25), c + Vector2(16, 2), c + Vector2(8, 20), c + Vector2(-9, 20), c + Vector2(-16, 2)], Color("39a3ff"))
			_circle(img, c + Vector2(-4, -2), 5.0, Color("c7efff"))
		"rune":
			_poly(img, [c + Vector2(0, -23), c + Vector2(21, 0), c + Vector2(0, 23), c + Vector2(-21, 0)], Color("f4ce54"))
			_line(img, c + Vector2(-9, 0), c + Vector2(9, 0), 2.2, Color("fff6b0"))
			_line(img, c + Vector2(0, -10), c + Vector2(0, 10), 2.2, Color("fff6b0"))
		"claw":
			for k in range(3):
				var x := -9.0 + float(k) * 9.0
				_poly(img, [c + Vector2(x, -22), c + Vector2(x + 5, 13), c + Vector2(x - 4, 20)], Color("f0d2a0"))
			_line(img, c + Vector2(-14, 22), c + Vector2(18, 14), 3.0, Color("9b4a2c"))
		"chain":
			for k in range(4):
				var p := c + Vector2(-18 + k * 12, 8 - k * 6)
				_ring(img, p, 7.0, 2.6, Color("c4b18a"))
		"banner":
			_line(img, c + Vector2(-14, 22), c + Vector2(-14, -22), 3.2, Color("6f4e2d"))
			_poly(img, [c + Vector2(-11, -21), c + Vector2(20, -14), c + Vector2(9, -2), c + Vector2(20, 10), c + Vector2(-11, 6)], Color("e0b138"))


func _draw_impact(img: Image, name: String, ox: int, oy: int) -> void:
	var c := Vector2(ox + 32, oy + 32)
	match name:
		"ground_crack":
			_ring(img, c, 20.0, 2.0, Color("9b825d"))
			_line(img, c + Vector2(-3, -22), c + Vector2(2, -3), 2.2, Color("2f2922"))
			_line(img, c + Vector2(2, -3), c + Vector2(-12, 17), 2.2, Color("2f2922"))
			_line(img, c + Vector2(1, 1), c + Vector2(18, 13), 1.8, Color("2f2922"))
		"heavy_slam":
			_ring(img, c, 22.0, 4.0, Color("cbb886"))
			for i in range(8):
				_ray(img, c, float(i) / 8.0 * TAU, 11.0, 27.0, 2.4, Color("fff2b3"))
		"fire_burst":
			for i in range(10):
				var a := float(i) / 10.0 * TAU
				_poly(img, [c, c + Vector2(cos(a - 0.18), sin(a - 0.18)) * 12, c + Vector2(cos(a), sin(a)) * 28, c + Vector2(cos(a + 0.18), sin(a + 0.18)) * 12], Color("ff7020"))
			_circle(img, c, 10.0, Color("ffd35a"))
		"ice_burst":
			for i in range(8):
				_ray(img, c, float(i) / 8.0 * TAU, 3.0, 27.0, 3.0, Color("a8efff"))
			_circle(img, c, 8.0, Color("e9fbff"))
		"poison_splash":
			_circle(img, c, 13.0, Color("67e840"))
			for p in [Vector2(-18, -8), Vector2(17, -6), Vector2(-11, 18), Vector2(14, 15)]:
				_circle(img, c + p, 5.0, Color("a7ff58"))
		"thunder_hit":
			_poly(img, [c + Vector2(2, -28), c + Vector2(-8, -2), c + Vector2(4, -3), c + Vector2(-1, 28), c + Vector2(15, -5), c + Vector2(4, -4)], Color("ffffff"))
			_ring(img, c, 18.0, 2.0, Color("62cfff"))
		"blood_hit":
			_circle(img, c, 9.0, Color("b11218"))
			for p in [Vector2(-20, -5), Vector2(18, -10), Vector2(-7, 20), Vector2(20, 12), Vector2(-15, 12)]:
				_circle(img, c + p, 4.0, Color("de2628"))
		"dust_ring":
			_ring(img, c, 21.0, 4.0, Color("b59668"))
			_circle(img, c + Vector2(-12, 6), 5.0, Color("d5bd8b"))
			_circle(img, c + Vector2(12, -5), 4.0, Color("d5bd8b"))
		"shadow_burst":
			_circle(img, c, 18.0, Color("3c235f"))
			_ring(img, c, 24.0, 2.2, Color("b282ff"))
			_circle(img, c + Vector2(5, -5), 8.0, Color("171122"))
		"water_splash":
			_circle(img, c, 10.0, Color("58b8ff"))
			for i in range(8):
				_ray(img, c, float(i) / 8.0 * TAU, 8.0, 25.0, 2.6, Color("afeaff"))
		"holy_flash":
			_circle(img, c, 12.0, Color("fff1a4"))
			for i in range(12):
				_ray(img, c, float(i) / 12.0 * TAU, 9.0, 28.0, 2.0, Color("ffd65a"))
		"leaf_snare":
			_ring(img, c, 18.0, 3.0, Color("4fd36d"))
			_line(img, c + Vector2(-23, 15), c + Vector2(22, -11), 3.0, Color("2d8d47"))
			_line(img, c + Vector2(-19, -17), c + Vector2(17, 19), 3.0, Color("2d8d47"))
		"armor_crack":
			_poly(img, [c + Vector2(0, -25), c + Vector2(19, -14), c + Vector2(14, 19), c + Vector2(0, 27), c + Vector2(-14, 19), c + Vector2(-19, -14)], Color("adb7bd"))
			_line(img, c + Vector2(-2, -20), c + Vector2(5, -2), 2.3, Color("2b3136"))
			_line(img, c + Vector2(5, -2), c + Vector2(-4, 18), 2.3, Color("2b3136"))
		"roar":
			for i in range(4):
				_ring(img, c, 8.0 + float(i) * 6.0, 1.8, Color("f3c25a"))
			_poly(img, [c + Vector2(-8, -7), c + Vector2(8, -2), c + Vector2(-8, 7)], Color("fff0a6"))
		"hex_puff":
			_circle(img, c, 17.0, Color("9a68ff"))
			for i in range(6):
				_poly(img, _star(c + Vector2(cos(float(i)) * 18, sin(float(i)) * 14), 4.0), Color("f6ddff"))
		"speed_wind":
			for i in range(5):
				var y := -16.0 + float(i) * 8.0
				_line(img, c + Vector2(-25, y), c + Vector2(22, y - 9.0), 2.4, Color("d7f5ff"))


func _ray(img: Image, c: Vector2, a: float, r0: float, r1: float, w: float, col: Color) -> void:
	_line(img, c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, w, col)


func _line(img: Image, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var n := maxi(1, int(a.distance_to(b) * 1.5))
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / float(n))
		_circle(img, p, width * 0.5, col)


func _rect(img: Image, rect: Rect2, col: Color) -> void:
	for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
		for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
			_put(img, x, y, col)


func _circle(img: Image, c: Vector2, r: float, col: Color, erase := false) -> void:
	var rr := r * r
	for y in range(int(c.y - r - 1.0), int(c.y + r + 2.0)):
		for x in range(int(c.x - r - 1.0), int(c.x + r + 2.0)):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(c) <= rr:
				_put(img, x, y, Color(0, 0, 0, 0) if erase else col, erase)


func _ring(img: Image, c: Vector2, r: float, thick: float, col: Color) -> void:
	var lo := (r - thick) * (r - thick)
	var hi := (r + thick) * (r + thick)
	for y in range(int(c.y - r - thick - 1.0), int(c.y + r + thick + 2.0)):
		for x in range(int(c.x - r - thick - 1.0), int(c.x + r + thick + 2.0)):
			var d := Vector2(x + 0.5, y + 0.5).distance_squared_to(c)
			if d >= lo and d <= hi:
				_put(img, x, y, col)


func _poly(img: Image, pts: Array, col: Color) -> void:
	var minx := 9999.0
	var miny := 9999.0
	var maxx := -9999.0
	var maxy := -9999.0
	for p in pts:
		var v: Vector2 = p
		minx = minf(minx, v.x)
		miny = minf(miny, v.y)
		maxx = maxf(maxx, v.x)
		maxy = maxf(maxy, v.y)
	for y in range(int(miny) - 1, int(maxy) + 2):
		for x in range(int(minx) - 1, int(maxx) + 2):
			if _point_in_poly(Vector2(x + 0.5, y + 0.5), pts):
				_put(img, x, y, col)


func _point_in_poly(p: Vector2, pts: Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in range(pts.size()):
		var pi: Vector2 = pts[i]
		var pj: Vector2 = pts[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / maxf(pj.y - pi.y, 0.0001) + pi.x):
			inside = not inside
		j = i
	return inside


func _star(c: Vector2, r: float) -> Array:
	return [c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]


func _put(img: Image, x: int, y: int, col: Color, replace := false) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if replace:
		img.set_pixel(x, y, col)
		return
	var dst := img.get_pixel(x, y)
	var a := col.a + dst.a * (1.0 - col.a)
	if a <= 0.0:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (col.r * col.a + dst.r * dst.a * (1.0 - col.a)) / a
	var g := (col.g * col.a + dst.g * dst.a * (1.0 - col.a)) / a
	var b := (col.b * col.a + dst.b * dst.a * (1.0 - col.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))
