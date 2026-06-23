extends SceneTree
## 一次性清理：去掉喽啰帧带里残留的绿/青色键残（该设计本身无绿色，可放心压绿）。
##   godot --headless --path . --script res://tools/clean_louluo.gd
## 对每个不透明像素：明显偏绿(键残)→透明；轻微偏绿(描边溢色)→把绿分量压回 max(r,b)。

func _init() -> void:
	var files := ["lou_luo_idle", "lou_luo_walk", "lou_luo_attack", "lou_luo_death", "lou_luo_gather"]
	for f in files:
		var path := "res://assets/anim/%s.png" % f
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			print("[clean] SKIP ", path); continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width(); var h := img.get_height()
		var killed := 0; var despilled := 0
		for y in range(h):
			for x in range(w):
				var c := img.get_pixel(x, y)
				if c.a <= 0.02:
					continue
				# 纯青/纯绿键残（r≈0、g/b 抬起）= 绿幕底，灰布/皮肤的 r 绝不为 0 → 安全抠透明
				if c.r < 0.07 and (c.g > 0.18 or c.b > 0.18):
					img.set_pixel(x, y, Color(0, 0, 0, 0)); killed += 1
				# 明显偏绿或偏青(g 占优、r 偏低) = 键色残块（喽啰设计无绿/青，安全）→ 直接抠透明
				elif c.r < 0.5 and c.g > 0.30 and c.g > c.r * 1.25 and c.b < c.g * 1.45:
					img.set_pixel(x, y, Color(0, 0, 0, 0)); killed += 1
				# 轻微偏绿 = 描边溢色 → 压绿
				elif c.g > 0.20 and c.g > c.r * 1.12 and c.g > c.b * 1.12:
					var m: float = maxf(c.r, c.b)
					img.set_pixel(x, y, Color(c.r, m, c.b, c.a)); despilled += 1
				# 轻微偏青 = 绿幕残留(g≈b 同时略高于 r，幅度小)→ 中和到 r 灰（喽啰无青，安全）
				elif c.r < 0.55 and c.g > 0.20 and c.g > c.r * 1.08 and c.b > c.r * 1.04 \
						and (c.g - c.r) < 0.15 and c.b < c.g * 1.5:
					img.set_pixel(x, y, Color(c.r, c.r, c.r, c.a)); despilled += 1
		# 第二趟：删掉「悬浮的极小不透明孤岛」(<16px)——多为图形圈住的键残碎块；
		# 真正的小物件(掉落的镐头等)都远大于此阈值，安全。
		var islands := _kill_small_islands(img, 16)
		img.save_png(ProjectSettings.globalize_path(path))
		print("[clean] %s  killed=%d despilled=%d islands=%d" % [f, killed, despilled, islands])
	print("[clean] done")
	quit()


## 连通域标记不透明像素，抹掉面积 < min_area 的孤岛；返回抹掉的像素总数。
func _kill_small_islands(img: Image, min_area: int) -> int:
	var w := img.get_width(); var h := img.get_height()
	var seen := PackedByteArray(); seen.resize(w * h)
	var removed := 0
	for sy in range(h):
		for sx in range(w):
			var si := sy * w + sx
			if seen[si] == 1 or img.get_pixel(sx, sy).a <= 0.04:
				continue
			# BFS 收集该连通域
			var comp := PackedInt32Array()
			var stack := PackedInt32Array(); stack.append(si); seen[si] = 1
			while stack.size() > 0:
				var i := stack[stack.size() - 1]; stack.resize(stack.size() - 1)
				comp.append(i)
				var x := i % w; var y := i / w
				for nn: int in [i - 1, i + 1, i - w, i + w]:
					if nn < 0 or nn >= w * h: continue
					var nx := nn % w
					if absi(nx - x) > 1: continue
					if seen[nn] == 0 and img.get_pixel(nx, nn / w).a > 0.04:
						seen[nn] = 1; stack.append(nn)
			if comp.size() < min_area:
				for i2 in comp:
					img.set_pixel(i2 % w, i2 / w, Color(0, 0, 0, 0))
					removed += 1
	return removed
