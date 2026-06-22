extends SceneTree
## 校验逐帧动画能被引擎正确加载（不只是文件存在）。
func _init() -> void:
	var keys := ["liang_dao", "guan_dao", "liang_qiang", "guan_qiang", "song_jiang", "lin_chong", "li_kui"]
	for k in keys:
		var p := "res://assets/anim/%s_walk.png" % k
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p)
			var n := int(round(float(t.get_width()) / float(t.get_height())))
			print("OK %s %dx%d frames=%d" % [k, t.get_width(), t.get_height(), n])
		else:
			print("MISSING %s" % k)
	quit()
