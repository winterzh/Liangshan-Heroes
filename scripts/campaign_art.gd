extends RefCounted
## 战役专用资源目录。只通过显式 variant / object key 使用，不覆盖自由模式同名角色。
const ROOT := "res://assets/campaign/"
const ANCHOR := Vector2(0.5, 0.82)
const DIRECTIONS := ["se", "sw", "ne", "nw"]
## 原著已明言的旗号文字。这里是唯一的文字白名单：渲染层只能按 id
## 取用，不能从关卡名、单位名或贴图文件名自由拼出旗文。
##
## 第七十一回：山顶杏黄旗「替天行道」；忠义堂前两面绣字红旗
## 「山东呼保义」「河北玉麒麟」。第八十回：高俅中军船「帅字旗」；
## 先锋头船两面红旗合书十四字。原文没有逐面分配七字，本作只把它作为
## 一组编制旗排在同一艘先锋头船的两面旗上，不能解释成三名将领各有私旗。
## 第四十八回祝家庄门前一对白旗的两行文字各绑定一面本关 banner；
## 当前地图左右/前后落位只是排版，不反推为原著规定的旗面次序。
const FLAG_TEXT_SPECS := {
	"gao_flagship_command": {
		"text": "帅", "chapter": "第八十回", "scope": "dynamic:gao_flagship_only",
		"leaders": ["高俅"],
		"states": ["default", "damaged", "flooding", "disabled"], "layout": "single", "text_only": true,
		"ground_color": "111819", "trim_color": "ab3b2d", "ink_color": "f2ddb0",
		# 相对本批 512px 真四向物件画布的主旗内侧。网页原图已经提供空白红旗布，
		# 这里只叠加单个「帅」字，不画底色、边框，也不遮盖任何网页像素。
		"dynamic_rects": {
			"se": [0.590, 0.168, 0.074, 0.092], "sw": [0.572, 0.189, 0.074, 0.092],
			"ne": [0.373, 0.166, 0.074, 0.092], "nw": [0.547, 0.287, 0.074, 0.092],
		},
	},
	"liangshan_hilltop_standard": {
		"text": "替天行道", "chapter": "第七十一回", "scope": "static:liangshan_hilltop_only",
		"layout": "vertical", "ground_color": "c79c37", "trim_color": "7e551e", "ink_color": "241d13",
		"static_rect": [0.405, 0.050, 0.190, 0.500],
	},
	"zhongyi_hall_standard_west": {
		"text": "山东呼保义", "chapter": "第七十一回", "scope": "static:zhongyi_hall_front_only",
		"layout": "vertical", "ground_color": "9f3229", "trim_color": "d2a244", "ink_color": "f3dfb3",
		"static_rect": [0.380, 0.100, 0.240, 0.470],
	},
	"zhongyi_hall_standard_east": {
		"text": "河北玉麒麟", "chapter": "第七十一回", "scope": "static:zhongyi_hall_front_only",
		"layout": "vertical", "ground_color": "9f3229", "trim_color": "d2a244", "ink_color": "f3dfb3",
		"static_rect": [0.380, 0.100, 0.240, 0.470],
	},
	"zhujiazhuang_gate_chao_standard": {
		"text": "填平水泊擒晁盖", "chapter": "第四十八回",
		"scope": "static:level3_zhujiazhuang_gate_pair_only",
		"layout": "vertical", "ground_color": "e9e3d4", "trim_color": "81796b", "ink_color": "201d19",
		# 通用竖旗只作支架；运行时白底和原文严格盖在旗心，不改 terrain_sheet.png。
		"static_rect": [0.385, 0.045, 0.230, 0.600],
	},
	"zhujiazhuang_gate_song_standard": {
		"text": "踏破梁山捉宋江", "chapter": "第四十八回",
		"scope": "static:level3_zhujiazhuang_gate_pair_only",
		"layout": "vertical", "ground_color": "e9e3d4", "trim_color": "81796b", "ink_color": "201d19",
		"static_rect": [0.385, 0.045, 0.230, 0.600],
	},
	"official_vanguard_red_pair": {
		"text": "搅海翻江冲巨浪，安邦定国灭洪妖", "chapter": "第八十回",
		"scope": "dynamic:third-battle-vanguard-headship-pair-only", "leaders": ["丘岳", "徐京", "梅展"],
		"states": ["default", "damaged", "flooding", "disabled"], "layout": "paired_only",
		# 两面旗都是同一先锋头船的编制旗；按原文逗号仅作排版换行，绝不归给个人。
		# 这些矩形只标示网页端空白旗面的内侧，按船况和朝向逐格量取，避免将
		# 本地绘制的旗布盖到网页端生成的像素上。
		"dynamic_pair_rects": {
			"default": {
				"se": [[0.137, 0.141, 0.092, 0.238], [0.709, 0.307, 0.070, 0.236]],
				"sw": [[0.232, 0.307, 0.086, 0.252], [0.768, 0.098, 0.082, 0.221]],
				"ne": [[0.215, 0.098, 0.072, 0.217], [0.727, 0.285, 0.072, 0.275]],
				"nw": [[0.238, 0.295, 0.078, 0.281], [0.766, 0.150, 0.070, 0.229]],
			},
			"damaged": {
				"se": [[0.141, 0.129, 0.088, 0.244], [0.707, 0.309, 0.088, 0.240]],
				"sw": [[0.230, 0.312, 0.090, 0.258], [0.762, 0.102, 0.068, 0.211]],
				"ne": [[0.205, 0.074, 0.088, 0.254], [0.723, 0.354, 0.076, 0.252]],
				"nw": [[0.221, 0.270, 0.098, 0.271], [0.756, 0.117, 0.072, 0.236]],
			},
			"flooding": {
				"se": [[0.186, 0.135, 0.102, 0.211], [0.707, 0.359, 0.102, 0.227]],
				"sw": [[0.232, 0.381, 0.074, 0.232], [0.734, 0.107, 0.086, 0.197]],
				"ne": [[0.195, 0.137, 0.080, 0.217], [0.701, 0.412, 0.078, 0.229]],
				"nw": [[0.203, 0.338, 0.105, 0.234], [0.768, 0.176, 0.076, 0.213]],
			},
			"disabled": {
				"se": [[0.162, 0.113, 0.086, 0.211], [0.713, 0.275, 0.074, 0.248]],
				"sw": [[0.215, 0.334, 0.090, 0.236], [0.727, 0.121, 0.078, 0.172]],
				"ne": [[0.230, 0.102, 0.064, 0.203], [0.730, 0.348, 0.082, 0.197]],
				"nw": [[0.215, 0.232, 0.092, 0.279], [0.746, 0.119, 0.076, 0.201]],
			},
		},
	},
	"ruan_three_heroes_lure": {
		"text": "梁山泊阮氏三雄", "chapter": "第八十回",
		"scope": "dynamic:third-battle-ruan-lure-event-only", "leaders": ["阮小二", "阮小五", "阮小七"],
		"layout": "single",
	},
}

