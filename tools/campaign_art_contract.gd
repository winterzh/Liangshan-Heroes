extends SceneTree
## 资源格式和造型隔离契约；不启动战斗、不读写玩家存档。
const CA := preload("res://scripts/campaign_art.gd")
var checks: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _check(name: String, passed: bool, details: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"details":details})

func _alpha_check(image: Image) -> Dictionary:
	var empty := 0
	var solid := 0
	var bottom := -1
	var edge := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var a := image.get_pixel(x,y).a
			if a == 0.0: empty += 1
			if a > 0.39:
				solid += 1
				bottom = maxi(bottom,y)
				if x==0 or y==0 or x==image.get_width()-1 or y==image.get_height()-1: edge=true
	return {"alpha_zero":empty,"visible":solid,"bottom":bottom,"edge_cut":edge,"passed":empty>solid/4 and solid>20 and not edge}

func _frame_source(frame: Texture2D) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""

func _run() -> void:
	var art := root.get_node("Art")
	var old_frames: Array = art.unit_anim_frames("wu_song","walk")
	var old_texture: Texture2D = art.avatar_texture("wu_song")
	_check("legacy_signature",not old_frames.is_empty() and old_texture!=null)
	# down is the non-lethal story terminal; death is the fatal terminal. A
	# campaign variant without death art must retain the legacy/programmatic
	# death path instead of silently borrowing its down or idle pose.
	for direction in CA.DIRECTIONS:
		var down_path := CA.animation_path("wu_song_mengzhou", "down", direction)
		var death_path := CA.animation_path("wu_song_mengzhou", "death", direction)
		var down_frames: Array = art.unit_anim_frames("wu_song", "down", direction, "wu_song_mengzhou")
		var death_frames: Array = art.unit_anim_frames("wu_song", "death", direction, "wu_song_mengzhou")
		_check("campaign_terminal_paths_are_distinct_" + direction,
			down_path.ends_with("_down_%s.png" % direction)
			and death_path.ends_with("_death_%s.png" % direction)
			and down_path != death_path)
		_check("campaign_down_reads_exact_down_" + direction,
			not down_frames.is_empty() and _frame_source(down_frames[0]) == down_path
			and art.unit_anim_uses_directional_source("wu_song", "down", direction, "wu_song_mengzhou"))
		_check("missing_campaign_death_uses_legacy_death_" + direction,
			not art.campaign_variant_has_animation("wu_song_mengzhou", "death", direction)
			and not death_frames.is_empty()
			and _frame_source(death_frames[0]) == "res://assets/anim/wu_song_death.png"
			and not art.unit_anim_uses_directional_source("wu_song", "death", direction, "wu_song_mengzhou"),
			{"actual":_frame_source(death_frames[0]) if not death_frames.is_empty() else ""})
		var lu_down_path := CA.animation_path("lu_zhishen_rescue", "down", direction)
		var lu_down: Array = art.unit_anim_frames("lu_zhishen", "down", direction, "lu_zhishen_rescue")
		_check("lu_zhishen_campaign_down_reads_exact_down_" + direction,
			art.campaign_variant_has_animation("lu_zhishen_rescue", "down", direction)
			and lu_down.size() == 1 and _frame_source(lu_down[0]) == lu_down_path
			and lu_down_path.ends_with("_down_%s.png" % direction)
			and art.unit_anim_uses_directional_source("lu_zhishen", "down", direction, "lu_zhishen_rescue"))
		var lu_attack_path := CA.animation_path("lu_zhishen_rescue", "attack", direction)
		var lu_intercept: Array = art.unit_anim_frames("lu_zhishen", "intercept", direction, "lu_zhishen_rescue")
		_check("lu_zhishen_intercept_explicitly_uses_corrected_attack_" + direction,
			CA.animation_path("lu_zhishen_rescue", "intercept", direction) == lu_attack_path
			and art.campaign_variant_has_animation("lu_zhishen_rescue", "intercept", direction)
			and lu_intercept.size() == 1 and _frame_source(lu_intercept[0]) == lu_attack_path
			and art.unit_anim_uses_directional_source("lu_zhishen", "intercept", direction, "lu_zhishen_rescue"))
		# 快活林蒋忠的 hurt/down 都是原著中仍存活的剧情状态。五种状态
		# 必须逐方向读取本批独立 PNG；普通死亡继续回退通用死亡素材，
		# 不能把倒地告饶图当作尸体。
		for menshen_state in ["idle", "walk", "attack", "hurt", "down"]:
			var menshen_path := CA.animation_path("jiang_menshen_fists", menshen_state, direction)
			var menshen_series: Array = art.unit_anim_frames("jiang_menshen", menshen_state, direction, "jiang_menshen_fists")
			var menshen_ok: bool = menshen_series.size() == 1 \
				and _frame_source(menshen_series[0]) == menshen_path \
				and art.unit_anim_uses_directional_source("jiang_menshen", menshen_state, direction, "jiang_menshen_fists")
			if not menshen_series.is_empty():
				var menshen_image: Image = menshen_series[0].get_image()
				var menshen_alpha := _alpha_check(menshen_image)
				menshen_ok = menshen_ok and menshen_image.get_size() == Vector2i(256, 256) \
					and menshen_alpha.passed and absi(int(menshen_alpha.bottom) - 210) <= 3
			_check("jiang_menshen_" + menshen_state + "_" + direction, menshen_ok)
		var menshen_death: Array = art.unit_anim_frames("jiang_menshen", "death", direction, "jiang_menshen_fists")
		_check("jiang_menshen_down_stays_separate_from_death_" + direction,
			CA.animation_path("jiang_menshen_fists", "down", direction) != CA.animation_path("jiang_menshen_fists", "death", direction)
			and not art.campaign_variant_has_animation("jiang_menshen_fists", "death", direction)
			and not menshen_death.is_empty()
			and _frame_source(menshen_death[0]) == "res://assets/anim/jiang_menshen_death.png"
			and not art.unit_anim_uses_directional_source("jiang_menshen", "death", direction, "jiang_menshen_fists"))
		var procedural_death: Array = art.unit_anim_frames("dong_chao", "death", direction, "dong_chao_escort")
		_check("missing_campaign_and_legacy_death_stays_empty_for_programmatic_fallback_" + direction,
			not art.campaign_variant_has_animation("dong_chao_escort", "death", direction)
			and procedural_death.is_empty()
			and not art.unit_anim_uses_directional_source("dong_chao", "death", direction, "dong_chao_escort"))
	var hashes: Array = []
	for direction in CA.DIRECTIONS:
		var frames: Array = art.unit_anim_frames("wu_song","walk",direction,"wu_song_mengzhou")
		# 新孟州批次是一张具名动作姿态对应一个真实朝向，不把单帧姿态
		# 虚报成四帧循环；四向差异由四张独立 PNG 提供。
		_check("wu_song_walk_"+direction,frames.size()==1
			and _frame_source(frames[0]) == CA.animation_path("wu_song_mengzhou", "walk", direction)
			and art.unit_anim_uses_directional_source("wu_song", "walk", direction, "wu_song_mengzhou"))
		if not frames.is_empty(): hashes.append(hash(frames[0].get_image().get_data()))
		for state in ["idle","walk","attack","hurt","down"]:
			var series: Array = art.unit_anim_frames("wu_song",state,direction,"wu_song_mengzhou")
			var okay: bool = series.size()==1 \
				and _frame_source(series[0]) == CA.animation_path("wu_song_mengzhou", state, direction) \
				and art.unit_anim_uses_directional_source("wu_song", state, direction, "wu_song_mengzhou")
			for frame in series:
				var im: Image = frame.get_image()
				var alpha := _alpha_check(im)
				okay = okay and im.get_size()==Vector2i(256,256) and alpha.passed and absi(int(alpha.bottom)-210)<=3
			_check("wu_song_"+state+"_"+direction,okay)
	var unique: Dictionary = {}
	for h in hashes: unique[h]=true
	_check("four_direction_distinct_images",unique.size()==4)
	_check("legacy_cache_not_polluted",art.unit_anim_frames("wu_song","walk")==old_frames and art.avatar_texture("wu_song")==old_texture)
	_check("period_avatar_not_old_portrait",art.avatar_texture("wu_song","wu_song_mengzhou")!=old_texture)
	for variant in CA.ANIMATED_VARIANTS:
		var okay := art.avatar_texture("wu_song",variant)!=null
		for direction in CA.DIRECTIONS:
			okay = okay and art.campaign_variant_has_direction(variant,direction)
			var frames: Array = art.unit_anim_frames("wu_song","idle",direction,variant)
			okay = okay and not frames.is_empty()
			if not frames.is_empty(): okay = okay and _alpha_check(frames[0].get_image()).passed
		_check("variant_ready_"+variant,okay)
	# 黄泥冈押送角色使用剧情状态而不是死亡替身：每个方向都有独立站姿和非致死倒地帧。
	for role in ["yu_hou", "lao_duguan"]:
		for state in ["idle", "down"]:
			var role_hashes: Dictionary = {}
			var role_okay := true
			for direction in CA.DIRECTIONS:
				var role_frames: Array = art.unit_anim_frames(role, state, direction)
				role_okay = role_okay and role_frames.size() == 1 and art.unit_anim_uses_directional_source(role, state, direction)
				if not role_frames.is_empty():
					var role_alpha := _alpha_check(role_frames[0].get_image())
					role_okay = role_okay and role_alpha.passed and role_frames[0].get_image().get_size() == Vector2i(256, 256)
					role_hashes[hash(role_frames[0].get_image().get_data())] = true
			role_okay = role_okay and role_hashes.size() == CA.DIRECTIONS.size()
			_check("huangnigang_" + role + "_" + state + "_four_direction_story_state", role_okay)
	for object_key in CA.OBJECT_ALIASES:
		var tex: Texture2D = art.campaign_object_texture(object_key)
		_check("object_"+object_key,tex!=null and _alpha_check(tex.get_image()).passed if tex!=null else false)
	_check("official_vanguard_legacy_call_uses_own_se_source",
		art.campaign_object_texture("official_vanguard") == art.campaign_object_texture("official_vanguard", "default", "se")
		and art.campaign_object_has_exact_directional_source("official_vanguard", "default", "se"))
	# 江州刑台明确复用通用刑台格；不能把不存在的战役专图登记成已完成物件。
	var scaffold_texture: Texture2D = art.terrain_texture("scaffold")
	_check("jiangzhou_scaffold_explicit_generic_alias",
		CA.generic_object_alias("jiangzhou_scaffold") == "scaffold"
		and CA.object_path("jiangzhou_scaffold").is_empty()
		and scaffold_texture != null
		and art.unit_texture("scaffold", "jiangzhou_scaffold", "se") == scaffold_texture
		and art.avatar_texture("scaffold", "jiangzhou_scaffold") == scaffold_texture
		and art.unit_texture("hall", "jiangzhou_scaffold", "se") == null)
	# 六名祝家庄囚犯复用“本人造型 + 程序绳索”，variant 与本人 key 强绑定。
	var expected_bound := {
		"bound_shi_qian": "shi_qian", "bound_qin_ming": "qin_ming",
		"bound_yang_lin": "yang_lin", "bound_huang_xin": "huang_xin",
		"bound_wang_ying": "wang_ying", "bound_deng_fei": "deng_fei",
	}
	_check("zhujiazhuang_programmatic_bound_registry_exact", CA.PROGRAMMATIC_BOUND_VARIANTS == expected_bound)
	for bound_variant in expected_bound:
		var owner: String = expected_bound[bound_variant]
		var own_texture: Texture2D = art.unit_texture(owner, bound_variant, "se")
		_check("zhujiazhuang_%s_keeps_owner_identity" % bound_variant,
			CA.programmatic_bound_owner(bound_variant) == owner
			and not bound_variant in CA.ANIMATED_VARIANTS
			and own_texture != null
			and own_texture == art.unit_texture(owner, "", "se")
			and art.avatar_texture(owner, bound_variant) == art.avatar_texture(owner))
		var wrong_owner := "qin_ming" if owner != "qin_ming" else "shi_qian"
		_check("zhujiazhuang_%s_rejects_wrong_owner" % bound_variant,
			art.unit_texture(wrong_owner, bound_variant, "se") == null
			and art.avatar_texture(wrong_owner, bound_variant) == null
			and art.unit_anim_frames(wrong_owner, "idle", "se", bound_variant).is_empty())
	for state in ["default","damaged","flooding","disabled"]:
		_check("ship_"+state,art.campaign_object_texture("official_warship",state)!=null)
	_check("gate_open_differs",art.campaign_object_texture("prison_gate","open")!=art.campaign_object_texture("prison_gate"))
	_check("fire_signal_differs",art.campaign_object_texture("cuiyun_tower","signal")!=art.campaign_object_texture("cuiyun_tower"))
	var okay: bool = checks.all(func(c):return c.passed)
	var report_path := OS.get_environment("CAMPAIGN_ART_REPORT")
	if report_path.is_empty(): report_path = "res://assets/campaign/contract_qa.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var out := FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed":okay,"checks":checks},"\t"))
	for c in checks:
		if not c.passed: print("[campaign_art_failure] ",JSON.stringify(c))
	print("[campaign_art_contract] checks=%d passed=%s"%[checks.size(),okay])
	quit(0 if okay else 5)
