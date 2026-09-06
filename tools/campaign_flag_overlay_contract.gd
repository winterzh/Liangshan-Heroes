extends SceneTree
## 纯代码契约：核对原著旗文白名单、动态/静态落点和 Unit 的真实选择链。
## 不生成、替换或修改任何战役贴图；也不把本测试作为视觉试玩或关卡通关证据。

const CampaignArt := preload("res://scripts/campaign_art.gd")

var _checks: Array = []
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, details := "") -> void:
	_checks.append({"name": name, "passed": passed, "details": details})
	print("[campaign-flag-overlay] ", "PASS " if passed else "FAIL ", name, " ", details)
	if not passed:
		_failures.append(name)


func _spec_text(id: String) -> String:
	return String(CampaignArt.flag_text_spec(id).get("text", ""))


func _stop_test_audio() -> void:
	# 直接 --script 的短夹具不经过正常场景切换；明确释放自动加载的临时播放实例，
	# 免得把音频清理告警误归因于旗号代码。
	for autoload_name in ["Sfx", "Music"]:
		var audio_root = root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_stop_test_audio()
	_check("gao_command_flag_exact", _spec_text("gao_flagship_command") == "帅")
	_check("liangshan_hilltop_flag_exact", _spec_text("liangshan_hilltop_standard") == "替天行道")
	_check("zhongyi_west_flag_exact", _spec_text("zhongyi_hall_standard_west") == "山东呼保义")
	_check("zhongyi_east_flag_exact", _spec_text("zhongyi_hall_standard_east") == "河北玉麒麟")
	_check("zhujiazhuang_chao_flag_exact", _spec_text("zhujiazhuang_gate_chao_standard") == "填平水泊擒晁盖"
		and String(CampaignArt.flag_text_spec("zhujiazhuang_gate_chao_standard").get("chapter", "")) == "第四十八回")
	_check("zhujiazhuang_song_flag_exact", _spec_text("zhujiazhuang_gate_song_standard") == "踏破梁山捉宋江"
		and String(CampaignArt.flag_text_spec("zhujiazhuang_gate_song_standard").get("chapter", "")) == "第四十八回")
	_check("vanguard_pair_kept_unsplit",
		_spec_text("official_vanguard_red_pair") == "搅海翻江冲巨浪，安邦定国灭洪妖"
			and String(CampaignArt.flag_text_spec("official_vanguard_red_pair").get("layout", "")) == "paired_only"
			and CampaignArt.flag_text_spec("official_vanguard_red_pair").get("leaders", []) == ["丘岳", "徐京", "梅展"]
			and CampaignArt.flag_text_spec("official_vanguard_red_pair").get("states", []) == ["default", "damaged", "flooding", "disabled"])
	var gao_spec := CampaignArt.flag_text_spec("gao_flagship_command")
	_check("gao_command_is_text_only_on_web_blank_cloth", bool(gao_spec.get("text_only", false))
		and not gao_spec.has("unlettered_masks"))
	var gao_route := CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "chapter80_gao_flagship")
	var vanguard_route := CampaignArt.dynamic_flag_route("official_vanguard", "official_vanguard", "chapter80_vanguard_headship")
	_check("gao_route_requires_exact_unit_object_and_chapter80_context", String(gao_route.get("overlay_id", "")) == "gao_flagship_command"
		and CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "").is_empty()
		and CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "third_battle").is_empty()
		and CampaignArt.dynamic_flag_route("qa_gao_flagship", "gao_flagship", "chapter80_gao_flagship").is_empty()
		and CampaignArt.dynamic_flag_route("gao_flagship", "official_warship", "chapter80_gao_flagship").is_empty())
	_check("vanguard_route_requires_chapter80_headship_context", String(vanguard_route.get("overlay_id", "")) == "official_vanguard_red_pair"
		and CampaignArt.dynamic_flag_route("official_vanguard", "official_vanguard", "").is_empty()
		and CampaignArt.dynamic_flag_route("official_vanguard", "official_vanguard", "third_battle").is_empty()
		and CampaignArt.dynamic_flag_route("imperial_warship", "official_warship", "chapter80_vanguard_headship").is_empty())
	var vanguard_pair_rects: Dictionary = CampaignArt.flag_text_spec("official_vanguard_red_pair").get("dynamic_pair_rects", {})
	var vanguard_rects_complete := true
	for state in ["default", "damaged", "flooding", "disabled"]:
		var by_direction: Dictionary = vanguard_pair_rects.get(state, {})
		for direction in CampaignArt.DIRECTIONS:
			var pair = by_direction.get(direction, [])
			vanguard_rects_complete = vanguard_rects_complete and pair is Array and pair.size() == 2 \
				and pair.all(func(rect): return rect is Array and rect.size() == 4)
	_check("vanguard_has_own_state_specific_pair_flag_rects", vanguard_rects_complete)
	_check("vanguard_uses_own_directional_art_paths", CampaignArt.object_direction_path("official_vanguard", "default", "se")
		!= CampaignArt.object_direction_path("official_warship", "default", "se")
		and CampaignArt.object_direction_path("official_vanguard", "disabled", "nw").ends_with("official_vanguard_disabled_nw.png"))
	_check("generic_banner_has_no_text_mapping", CampaignArt.static_flag_overlay_id("banner").is_empty())
	_check("static_marker_whitelist", CampaignArt.static_flag_overlay_id("liangshan_hilltop_standard") == "liangshan_hilltop_standard"
		and CampaignArt.static_flag_overlay_id("zhongyi_hall_standard_west") == "zhongyi_hall_standard_west"
		and CampaignArt.static_flag_overlay_id("zhongyi_hall_standard_east") == "zhongyi_hall_standard_east"
		and CampaignArt.static_flag_overlay_id("zhujiazhuang_gate_chao_standard") == "zhujiazhuang_gate_chao_standard"
		and CampaignArt.static_flag_overlay_id("zhujiazhuang_gate_song_standard") == "zhujiazhuang_gate_song_standard")
	_check("static_marker_requires_level_and_banner_scope",
		String(CampaignArt.static_flag_route("liangshan_hilltop_standard", "level5", "banner").get("overlay_id", "")) == "liangshan_hilltop_standard"
		and CampaignArt.static_flag_route("liangshan_hilltop_standard", "level1", "banner").is_empty()
		and CampaignArt.static_flag_route("liangshan_hilltop_standard", "level5", "tower").is_empty())
	_check("zhujiazhuang_pair_requires_level3_banner_scope",
		String(CampaignArt.static_flag_route("zhujiazhuang_gate_chao_standard", "level3", "banner").get("overlay_id", "")) == "zhujiazhuang_gate_chao_standard"
		and String(CampaignArt.static_flag_route("zhujiazhuang_gate_song_standard", "level3", "banner").get("overlay_id", "")) == "zhujiazhuang_gate_song_standard"
		and CampaignArt.static_flag_route("zhujiazhuang_gate_chao_standard", "level5", "banner").is_empty()
		and CampaignArt.static_flag_route("zhujiazhuang_gate_song_standard", "level3", "tower").is_empty())
	for forbidden in ["梁山好汉", "梁山军", "宋军", "刘梦龙水军"]:
		_check("forbidden_text_not_a_flag_" + forbidden, CampaignArt.flag_text_spec(forbidden).is_empty())
	# Unit 和 overlay 都引用项目自动加载。像其他项目内脚本夹具一样延迟加载，
	# 避免 --script 在自动加载注册前预编译它们。
	var overlay_script = load("res://scripts/campaign_flag_overlay.gd")
	var unit_script = load("res://scripts/unit.gd")
	_check("runtime_scripts_load_after_autoload", overlay_script != null and unit_script != null)
	if overlay_script != null:
		var overlay = overlay_script.new()
		_check("static_component_accepts_only_known_marker", overlay.configure_static_marker("liangshan_hilltop_standard", 72.0, 0.8, "level5", "banner")
			and overlay.overlay_id() == "liangshan_hilltop_standard"
			and not overlay.configure_static_marker("liangshan_hilltop_standard", 72.0, 0.8, "level1", "banner")
			and not overlay.configure_static_marker("banner", 72.0, 0.8, "level5", "banner")
			and overlay.overlay_id().is_empty())
		_check("zhujiazhuang_static_component_is_level3_only",
			overlay.configure_static_marker("zhujiazhuang_gate_chao_standard", 144.0, 0.8, "level3", "banner")
			and overlay.overlay_id() == "zhujiazhuang_gate_chao_standard"
			and not overlay.configure_static_marker("zhujiazhuang_gate_chao_standard", 144.0, 0.8, "level5", "banner")
			and overlay.overlay_id().is_empty())
		overlay.free()
	if unit_script != null:
		var gao = unit_script.new()
		gao.setup("gao_flagship", {"name":"夹具高俅座船", "hp":100, "atk":0, "speed":50,
			"radius":25, "movement_profile":"water", "campaign_object":"gao_flagship"}, 1, null, null)
		var impostor = unit_script.new()
		impostor.setup("qa_gao_flagship", {"name":"冒用高俅物件", "hp":100, "atk":0, "speed":50,
			"radius":25, "movement_profile":"water", "campaign_object":"gao_flagship"}, 1, null, null)
		var official = unit_script.new()
		official.setup("qa_official_warship", {"name":"夹具官船", "hp":100, "atk":0, "speed":50,
			"radius":25, "movement_profile":"water", "campaign_object":"official_warship"}, 1, null, null)
		var vanguard = unit_script.new()
		vanguard.setup("official_vanguard", {"name":"第八十回先锋头船", "hp":100, "atk":0, "speed":50,
			"radius":25, "movement_profile":"water", "campaign_object":"official_vanguard"}, 1, null, null)
		_check("real_units_need_authorized_context_before_selecting_routes", gao._campaign_flag_object_key().is_empty()
			and impostor._campaign_flag_object_key().is_empty()
			and official._campaign_flag_object_key().is_empty()
			and vanguard._campaign_flag_object_key().is_empty())
		gao.set_meta("campaign_flag_context", "chapter80_gao_flagship")
		_check("real_gao_flagship_needs_context_then_selects_command_flag", gao._campaign_flag_object_key() == "gao_flagship")
		vanguard.set_meta("campaign_flag_context", "chapter80_vanguard_headship")
		_check("real_vanguard_unit_needs_context_then_selects_pair", vanguard._campaign_flag_object_key() == "official_vanguard")
		vanguard.set_meta("ship_state", "disabled")
		_check("real_vanguard_disabled_state_keeps_pair_flag", vanguard._campaign_flag_object_key() == "official_vanguard")
		gao.free()
		impostor.free()
		official.free()
		vanguard.free()
	var art = root.get_node_or_null("Art")
	_check("art_exact_directional_contract_available", art != null and art.has_method("campaign_object_has_exact_directional_source"))
	if art != null and art.has_method("campaign_object_has_exact_directional_source"):
		var vanguard_exact := true
		for state in ["default", "damaged", "flooding", "disabled"]:
			for direction in CampaignArt.DIRECTIONS:
				vanguard_exact = vanguard_exact and bool(art.call("campaign_object_has_exact_directional_source", "official_vanguard", state, direction))
		_check("gao_and_vanguard_use_true_directional_sources", bool(art.call("campaign_object_has_exact_directional_source", "gao_flagship", "default", "se"))
			and vanguard_exact)
	var report_path := OS.get_environment("CAMPAIGN_FLAG_OVERLAY_REPORT")
	if report_path.is_empty():
		report_path = "res://qa/direction4_20260901/campaign_flag_overlay_contract.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var out := FileAccess.open(report_path, FileAccess.WRITE)
	if out != null:
		# 先落一个最小文件再核验路径；完整报告在 report_written 也入 checks 后写入。
		out.store_string("{}\n")
		out.close()
	_check("report_written", FileAccess.file_exists(report_path), report_path)
	if FileAccess.file_exists(report_path):
		var final_out := FileAccess.open(report_path, FileAccess.WRITE)
		if final_out != null:
			final_out.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks}, "\t") + "\n")
			final_out.close()
	print("[campaign-flag-overlay-result] ", JSON.stringify({"passed": _failures.is_empty(), "checks": _checks.size(), "failures": _failures}))
	_stop_test_audio()
	for frame in range(3):
		await process_frame
	quit(0 if _failures.is_empty() else 5)