## 动态旗号必须同时匹配单位 key、战役物件 key 和（若有）剧情编制 context。
## 通用官船、普通梁山战船、刘梦龙前两败手旗均没有原文可用的旗面文字，
## 故意没有路由。先锋头船也只能由第八十回部署显式给 context。
const DYNAMIC_FLAG_ROUTES := {
	"gao_flagship": {
		"object_key": "gao_flagship", "overlay_id": "gao_flagship_command",
		"required_context": "chapter80_gao_flagship", "require_exact_directional_art": true,
	},
	"official_vanguard": {
		"object_key": "official_vanguard", "overlay_id": "official_vanguard_red_pair",
		"required_context": "chapter80_vanguard_headship", "require_exact_directional_art": true,
	},
}

## 静态旗必须同时落在指定关卡和指定的 banner 布景上。marker 本身只是
## 美术落点名称，不能因为别的关卡复用了同名 marker 就带出原著旗文。
const STATIC_FLAG_ROUTES := {
	"liangshan_hilltop_standard": {
		"overlay_id": "liangshan_hilltop_standard", "level_id": "level5", "decor_key": "banner",
	},
	"zhongyi_hall_standard_west": {
		"overlay_id": "zhongyi_hall_standard_west", "level_id": "level5", "decor_key": "banner",
	},
	"zhongyi_hall_standard_east": {
		"overlay_id": "zhongyi_hall_standard_east", "level_id": "level5", "decor_key": "banner",
	},
	"zhujiazhuang_gate_chao_standard": {
		"overlay_id": "zhujiazhuang_gate_chao_standard", "level_id": "level3", "decor_key": "banner",
	},
	"zhujiazhuang_gate_song_standard": {
		"overlay_id": "zhujiazhuang_gate_song_standard", "level_id": "level3", "decor_key": "banner",
	},
}

