extends SceneTree

const KEYS := ["chao_gai", "lu_zhishen", "wu_song", "gongsun_sheng"]
const EXPECTED := {
	"chao_gai": "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png",
	"lu_zhishen": "res://assets/characters/art_full_20260916/lu_zhishen_portrait_20260916.png",
	"wu_song": "res://assets/characters/art_full_20260916/wu_song_portrait_20260916.png",
	"gongsun_sheng": "res://assets/characters/art_full_20260916/gongsun_sheng_portrait_20260916.png",
}

func _init() -> void:
	var art = load("res://scripts/art_db.gd").new()
	var passed := 0
	var total := 0
	for key in KEYS:
		total += 1
		var texture: Texture2D = art.portrait_texture(key)
		if texture != null:
			passed += 1
			print("[liangshan-core-portraits] %s texture OK" % key)
		total += 1
		if texture != null and texture.get_size() == Vector2(1254, 1254):
			passed += 1
		else:
			print("[liangshan-core-portraits] %s size FAIL" % key)
		total += 1
		var expected: Texture2D = load(EXPECTED[key])
		if texture == expected:
			passed += 1
		else:
			print("[liangshan-core-portraits] %s route FAIL" % key)
	# A missing key must still use the normal fallback chain without crashing.
	total += 1
	if art.portrait_texture("__missing_portrait_contract__") == null:
		passed += 1
	else:
		print("[liangshan-core-portraits] missing key FAIL")
	print("[liangshan-core-portraits] %d/%d PASS" % [passed, total])
	quit(0 if passed == total else 1)
