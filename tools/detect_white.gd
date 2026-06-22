extends SceneTree
## 扫 assets/anim/*_walk.png：检测每帧底部是否有「白色一坨」（不透明、高亮度、低饱和=白/灰底残留）。
## godot --headless --path . --script res://tools/detect_white.gd

func _init() -> void:
	var dir := DirAccess.open("res://assets/anim")
	var flagged: Array = []
	for f in dir.get_files():
		if not f.ends_with("_walk.png"):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/anim/" + f))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var h := img.get_height()
		var fw := h
		var nf := int(img.get_width() / fw)
		var worst := 0
		for fi in range(nf):
			var cnt := 0
			for y in range(int(h * 0.88), h):    # 最底部 12%
				for x in range(fi * fw + int(fw * 0.18), fi * fw + int(fw * 0.82)):
					var c := img.get_pixel(x, y)
					if c.a <= 0.35:
						continue
					var mx: float = maxf(maxf(c.r, c.g), c.b)
					var mn: float = minf(minf(c.r, c.g), c.b)
					var sat := (mx - mn) / maxf(mx, 0.001)
					var pale := c.get_luminance() > 0.55 and sat < 0.30      # 灰白晕
					var green := c.g > c.r + 0.05 and c.g > c.b + 0.05       # 绿幕残留
					if pale or green:
						cnt += 1
			worst = maxi(worst, cnt)
		var key := f.replace("_walk.png", "")
		print("  %-18s bottom_white=%d %s" % [key, worst, "  <== FLAG" if worst > 25 else ""])
		if worst > 25:
			flagged.append(key)
	print("[detect] flagged=%d : %s" % [flagged.size(), ", ".join(flagged)])
	quit()