## 供资料表与契约查询的 marker 白名单；实际绘制必须走 static_flag_route。
const STATIC_FLAG_BY_MARKER := {
	"liangshan_hilltop_standard": "liangshan_hilltop_standard",
	"zhongyi_hall_standard_west": "zhongyi_hall_standard_west",
	"zhongyi_hall_standard_east": "zhongyi_hall_standard_east",
	"zhujiazhuang_gate_chao_standard": "zhujiazhuang_gate_chao_standard",
	"zhujiazhuang_gate_song_standard": "zhujiazhuang_gate_song_standard",
}

const ANIMATED_VARIANTS := ["wu_song_mengzhou", "lin_chong_prisoner", "lin_chong_bound", "lin_chong_escort", "jiang_menshen_fists", "li_kui_jiangzhou", "lu_zhishen_rescue", "shi_qian_lantern", "chai_jin_officer", "yue_he_officer", "bound_lu_junyi", "bound_shi_xiu", "rescued_lu_junyi", "rescued_shi_xiu", "song_jiang_bound", "song_jiang_rescued", "dai_zong_bound", "dai_zong_rescued", "gao_qiu_captured", "dong_chao_escort", "xue_ba_escort",
	"hn_chao_gai", "hn_wu_yong", "hn_gongsun_sheng", "hn_liu_tang", "hn_ruan_xiaoer", "hn_ruan_xiaowu", "hn_ruan_xiaoqi", "hn_bai_sheng",
	"town_vendor", "town_porter", "town_woman", "town_elder",
	"daming_bound_lu_junyi", "daming_rescued_lu_junyi", "daming_bound_shi_xiu", "daming_rescued_shi_xiu"]

## 野猪林的拦棍事件继续使用 story_pose="intercept"，但本批网页图只
## 提供经过原著武器复核的控制性横挥 attack。显式别名保证事件读取同一
## 朝向的新浑铁禅杖帧，而不会落回旧的月牙铲 intercept 位图。
const ANIMATION_STATE_ALIASES := {
	"lu_zhishen_rescue": {"intercept": "attack"},
}

## 祝家庄第三日的六名囚犯还没有各自的网页位图。这里显式登记为
## “本体造型 + 共用绳索覆盖”的程序化被缚变体，既保留每个人的脸和服色，
## 也不把石秀的专用被缚图冒充成别人。键和值必须一一对应；调用方若把
## variant 挂到错误人物上会拒绝取图，避免跨人物、跨关卡串造型。
const PROGRAMMATIC_BOUND_VARIANTS := {
	"bound_shi_qian": "shi_qian",
	"bound_qin_ming": "qin_ming",
	"bound_yang_lin": "yang_lin",
	"bound_huang_xin": "huang_xin",
	"bound_wang_ying": "wang_ying",
	"bound_deng_fei": "deng_fei",
}

## 江州刑台使用现有通用刑台格，不虚报成一张尚不存在的战役专图。
## 这是显式的战役物件别名；其返回值由 ArtDB 从通用地形图集取用。
const GENERIC_OBJECT_ALIASES := {
	"jiangzhou_scaffold": "scaffold",
}
const OBJECT_ALIASES := {
	"tribute_load": "tribute_load", "wine_buckets": "wine_buckets", "jujube_load": "jujube_load", "jujube_cart": "jujube_cart", "wine_bowls": "wine_bowls",
	"bailong_temple": "bailong_temple", "cuiyun_tower": "cuiyun_tower", "cuiyun_signal": "cuiyun_tower",
	"prison_gate": "prison_gate", "daming_prison_gate": "prison_gate", "official_warship": "official_warship", "official_vanguard": "official_vanguard", "gao_flagship": "gao_flagship",
	"liangshan_boat": "liangshan_boat", "hook_spear_team": "hook_spear_team", "broken_cavalry": "broken_cavalry", "linked_cavalry": "linked_cavalry",
	"daming_south_gate": "daming_south_gate", "roadside_tavern": "roadside_tavern", "heyang_tavern": "heyang_tavern", "hook_training_dummy": "hook_training_dummy",
	"death_remains": "death_remains",
}


