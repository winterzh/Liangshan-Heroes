extends SceneTree
## 格式、真实多帧资源和精确动作查询合约；不把哈希不同当作动画质量验收。
const CA := preload("res://scripts/campaign_art.gd")
var checks: Array=[]
var profiles: Dictionary={}
func _initialize() -> void: _run.call_deferred()
func _check(name: String, passed: bool) -> void:
	checks.append({"name":name,"passed":passed})
	if not passed: print("[motion-art-fail] ",name)
func _profile(im: Image) -> Dictionary:
	im.convert(Image.FORMAT_RGBA8)
	var bytes := im.get_data()
	var zero := 0
	var top := 256
	var bottom := -1
	var edge := false
	var lower := PackedByteArray()
	for y in range(256):
		for x in range(256):
			var a := bytes[(y*256+x)*4+3]
			if a==0: zero+=1
			if a>100:
				top=mini(top,y); bottom=maxi(bottom,y)
				edge=edge or x==0 or x==255 or y==0 or y==255
			if y>=130: lower.append(1 if a>100 else 0)
	return {"size":str(im.get_size()),"alpha_zero":zero,"top":top,"bottom":bottom,"height":bottom-top+1,
		"edge_cut":edge,"pixels":bytes.hex_encode().sha256_text(),"lower_mask":lower.hex_encode().sha256_text()}
func _run() -> void:
	var art=root.get_node("Art")
	var old_song: Array=art.unit_anim_frames("song_jiang","walk")
	var old_dai=art.avatar_texture("dai_zong")
	for spec in [["lin_chong","lin_chong_escort","walk"],["lin_chong","lin_chong_escort","assisted"],
		["song_jiang","song_jiang_rescued","walk"],["dai_zong","dai_zong_rescued","walk"],
		["dong_chao","dong_chao_escort","walk",2],["xue_ba","xue_ba_escort","walk",2]]:
		var expected: int = spec[3] if spec.size()>3 else 4
		var direction_hashes: Dictionary={}
		for direction in CA.DIRECTIONS:
			var label: String=spec[1]+"|"+spec[2]+"|"+direction
			_check(label+" exact file exists",art.campaign_variant_has_animation(spec[1],spec[2],direction))
			var frames: Array=art.unit_anim_frames(spec[0],spec[2],direction,spec[1])
			var data: Array=[]
			var hashes: Dictionary={}
			var lower: Dictionary={}
			var valid := frames.size()==expected
			for frame in frames:
				var p := _profile(frame.get_image())
				data.append(p); hashes[p.pixels]=true; lower[p.lower_mask]=true
				valid=valid and p.size=="(256, 256)" and p.alpha_zero>1000 and not p.edge_cut and absi(p.bottom-210)<=3
			_check(label+" %d distinct frames with changing leg silhouettes"%expected,valid and hashes.size()==expected and lower.size()==expected)
			profiles[label]=data
			if not data.is_empty(): direction_hashes[data[0].pixels]=true
		_check(spec[1]+" "+spec[2]+" four different viewpoints",direction_hashes.size()==4)
	for variant in ["song_jiang_bound","song_jiang_rescued","dai_zong_bound","dai_zong_rescued","gao_qiu_captured","dong_chao_escort","xue_ba_escort"]:
		_check(variant+" own portrait",art.avatar_texture("gao_qiu",variant).resource_path==CA.still_path(variant))
	for direction in CA.DIRECTIONS:
		for state in ["idle","down"]:
			_check("Gao captive "+state+" "+direction,art.campaign_variant_has_animation("gao_qiu_captured",state,direction))
	_check("missing assisted cannot be faked by idle fallback",not art.campaign_variant_has_animation("wu_song_mengzhou","assisted","se") and not art.unit_anim_frames("wu_song","assisted","se","wu_song_mengzhou").is_empty())
	_check("unknown variant and invalid direction are absent",not art.campaign_variant_has_animation("not_a_variant","walk","se") and not art.campaign_variant_has_animation("lin_chong_escort","assisted","wrong"))
	_check("campaign assets do not replace free-mode resources",art.unit_anim_frames("song_jiang","walk")==old_song and art.avatar_texture("dai_zong")==old_dai)
	var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campaign/slice_qa.json"))
	var frames := 0
	var unique: Dictionary={}
	var legacy_variants: Dictionary={}
	for entry in inventory.frames:
		frames+=entry.count; unique[entry.variant+"|"+entry.state+"|"+entry.direction]=true
		legacy_variants[entry.variant]=true
	_check("inventory 188 unique strips and 312 frames",inventory.frames.size()==188 and unique.size()==188 and frames==312)
	var legacy_registered := true
	for variant in legacy_variants:
		legacy_registered = legacy_registered and variant in CA.ANIMATED_VARIANTS
	_check("legacy inventory 22 objects and 20 still registered variants",inventory.objects.size()==22 and legacy_variants.size()==20 and legacy_registered)
	var okay: bool=checks.all(func(c):return c.passed)
	# Preserve the historical pre-web report. New assets have independent web QA.
	var report_path := "res://assets/campaign/motion_contract_qa_with_web.json" if FileAccess.file_exists("res://assets/campaign/web_art_manifest.json") else "res://assets/campaign/motion_contract_qa.json"
	var out := FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed":okay,"checks":checks,"profiles":profiles,"inventory":{"strips":unique.size(),"frames":frames,"objects":inventory.objects.size(),"variants":legacy_variants.size(),"registered_variants_total":CA.ANIMATED_VARIANTS.size()}},"\t"))
	print("[campaign_motion_art_contract] checks=%d passed=%s"%[checks.size(),okay])
	quit(0 if okay else 5)
