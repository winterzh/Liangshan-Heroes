extends SceneTree
## 一次性检查：列出所有单位 key 在 HUD 选区图标里能不能拿到「头像/立绘」。
##   godot --headless --path . --script res://tools/audit_portraits.gd
## CIRCLE = 既无 portrait 也无 unit 贴图 → 选区图标画黄圈（用户要消灭的）。
func _init() -> void:
	var art = load("res://scripts/art_db.gd").new()
	get_root().add_child(art)
	await process_frame
	var defs = load("res://scripts/defs.gd")
	var keys = defs.UNITS.keys()
	keys.sort()
	var circle := []
	var sprite_only := []
	for k in keys:
		var d = defs.UNITS[k]
		# 资源点/旗标之类不进选区图标，跳过
		if bool(d.get("is_resource", false)):
			continue
		var a = art.avatar_texture(k)        # HUD 选区图标实际取图链
		var p = art.portrait_texture(k)
		if a == null:
			circle.append(k)                 # 仍画黄圈/首字者
		elif p == null:
			sprite_only.append(k)            # 有图但非专属头像
	print("=== CIRCLE (无脸·无图 → 黄圈) %d ===" % circle.size())
	for k in circle:
		print("  %-18s name=%s building=%s" % [k, defs.UNITS[k].get("name", "?"), defs.UNITS[k].get("is_building", false)])
	print("=== sprite-only (有走图·无头像) %d ===" % sprite_only.size())
	for k in sprite_only:
		print("  %-18s" % k)
	print("=== total unit keys (non-resource) checked ===")
	quit()
