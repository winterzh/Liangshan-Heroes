extends SceneTree
## Focused no-art-write runtime contract for the September 5 direction-4 fix.

const REPORT_PATH := "res://qa/skirmish_direction4_fix_20260905/unit_runtime_fix_report.json"

var failures: Array[String] = []
var results: Array[Dictionary] = []
var checks := 0
var _unit_script = null
var _defs_script = null


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks += 1
	results.append({"name": name, "passed": passed, "details": details})
	print("[direction4-fix] ", "PASS " if passed else "FAIL ", name,
		"" if details == null else " :: " + JSON.stringify(details))
	if not passed:
		failures.append(name)


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0001


func _make_unit(key: String):
	var definition: Dictionary = (_defs_script.UNITS[key] as Dictionary).duplicate(true)
	var unit = _unit_script.new()
	unit.setup(key, definition, _unit_script.FACTION_GUAN, null, null)
	root.add_child(unit)
	unit.set_physics_process(false)
	return unit


func _run() -> void:
	_unit_script = load("res://scripts/unit.gd")
	_defs_script = load("res://scripts/defs.gd")
	_check("production scripts instantiate", _unit_script != null and _defs_script != null \
		and _unit_script.can_instantiate() and _defs_script.can_instantiate())
	if not failures.is_empty():
		quit(1)
		return

	for key in ["guan_qi", "guan_jingqi"]:
		var definition: Dictionary = _defs_script.UNITS[key]
		_check(key + " keeps combat range", int(definition.get("range", -1)) == 26,
			{"range": definition.get("range", null)})
		_check(key + " declares spear profile", String(definition.get("weapon_profile", "")) == "spear",
			{"weapon_profile": definition.get("weapon_profile", "")})
		var cavalry = _make_unit(key)
		_check(key + " resolves spear weapon kind", cavalry._weapon_kind() == _unit_script.WK.SPEAR,
			{"actual": cavalry._weapon_kind(), "spear": _unit_script.WK.SPEAR})
		cavalry.queue_free()

	var dying = _make_unit("guan_dao")
	dying._dying = true
	dying._death_t = 0.0
	dying._flash = 0.18
	dying._phys_body(0.10)
	_check("lethal flash decays during death", _near(dying._flash, 0.08),
		{"flash": dying._flash, "death_t": dying._death_t})
	dying._phys_body(0.10)
	_check("lethal flash reaches zero during death", _near(dying._flash, 0.0),
		{"flash": dying._flash, "death_t": dying._death_t})
	dying.queue_free()

	for key in ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]:
		var authored = _make_unit(key)
		authored.animation_direction = "sw"
		authored._lunge = 0.5
		authored._real_frames = true
		authored._frame_directional = true
		_check(key + " authored attack disables whole-sprite swing",
			_near(authored._programmatic_swing_scale(), 0.0),
			{"scale": authored._programmatic_swing_scale()})
		_check(key + " authored attack disables procedural weapon FX",
			not authored._should_draw_programmatic_swing_fx())
		authored._frame_directional = false
		_check(key + " legacy/non-directional frame retains secondary swing",
			_near(authored._programmatic_swing_scale(), 0.25),
			{"scale": authored._programmatic_swing_scale()})
		authored.queue_free()

	var procedural = _make_unit("guan_dao")
	procedural._lunge = 0.5
	procedural._real_frames = false
	procedural._frame_directional = false
	_check("procedural fallback retains full swing", _near(procedural._programmatic_swing_scale(), 1.0),
		{"scale": procedural._programmatic_swing_scale()})
	_check("procedural fallback retains weapon FX", procedural._should_draw_programmatic_swing_fx())
	procedural.queue_free()

	var variant = _make_unit("guan_dao")
	variant._lunge = 0.5
	variant._real_frames = true
	variant._frame_directional = true
	variant.art_variant = "qa_campaign_variant"
	_check("campaign variant remains outside batch suppression",
		_near(variant._programmatic_swing_scale(), 0.25),
		{"scale": variant._programmatic_swing_scale()})
	var offset_image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var offset_frame := ImageTexture.create_from_image(offset_image)
	offset_frame.set_meta("draw_offset_px", Vector2(12.0, -8.0))
	_check("frame offset scales from native 256px texture space",
		variant._frame_draw_offset(offset_frame, 64.0).is_equal_approx(Vector2(3.0, -2.0)),
		{"actual": variant._frame_draw_offset(offset_frame, 64.0)})
	offset_frame.remove_meta("draw_offset_px")
	_check("unknown frame offset defaults to zero",
		variant._frame_draw_offset(offset_frame, 64.0) == Vector2.ZERO)
	offset_frame.set_meta("draw_offset_px", "invalid")
	_check("invalid frame offset type is ignored",
		variant._frame_draw_offset(offset_frame, 64.0) == Vector2.ZERO)
	variant.queue_free()

	var report := {
		"kind": "skirmish_direction4_unit_runtime_fix",
		"status": "PASS" if failures.is_empty() else "FAIL",
		"checks": checks,
		"failures": failures,
		"results": results,
	}
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		failures.append("write QA report")
	else:
		report_file.store_string(JSON.stringify(report, "  ") + "\n")
		report_file.close()
	print("[direction4-fix] RESULT ", "PASS" if failures.is_empty() else "FAIL",
		" checks=", checks, " failures=", failures.size(), " report=", REPORT_PATH)
	quit(0 if failures.is_empty() else 1)
