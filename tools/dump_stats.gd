extends SceneTree
## 导出所有单位的 血量/攻击/防御(/射程) 为 HTML 表 → /tmp/units.html（再由 Chrome 转 PDF）。
## godot --headless --path . --script res://tools/dump_stats.gd

func _type(d: Dictionary) -> String:
	if d.has("res_kind"): return "资源"
	if bool(d.get("building", false)): return "建筑"
	if bool(d.get("worker", false)): return "工人"
	if bool(d.get("hero", false)): return "英雄"
	if bool(d.get("cavalry", false)): return "骑兵"
	if bool(d.get("ranged", false)): return "远程"
	return "步兵"

func _torder(t: String) -> int:
	return ["英雄", "步兵", "远程", "骑兵", "工人", "建筑", "资源"].find(t)

func _init() -> void:
	var rows: Array = []
	for key in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[key]
		rows.append({
			"name": String(d.get("name", key)), "type": _type(d),
			"hp": int(d.get("hp", 0)), "atk": int(d.get("atk", 0)),
			"defense": int(d.get("defense", 0)), "range": int(d.get("range", 0)),
		})
	rows.sort_custom(func(a, b):
		var ta := _torder(a["type"]); var tb := _torder(b["type"])
		if ta != tb: return ta < tb
		return a["hp"] > b["hp"])

	var html := """<!DOCTYPE html><html><head><meta charset="utf-8"><style>
	body{font-family:"PingFang SC","Heiti SC",sans-serif;margin:24px;color:#222}
	h1{font-size:22px;text-align:center;margin:0 0 4px}
	.sub{text-align:center;color:#888;font-size:12px;margin-bottom:14px}
	table{border-collapse:collapse;width:100%;font-size:12px}
	th,td{border:1px solid #ccc;padding:5px 8px;text-align:center}
	th{background:#3a2f1c;color:#ffe9a8}
	td.n{text-align:left;font-weight:bold}
	tr:nth-child(even){background:#f6f3ec}
	.t{background:#efe6d2;font-weight:bold;color:#6b5320}
	</style></head><body>
	<h1>水浒英雄传 · 单位数值表</h1>
	<div class="sub">血量 / 攻击 / 防御 / 射程（防御为新机制，默认 0，每点 +5% 等效血量·仅减普通攻击）</div>
	<table><tr><th>名称</th><th>类型</th><th>血量</th><th>攻击</th><th>防御</th><th>射程</th></tr>"""
	var last_t := ""
	for r in rows:
		if r["type"] != last_t:
			last_t = r["type"]
			html += "<tr class='t'><td colspan='6'>%s</td></tr>" % last_t
		html += "<tr><td class='n'>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%s</td></tr>" % [
			r["name"], r["type"], r["hp"], r["atk"], r["defense"],
			str(r["range"]) if r["range"] > 0 else "—"]
	html += "</table></body></html>"

	var f := FileAccess.open("/tmp/units.html", FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("[dump] wrote /tmp/units.html rows=%d" % rows.size())
	quit()