static func programmatic_bound_owner(variant: String) -> String:
	return String(PROGRAMMATIC_BOUND_VARIANTS.get(variant, ""))


static func generic_object_alias(variant: String) -> String:
	return String(GENERIC_OBJECT_ALIASES.get(variant, ""))

static func animation_path(variant: String, state: String, direction: String) -> String:
	if not variant in ANIMATED_VARIANTS: return ""
	if direction not in DIRECTIONS: return ""
	# down is a non-lethal story outcome; death is an ordinary fatal animation.
	# Keep their paths distinct so a campaign pose cannot silently change meaning.
	var resolved_state := state
	if ANIMATION_STATE_ALIASES.has(variant):
		resolved_state = String((ANIMATION_STATE_ALIASES[variant] as Dictionary).get(state, state))
	return ROOT + "anim/%s_%s_%s.png" % [variant, resolved_state, direction]


static func direction_from_delta(delta: Vector2, fallback := "se") -> String:
	if delta.length_squared() <= 0.000001:
		return fallback if fallback in DIRECTIONS else "se"
	var screen := Vector2(delta.x - delta.y, (delta.x + delta.y) * 0.5)
	return ("se" if screen.x >= 0.0 else "sw") if screen.y >= 0.0 else ("ne" if screen.x >= 0.0 else "nw")


## 返回副本，避免场景脚本改写原著旗号白名单。
static func flag_text_spec(id: String) -> Dictionary:
	if not FLAG_TEXT_SPECS.has(id):
		return {}
	return (FLAG_TEXT_SPECS[id] as Dictionary).duplicate(true)


## 仅返回同时匹配 unit/object/context 的旗号路由，避免有脚本把任意水军
## 改成 gao_flagship 物件后就得到「帅」字旗。
static func dynamic_flag_route(unit_key: String, object_key: String, context := "") -> Dictionary:
	if not DYNAMIC_FLAG_ROUTES.has(unit_key):
		return {}
	var route: Dictionary = DYNAMIC_FLAG_ROUTES[unit_key]
	if String(route.get("object_key", "")) != object_key:
		return {}
	var required_context := String(route.get("required_context", ""))
	if not required_context.is_empty() and context != required_context:
		return {}
	return route.duplicate(true)


static func static_flag_overlay_id(marker: String) -> String:
	return String(STATIC_FLAG_BY_MARKER.get(marker, ""))


static func static_flag_route(marker: String, level_id: String, decor_key: String) -> Dictionary:
	if not STATIC_FLAG_ROUTES.has(marker):
		return {}
	var route: Dictionary = STATIC_FLAG_ROUTES[marker]
	if String(route.get("level_id", "")) != level_id:
		return {}
	if String(route.get("decor_key", "")) != decor_key:
		return {}
	return route.duplicate(true)

static func object_path(key: String, state := "default") -> String:
	if not OBJECT_ALIASES.has(key): return ""
	var k: String = OBJECT_ALIASES[key]
	var s := state
	if k == "cuiyun_tower":
		s = "signal" if state in ["signal", "lit", "burning", "fire"] else "default"
	elif k == "prison_gate":
		s = "open" if state in ["open", "rescued"] else "default"
	elif k in ["official_warship", "official_vanguard", "gao_flagship"]:
		s = state if state in ["damaged", "flooding", "disabled"] else "default"
	elif k == "hook_spear_team":
		s = "engaged" if state == "engaged" else "default"
	else:
		s = "default"
	return ROOT + "objects/%s_%s.png" % [k, s]


## 动态船只的真四向资源。保持 object_path 的旧接口不变，缺图由调用方严格回退旧图。
static func object_direction_path(key: String, state := "default", direction := "") -> String:
	if direction not in DIRECTIONS or not OBJECT_ALIASES.has(key):
		return ""
	var k: String = OBJECT_ALIASES[key]
	var s := "default"
	if k in ["official_warship", "official_vanguard", "gao_flagship"]:
		s = state if state in ["damaged", "flooding", "disabled"] else "default"
	elif k != "liangshan_boat":
		return ""
	return ROOT + "objects/%s_%s_%s.png" % [k, s, direction]

static func still_path(variant: String) -> String:
	if variant in ANIMATED_VARIANTS:
		return ROOT + "portraits/%s.png" % variant
	return object_path(variant)
