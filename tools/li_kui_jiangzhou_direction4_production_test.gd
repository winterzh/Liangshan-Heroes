extends SceneTree
## Targeted production contract for the level-2 Jiangzhou bare-torso Li Kui.
## It verifies twenty exact imported files, portrait, variant isolation, and the
## generic Li Kui hash lock. It does not claim mission or human-play acceptance.

const VARIANT := "li_kui_jiangzhou"
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/li_kui_jiangzhou_direction4_production_20260903/runtime_report.json"
const MANIFEST := "res://assets/campaign/li_kui_jiangzhou_direction4_manifest.json"
const EXPECTED_SHA256 := {
	"idle_se": "eeb9bd5a44e125a5e9b3e495cf909682df67ea1ad2c3fab89612779f8c586720",
	"idle_sw": "1eb0be2b3d84bbf171d8201b2a355033b2ef806dc6b6d190c3d0c87aab6d1d67",
	"idle_ne": "a83d51038434b5dd59a5739a7dd206bfc0bb1fdfa268f3ad7480e419abe3dadf",
	"idle_nw": "87f2750bdf91672fbea17dacec58b461267f57e9763d8b8fa77f679691b8ed4b",
	"walk_se": "782d08030baa129deef0b76d146270b852690639a49e899c7190153512490c3e",
	"walk_sw": "fa3511cb2f4b03f46c56e0ea13fa7d371e025d0fd8398ffab2eebb2399ff3f17",
	"walk_ne": "bc2f193fb74f34b02daa0d488ef6205e8ffcb3554de34d71f9b5ab9d12882d07",
	"walk_nw": "b95634ed33c218efd93212f7f220a35a841d11d24afee6b5cc62c78e69b18573",
	"attack_se": "6cef1a6e056c4140b21d31b1b43910a4331ccdf0655b1163eca6c62200a504f4",
	"attack_sw": "de773716b0432c04d6c2b2327a86a6b1e3e5cb3261166c4c1c0069477ddf47df",
	"attack_ne": "975010f6cf5894d7c3ad650d299cce8f81631816570fba5eed510d562804f203",
	"attack_nw": "88aee545b2ba8d9d56af9722a0cb8b2d8bb69da9a8d0276590ce85500a5991d1",
	"hurt_se": "aff34b375e4a1474ed2fb40de050b929cc87656439c96b40a7d6abc06b48c151",
	"hurt_sw": "5b9ea4564f01b960cafc7ce9c0ea0427f6eefde65ff343bde3b36e973505d4eb",
	"hurt_ne": "56104394fc4e8aa938ec0f190522f9108f026ef6e4df528bf3e86f65dd5e799e",
	"hurt_nw": "232473d60b47b76fc7eaddd8f705b5e0cec10f08178bd6ac080334a4a307a1d4",
	"down_se": "503b55976f33cbff91c9132fbc918478243fc03d6a109fbeea0a0a1706aec2db",
	"down_sw": "bacae24078cbbccc7cdcfa436df9891f248fcbe3c2035777c4cc4234dc8b1318",
	"down_ne": "dc4c2a91c7c7e036fccbccd454850c64090c7c00b6cca91d13ba1417bf4a6e63",
	"down_nw": "4a2755b0a196271622ee6efb137ed60364df35e4ed747735ee173ab6f74fe5d2",
}

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[li-kui-jiangzhou] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var manifest_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check("production manifest parses", manifest_data is Dictionary, MANIFEST)
	var protected_generic: Dictionary = manifest_data.get("protected_generic_li_kui_sha256", {}) if manifest_data is Dictionary else {}
	_check("generic Li Kui baseline contains twenty direction files", protected_generic.size() == 20, protected_generic.size())
	for generic_path in protected_generic:
		var actual_generic := FileAccess.get_sha256(ProjectSettings.globalize_path("res://" + String(generic_path)))
		_check("generic hash unchanged " + String(generic_path).get_file(),
			actual_generic == String(protected_generic[generic_path]),
			{"actual": actual_generic, "expected": protected_generic[generic_path]})

	for state in STATES:
		var state_sources: Array[String] = []
		for direction in DIRECTIONS:
			var key: String = String(state) + "_" + String(direction)
			var expected := "res://assets/campaign/anim/%s_%s_%s.png" % [VARIANT, state, direction]
			_check("file exists " + key, FileAccess.file_exists(expected), expected)
			var actual_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(expected))
			_check("file hash " + key, actual_hash == EXPECTED_SHA256[key], {
				"actual": actual_hash, "expected": EXPECTED_SHA256[key]})
			var texture := load(expected) as Texture2D
			_check("imported texture is 256x256 " + key,
				texture != null and texture.get_size() == Vector2(256, 256),
				texture.get_size() if texture != null else Vector2.ZERO)
			_check("exact variant action exists " + key,
				art.campaign_variant_has_animation(VARIANT, state, direction))
			var frames: Array = art.unit_anim_frames("li_kui", state, direction, VARIANT)
			var exact_source := frames.size() == 1 and _source(frames[0]) == expected
			_check("Art resolves one exact frame " + key, exact_source, {
				"frame_count": frames.size(),
				"source": _source(frames[0]) if not frames.is_empty() else "",
			})
			_check("directional source flag " + key,
				art.unit_anim_uses_directional_source("li_kui", state, direction, VARIANT))
			state_sources.append(_source(frames[0]) if not frames.is_empty() else "")
		_check("four sources distinct " + state,
			state_sources.size() == 4 and state_sources.duplicate().all(func(source): return state_sources.count(source) == 1),
			state_sources)

	var portrait_path := "res://assets/campaign/portraits/%s.png" % VARIANT
	var portrait: Texture2D = art.avatar_texture("li_kui", VARIANT)
	_check("variant portrait exists and is hash-locked",
		FileAccess.file_exists(portrait_path)
		and FileAccess.get_sha256(ProjectSettings.globalize_path(portrait_path)) == EXPECTED_SHA256["idle_se"], portrait_path)
	_check("Art selects exact variant portrait", _source(portrait) == portrait_path, _source(portrait))
	_check("invalid direction cannot silently fall back",
		not art.campaign_variant_has_animation(VARIANT, "idle", "wrong"))

	var level2_source := FileAccess.get_file_as_string("res://scripts/levels/level2_jiangzhou.gd")
	var key_gate := level2_source.find('if u.key == "li_kui":')
	var variant_set := level2_source.find('u.art_variant = "li_kui_jiangzhou"')
	_check("level2 assigns dedicated variant under exact Li Kui key gate",
		key_gate >= 0 and variant_set > key_gate and variant_set - key_gate < 160,
		{"key_gate": key_gate, "variant_set": variant_set})
	var other_level_mentions: Array[String] = []
	var levels := DirAccess.open("res://scripts/levels")
	if levels != null:
		levels.list_dir_begin()
		var filename := levels.get_next()
		while not filename.is_empty():
			if filename.ends_with(".gd") and filename != "level2_jiangzhou.gd":
				var path := "res://scripts/levels/" + filename
				if VARIANT in FileAccess.get_file_as_string(path):
					other_level_mentions.append(filename)
			filename = levels.get_next()
		levels.list_dir_end()
	_check("no other campaign level routes the Jiangzhou-only variant", other_level_mentions.is_empty(), other_level_mentions)
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "li_kui_jiangzhou five states x four directions, portrait, exact Art path, level2-only route, and generic Li Kui hash lock",
		"excluded": ["mission progression", "original-text literal nudity", "human playtest", "Steam build or upload"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
