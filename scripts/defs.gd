class_name Defs
## 全战役单位与技能中央注册表。关卡按 key 引用；技能用数据化 effect 描述，
## 由 Battle._do_ability 统一结算，无需为每个技能写分支。

# 单位定义。字段：name,hp,atk,cd(出手间隔),range(像素),speed,
# ranged,cavalry,hero,bonus_cav,aura("atk"/"speed"),aura_r,aura_p,building,ability,radius,
# 以及关卡用标签：objective/captive/noncombat/scout/porter/elite_guard。
const UNITS := {
	# ---- 通用troops / 梁山主将（第5关及复用） ----
	"song_jiang": {"name": "宋江", "hp": 280, "atk": 18, "cd": 0.9, "range": 26, "speed": 78,
		"hero": true, "aura": "atk", "aura_r": 170, "aura_p": 1.25, "radius": 13, "ability": "song_rally",
		"abilities": ["song_rally", "song_haste", "song_fire", "song_lead"],
		"hero_trainable": true, "pop": 3, "cost_gold": 160, "cost_wood": 40, "train_time": 38.0, "trained_at": "hall", "min_age": 2},
	"wu_yong": {"name": "吴用", "hp": 150, "atk": 11, "cd": 1.2, "range": 200, "speed": 78,
		"ranged": true, "hero": true, "aura": "speed", "aura_r": 170, "aura_p": 1.15, "radius": 12, "ability": "wu_fire"},
	"lin_chong": {"name": "林冲", "hp": 320, "atk": 24, "cd": 0.8, "range": 30, "speed": 88,
		"hero": true, "bonus_cav": 2.0, "radius": 13, "ability": "lin_sweep",
		"abilities": ["lin_thrust", "lin_sweep", "lin_predator", "lin_chrono"],
		"hero_trainable": true, "pop": 3, "cost_gold": 156, "cost_wood": 32, "train_time": 38.0, "trained_at": "hall", "min_age": 2},
	"hua_rong": {"name": "花荣", "hp": 180, "atk": 16, "cd": 0.9, "range": 230, "speed": 82,
		"ranged": true, "melee_switch": true, "hero": true, "radius": 12, "ability": "hua_shot",
		"abilities": ["hua_blink", "hua_rain", "hua_pin", "hua_blade"],
		"hero_trainable": true, "pop": 3, "cost_gold": 152, "cost_wood": 44, "train_time": 36.0, "trained_at": "hall", "min_age": 2},
	"liang_dao": {"name": "朴刀手", "hp": 110, "atk": 12, "cd": 1.0, "range": 24, "speed": 72,
		"pop": 1, "cost_gold": 60, "cost_wood": 0, "train_time": 16.0, "trained_at": "barracks"},
	"liang_qiang": {"name": "长枪手", "hp": 115, "atk": 10, "cd": 1.1, "range": 30, "speed": 66, "bonus_cav": 2.2,
		"pop": 1, "cost_gold": 50, "cost_wood": 20, "train_time": 17.0, "trained_at": "barracks"},
	"liang_gong": {"name": "弓手", "hp": 65, "atk": 10, "cd": 1.4, "range": 185, "speed": 74, "ranged": true, "radius": 10,
		"pop": 1, "cost_gold": 45, "cost_wood": 30, "train_time": 16.0, "trained_at": "barracks"},
	"guan_dao": {"name": "官军刀盾兵", "hp": 85, "atk": 9, "cd": 1.0, "range": 24, "speed": 64},
	"guan_gong": {"name": "官军弓手", "hp": 55, "atk": 7, "cd": 1.4, "range": 165, "speed": 64, "ranged": true, "radius": 10},
	"guan_qi": {"name": "官军骑兵", "hp": 200, "atk": 13, "cd": 1.0, "range": 26, "speed": 112, "cavalry": true, "radius": 13},
	"gao_qiu": {"name": "高俅", "hp": 1830, "atk": 51, "cd": 0.8, "range": 30, "speed": 95,
		"hero": true, "cavalry": true, "aura": "atk", "aura_r": 200, "aura_p": 1.2, "radius": 15,
		"ability": "guan_charge",
		"abilities": ["guan_barrage", "guan_charge", "guan_valor", "guan_rally"]},
	"hall": {"name": "聚义厅", "hp": 1500, "atk": 0, "building": true, "radius": 58, "drop_off": true, "is_main_base": true,
		"produces": ["lou_luo", "song_jiang", "lin_chong", "hua_rong", "li_kui", "gongsun_sheng", "wu_song"], "is_altar": true,
		"researches": ["tech_age2", "tech_age3", "tech_gather"], "garrison_cap": 10},

	# ---- 召唤物（技能产出，不可训练；血/攻在召唤时按等级覆盖） ----
	"tiger_summon": {"name": "猛虎", "hp": 150, "atk": 15, "cd": 0.95, "range": 26, "speed": 116,
		"cavalry": true, "radius": 13, "pop": 0, "xp": 18},
	"dragon_summon": {"name": "金龙", "hp": 165, "atk": 12, "cd": 1.1, "range": 190, "speed": 96,
		"ranged": true, "proj_kind": "fireball", "splash": 50.0,
		"radius": 18, "pop": 0, "xp": 30, "summon_kind": "dragon"},

	# ---- 第1关 智取生辰纲 ----
	"chao_gai": {"name": "晁盖", "hp": 300, "atk": 19, "cd": 0.85, "range": 28, "speed": 80,
		"hero": true, "aura": "atk", "aura_r": 180, "aura_p": 1.25, "radius": 13, "ability": "chao_rally"},
	"gongsun_sheng": {"name": "公孙胜", "hp": 165, "atk": 12, "cd": 1.2, "range": 200, "speed": 78,
		"ranged": true, "hero": true, "aura": "speed", "aura_r": 175, "aura_p": 1.15, "radius": 12, "ability": "gongsun_thunder",
		"proj_kind": "fireball",
		"abilities": ["gong_blackrain", "gong_icewall", "gong_slow", "gong_dragon"],
		"hero_trainable": true, "pop": 3, "cost_gold": 168, "cost_wood": 56, "train_time": 40.0, "trained_at": "hall", "min_age": 2},
	"liu_tang": {"name": "刘唐", "hp": 210, "atk": 22, "cd": 0.8, "range": 26, "speed": 86, "hero": true, "radius": 13, "ability": "liu_cleave"},
	"ruan_brother": {"name": "阮氏好汉", "hp": 130, "atk": 14, "cd": 0.9, "range": 26, "speed": 92, "radius": 11},
	"bai_sheng": {"name": "白胜", "hp": 70, "atk": 8, "cd": 1.1, "range": 24, "speed": 96, "radius": 10, "scout": true, "ability": "bai_drug"},
	"yang_zhi": {"name": "杨志", "hp": 360, "atk": 23, "cd": 0.8, "range": 30, "speed": 90, "hero": true, "radius": 14, "elite_guard": true},
	"yu_hou": {"name": "虞候", "hp": 95, "atk": 11, "cd": 1.0, "range": 26, "speed": 70, "radius": 11},
	"jun_han": {"name": "军汉", "hp": 80, "atk": 9, "cd": 1.1, "range": 24, "speed": 64, "radius": 10, "porter": true},
	"lao_duguan": {"name": "老都管", "hp": 70, "atk": 4, "cd": 1.4, "range": 24, "speed": 58, "radius": 10, "noncombat": true},
	"treasure_cart": {"name": "生辰纲宝车", "hp": 900, "atk": 0, "building": true, "radius": 20, "objective": true},

	# ---- 第2关 江州劫法场 ----
	"li_kui": {"name": "李逵", "hp": 320, "atk": 21, "cd": 0.75, "range": 28, "speed": 80, "hero": true, "radius": 13, "ability": "li_berserk",
		"abilities": ["li_axes", "li_charge", "li_brawn", "li_fury"],
		"hero_trainable": true, "pop": 3, "cost_gold": 148, "cost_wood": 24, "train_time": 36.0, "trained_at": "hall", "min_age": 2},
	"dai_zong": {"name": "戴宗", "hp": 200, "atk": 15, "cd": 0.9, "range": 26, "speed": 150,
		"hero": true, "aura": "speed", "aura_r": 180, "aura_p": 1.15, "radius": 12, "ability": "dai_dash"},
	"zhang_shun": {"name": "张顺", "hp": 210, "atk": 16, "cd": 0.85, "range": 26, "speed": 88, "hero": true, "radius": 12, "ability": "zhang_drag"},
	"yan_shun": {"name": "燕顺", "hp": 190, "atk": 16, "cd": 0.85, "range": 28, "speed": 78, "hero": true, "radius": 12},
	"guan_zhanzi": {"name": "刽子手", "hp": 130, "atk": 14, "cd": 1.1, "range": 26, "speed": 60, "radius": 12},
	# 攻城投石车：射程很远、移速慢；对箭楼 ×3 伤害(仅箭楼，其余建筑/单位无加成)，约 5 下拆一座箭楼。
	"siege_cata": {"name": "投石车", "hp": 260, "atk": 47, "cd": 3.0, "range": 280, "speed": 32, "ranged": true,
		"radius": 16, "vs_tower": 3.0, "vs_hero": 0.3, "xp": 30.0,
		"pop": 3, "cost_gold": 150, "cost_wood": 40, "train_time": 30.0, "trained_at": "siege_workshop", "min_age": 3},
	# 撞车：硬克制攻城——对一切建筑 ×8 巨伤、护甲厚抗箭，但对人只挠痒(atk低)且移速慢，必须有兵护着推。
	"siege_ram": {"name": "撞车", "hp": 380, "atk": 6, "cd": 2.0, "range": 30, "speed": 30,
		"radius": 16, "vs_building": 8.0, "vs_hero": 0.3, "xp": 26.0,
		"pop": 3, "cost_gold": 110, "cost_wood": 70, "train_time": 26.0, "trained_at": "siege_workshop", "min_age": 3},
	"guan_laozi": {"name": "江州牢子", "hp": 80, "atk": 9, "cd": 1.05, "range": 24, "speed": 62, "radius": 11},
	"cai_jiu": {"name": "蔡九知府", "hp": 260, "atk": 12, "cd": 1.0, "range": 26, "speed": 70,
		"hero": true, "aura": "atk", "aura_r": 180, "aura_p": 1.2, "radius": 13},
	"scaffold": {"name": "法场刑台", "hp": 1200, "atk": 0, "building": true, "radius": 46},
	"song_jiang_bound": {"name": "宋江", "hp": 200, "atk": 0, "building": true, "radius": 13, "captive": true},
	"dai_zong_bound": {"name": "戴宗", "hp": 150, "atk": 0, "building": true, "radius": 12, "captive": true},

	# ---- 第3关 三打祝家庄 ----
	"shi_xiu": {"name": "石秀", "hp": 230, "atk": 19, "cd": 0.85, "range": 26, "speed": 86, "hero": true, "radius": 12, "ability": "shi_xiu_path"},
	"zhu_long": {"name": "祝龙", "hp": 1200, "atk": 51, "cd": 0.85, "range": 30, "speed": 108, "cavalry": true, "hero": true, "radius": 13},
	"zhu_hu": {"name": "祝虎", "hp": 320, "atk": 20, "cd": 0.9, "range": 28, "speed": 106, "cavalry": true,
		"hero": true, "aura": "atk", "aura_r": 180, "aura_p": 1.2, "radius": 13},
	"zhu_biao": {"name": "祝彪", "hp": 800, "atk": 39, "cd": 1.1, "range": 210, "speed": 96, "ranged": true, "hero": true, "radius": 12},
	"luan_tingyu": {"name": "栾廷玉", "hp": 1400, "atk": 56, "cd": 1.0, "range": 30, "speed": 80, "hero": true, "radius": 13, "ability": "luan_smash",
		"abilities": ["luan_smash", "guan_charge", "guan_valor", "guan_fury"]},
	"zhu_zhaofeng": {"name": "祝朝奉", "hp": 670, "atk": 28, "cd": 1.4, "range": 28, "speed": 60, "hero": true, "radius": 12},
	"hu_sanniang": {"name": "扈三娘", "hp": 420, "atk": 42, "cd": 0.8, "range": 26, "speed": 112, "cavalry": true, "hero": true, "radius": 13},
	"zhu_keke": {"name": "祝家庄客", "hp": 95, "atk": 11, "cd": 1.0, "range": 24, "speed": 66},
	"zhu_gong": {"name": "祝家弓手", "hp": 60, "atk": 9, "cd": 1.4, "range": 180, "speed": 64, "ranged": true, "radius": 10},
	"zhu_qi": {"name": "祝家马军", "hp": 200, "atk": 13, "cd": 1.0, "range": 26, "speed": 110, "cavalry": true, "radius": 13},
	"zhu_gate": {"name": "祝家庄门", "hp": 1600, "atk": 0, "building": true, "radius": 22},

	# ---- 第4关 大破连环马 ----
	"lian_huan_ma": {"name": "连环马", "hp": 300, "atk": 15, "cd": 1.0, "range": 26, "speed": 118, "cavalry": true, "radius": 13},
	"gou_lian": {"name": "钩镰枪手", "hp": 105, "atk": 11, "cd": 1.1, "range": 30, "speed": 68, "bonus_cav": 3.5},
	"xu_ning": {"name": "徐宁", "hp": 210, "atk": 20, "cd": 0.85, "range": 30, "speed": 80, "hero": true, "bonus_cav": 2.0, "radius": 13, "ability": "xu_drill"},
	"hu_yanzhuo": {"name": "呼延灼", "hp": 780, "atk": 53, "cd": 0.8, "range": 30, "speed": 110, "cavalry": true,
		"hero": true, "aura": "atk", "aura_r": 190, "aura_p": 1.2, "radius": 15, "ability": "hu_whips",
		"abilities": ["hu_whips", "guan_charge", "guan_valor", "guan_fury"]},
	"tang_long": {"name": "汤隆", "hp": 160, "atk": 12, "cd": 1.2, "range": 160, "speed": 78, "ranged": true, "hero": true, "radius": 12},
	"han_tao": {"name": "韩滔", "hp": 450, "atk": 42, "cd": 0.9, "range": 26, "speed": 114, "cavalry": true, "hero": true, "radius": 13},
	"peng_qi": {"name": "彭玘", "hp": 450, "atk": 42, "cd": 0.9, "range": 26, "speed": 114, "cavalry": true, "hero": true, "radius": 13},
	"jiangtai": {"name": "中军帅旗", "hp": 1600, "atk": 0, "building": true, "radius": 40},

	# ---- 第5关 可选增强 ----
	"guan_zhanchuan": {"name": "官军战船", "hp": 220, "atk": 14, "cd": 1.8, "range": 200, "speed": 70, "ranged": true, "radius": 16},
	"guan_jingqi": {"name": "官军精骑", "hp": 175, "atk": 16, "cd": 0.9, "range": 26, "speed": 100, "cavalry": true, "radius": 13},

	# ---- 第6关 大闹野猪林（鲁智深救林冲）----
	"lu_zhishen": {"name": "鲁智深", "hp": 540, "atk": 28, "cd": 0.78, "range": 30, "speed": 86,
		"hero": true, "radius": 14, "ability": "lu_sweep"},
	"lin_chong_bound": {"name": "林冲", "hp": 240, "atk": 0, "building": true, "radius": 13, "captive": true},
	"dong_chao": {"name": "董超", "hp": 150, "atk": 14, "cd": 0.95, "range": 26, "speed": 70, "radius": 11, "elite_guard": true},
	"xue_ba": {"name": "薛霸", "hp": 150, "atk": 14, "cd": 0.95, "range": 26, "speed": 70, "radius": 11, "elite_guard": true},
	"lu_qian": {"name": "陆谦", "hp": 870, "atk": 39, "cd": 0.9, "range": 28, "speed": 90, "hero": true, "radius": 12,
		"aura": "atk", "aura_r": 170, "aura_p": 1.15},
	"gong_ren": {"name": "防送公人", "hp": 85, "atk": 9, "cd": 1.05, "range": 24, "speed": 66, "radius": 10},

	# ---- 第7关 醉打蒋门神（武松快活林）----
	"wu_song": {"name": "武松", "hp": 360, "atk": 23, "cd": 0.78, "range": 28, "speed": 86,
		"hero": true, "radius": 13, "ability": "wu_kick",
		"abilities": ["wu_tigers", "wu_wine", "wu_blades", "wu_drunkgod"],
		"hero_trainable": true, "pop": 3, "cost_gold": 160, "cost_wood": 32, "train_time": 40.0, "trained_at": "hall", "min_age": 2},
	"shi_en": {"name": "施恩", "hp": 210, "atk": 15, "cd": 0.95, "range": 26, "speed": 80, "hero": true, "radius": 12},
	"jiang_menshen": {"name": "蒋门神", "hp": 1870, "atk": 53, "cd": 0.88, "range": 30, "speed": 76,
		"hero": true, "aura": "atk", "aura_r": 160, "aura_p": 1.1, "radius": 16, "ability": "jiang_smash", "elite_guard": true},
	"jiang_thug": {"name": "蒋家打手", "hp": 95, "atk": 11, "cd": 1.0, "range": 24, "speed": 66, "radius": 11},
	"zhang_tuanlian": {"name": "张团练", "hp": 1000, "atk": 42, "cd": 0.9, "range": 28, "speed": 96, "cavalry": true, "hero": true, "radius": 13},
	"tavern": {"name": "酒望", "hp": 100000, "atk": 0, "building": true, "radius": 18, "noncombat": true},
	"signboard": {"name": "蒋家招牌", "hp": 800, "atk": 0, "building": true, "radius": 20, "objective": true},

	# ---- 第8关 东昌府·飞石没羽箭（招安张清）----
	"zhang_qing": {"name": "张清", "hp": 690, "atk": 37, "cd": 1.1, "range": 235, "speed": 96,
		"ranged": true, "hero": true, "radius": 12, "ability": "zhang_stone"},
	"gong_wang": {"name": "龚旺", "hp": 315, "atk": 37, "cd": 0.9, "range": 26, "speed": 110, "cavalry": true, "hero": true, "radius": 13},
	"ding_desun": {"name": "丁得孙", "hp": 315, "atk": 37, "cd": 0.95, "range": 28, "speed": 80, "hero": true, "radius": 12},
	"dongchang_yamen": {"name": "东昌府衙", "hp": 1600, "atk": 0, "building": true, "radius": 40},

	# ---- 据守模式·新增地方英雄（曾头市教师·史文恭）----
	"shi_wengong": {"name": "史文恭", "hp": 2130, "atk": 63, "cd": 0.82, "range": 30, "speed": 92,
		"hero": true, "cavalry": true, "aura": "atk", "aura_r": 190, "aura_p": 1.2, "radius": 15, "ability": "shi_spear"},

	# ---- 自由「遭遇战」模式：经营 / 建造 / 资源 ----
	# 工人：采集金/木、建造；也能弱战斗。经济字段：worker/pop/cost_gold/cost_wood/build_time/trained_at。
	"lou_luo": {"name": "喽啰", "hp": 60, "atk": 5, "cd": 1.3, "range": 22, "speed": 70, "radius": 10,
		"worker": true, "pop": 1, "cost_gold": 20, "cost_wood": 0, "train_time": 14.0, "trained_at": "hall"},
	# 资源点（建筑形态，不可攻击）：res_kind=gold/wood，res_amount=储量
	"gold_mine": {"name": "金矿", "hp": 100000, "atk": 0, "building": true, "radius": 26,
		"noncombat": true, "res_kind": "gold", "res_amount": 6000},
	"tree": {"name": "林木", "hp": 100000, "atk": 0, "building": true, "radius": 13,
		"noncombat": true, "res_kind": "wood", "res_amount": 1800},

	# 可建造建筑：buildable=true，cost_gold/cost_wood/build_time；produces/provides_pop/drop_off
	"barracks": {"name": "兵营", "hp": 900, "atk": 0, "building": true, "radius": 30, "buildable": true, "build_order": 1,
		"cost_gold": 150, "cost_wood": 80, "build_time": 28.0,
		"produces": ["liang_dao", "liang_qiang", "liang_gong", "liang_ma"],
		"researches": ["tech_weapon", "tech_armor"]},
	"liang_ma": {"name": "梁山马军", "hp": 210, "atk": 15, "cd": 0.95, "range": 26, "speed": 112, "cavalry": true, "radius": 13,
		"pop": 2, "cost_gold": 90, "cost_wood": 40, "train_time": 22.0, "trained_at": "barracks", "min_age": 2},
	"arrow_tower": {"name": "箭楼", "hp": 700, "atk": 17, "cd": 1.3, "range": 215, "speed": 0, "ranged": true,
		"building": true, "radius": 20, "buildable": true, "build_order": 2, "cost_gold": 110, "cost_wood": 60, "build_time": 24.0,
		"garrison_cap": 5, "min_age": 2},
	"house": {"name": "民居", "hp": 480, "atk": 0, "building": true, "radius": 20, "buildable": true, "build_order": 3,
		"cost_gold": 0, "cost_wood": 55, "build_time": 16.0, "provides_pop": 10},
	"depot": {"name": "仓库", "hp": 560, "atk": 0, "building": true, "radius": 20, "buildable": true, "build_order": 4,
		"cost_gold": 0, "cost_wood": 90, "build_time": 18.0, "drop_off": true},
	"market": {"name": "集市", "hp": 650, "atk": 0, "building": true, "radius": 22, "buildable": true, "build_order": 5,
		"cost_gold": 0, "cost_wood": 140, "build_time": 22.0, "trades": true, "min_age": 2},
	"siege_workshop": {"name": "攻城作坊", "hp": 820, "atk": 0, "building": true, "radius": 28, "buildable": true, "build_order": 6,
		"cost_gold": 160, "cost_wood": 120, "build_time": 30.0, "min_age": 3,
		"produces": ["siege_cata", "siege_ram"]},

	# ===== 驻守战·官军新兵种 =====
	# 火枪手：攻高、攻速慢、射程略远（高单发压制，怕近身/快骑切入）
	"guan_musket": {"name": "官军火枪手", "hp": 70, "atk": 24, "cd": 2.4, "range": 240, "speed": 60, "ranged": true, "radius": 11},
	# 投弹手：很小范围 AoE（splash 半径小），怕被风筝/被骑兵贴脸
	"guan_bomber": {"name": "官军投弹手", "hp": 82, "atk": 18, "cd": 2.2, "range": 150, "speed": 60, "ranged": true, "splash": 30.0, "radius": 11},
	# 战象：巨兽重骑，血厚攻高但慢——属骑兵，被长枪/钩镰/林冲克制
	"war_elephant": {"name": "战象", "hp": 800, "atk": 26, "cd": 1.4, "range": 32, "speed": 66, "cavalry": true, "radius": 20},
	# 驼骑：沙漠骆驼快骑，机动骚扰——属骑兵，被长枪/钩镰/林冲克制
	"camel_rider": {"name": "骆驼骑兵", "hp": 200, "atk": 14, "cd": 1.0, "range": 26, "speed": 124, "cavalry": true, "radius": 13},

	# ===== 驻守战·官军地方大将（敌方英雄；faction 由波次指定为官军）=====
	# 十节度使（朝廷征调的各路节度使，与梁山为敌）
	"wang_huan": {"name": "王焕", "hp": 1730, "atk": 51, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 15,
		"aura": "atk", "aura_r": 175, "aura_p": 1.15, "ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	"xu_jing": {"name": "徐京", "hp": 1530, "atk": 49, "cd": 1.0, "range": 30, "speed": 96, "hero": true, "radius": 14,
		"ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	"wang_wende": {"name": "王文德", "hp": 1500, "atk": 51, "cd": 0.95, "range": 28, "speed": 116, "hero": true, "cavalry": true, "radius": 14,
		"ability": "jd_charge", "abilities": ["jd_charge", "jd_valor"]},
	"mei_zhan": {"name": "梅展", "hp": 1500, "atk": 53, "cd": 0.9, "range": 28, "speed": 100, "hero": true, "radius": 14,
		"ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	"zhang_kai": {"name": "张开", "hp": 1270, "atk": 46, "cd": 1.7, "range": 200, "speed": 88, "ranged": true, "hero": true, "radius": 12,
		"ability": "guan_barrage", "abilities": ["guan_barrage", "jd_valor"]},
	"yang_wen": {"name": "杨温", "hp": 1500, "atk": 49, "cd": 1.0, "range": 30, "speed": 94, "hero": true, "radius": 14,
		"ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	"li_congji": {"name": "李从吉", "hp": 1530, "atk": 51, "cd": 0.95, "range": 28, "speed": 112, "hero": true, "cavalry": true, "radius": 14,
		"ability": "jd_charge", "abilities": ["jd_charge", "jd_valor"]},
	"xiang_yuanzhen": {"name": "项元镇", "hp": 1270, "atk": 46, "cd": 1.6, "range": 205, "speed": 90, "ranged": true, "hero": true, "radius": 12,
		"ability": "guan_barrage", "abilities": ["guan_barrage", "jd_valor"]},
	"jing_zhong": {"name": "荆忠", "hp": 1470, "atk": 49, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 14,
		"ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	"duan_pengju": {"name": "段鹏举", "hp": 1530, "atk": 51, "cd": 0.95, "range": 28, "speed": 116, "hero": true, "cavalry": true, "radius": 14,
		"ability": "jd_charge", "abilities": ["jd_charge", "jd_valor"]},
	# 特殊官军大将
	"tong_guan": {"name": "童贯", "hp": 2530, "atk": 56, "cd": 0.9, "range": 30, "speed": 96, "hero": true, "radius": 16,
		"aura": "atk", "aura_r": 210, "aura_p": 1.2, "ability": "tong_drums", "abilities": ["tong_drums", "guan_fury", "jd_valor"]},
	"ling_zhen": {"name": "凌振", "hp": 930, "atk": 46, "cd": 2.6, "range": 235, "speed": 60, "ranged": true, "hero": true, "radius": 13,
		"proj_kind": "fireball", "splash": 38.0, "ability": "ling_cannon", "abilities": ["ling_cannon", "jd_valor"]},
	"wei_dingguo": {"name": "魏定国", "hp": 1070, "atk": 42, "cd": 2.0, "range": 200, "speed": 84, "ranged": true, "hero": true, "radius": 12,
		"ability": "wei_fire", "abilities": ["wei_fire", "jd_valor"]},
	"shan_tinggui": {"name": "单廷圭", "hp": 1200, "atk": 44, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 14,
		"ability": "shan_flood", "abilities": ["shan_flood", "jd_valor"]},
	"wen_da": {"name": "闻达", "hp": 1600, "atk": 51, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 15,
		"aura": "atk", "aura_r": 170, "aura_p": 1.12, "ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
}

# 技能定义：name,cd,targeted,radius,color,desc(UI), 以及 effect(数据化结算描述)。
# effect.kind: rally(治疗+攻击buff队友) / haste(队友移速) / smite(范围伤敌,可附slow,可cav加成,可self自身buff)
#              / debuff(减速+削攻于敌) / drag(拖入水+伤害) / path(交给关卡处理)
const ABILITIES := {
	"song_rally": {"name": "替天行道", "cd": 12.0, "targeted": false, "radius": 200.0, "color": Color("ffd24a"),
		"desc": "号令群雄：周围梁山兵\n回血{v}、攻击+60%（8秒）", "effect": {"kind": "rally", "heal": 42.0, "atk_mult": 1.6, "dur": 8.0}},
	"wu_fire": {"name": "锦囊火计", "cd": 14.0, "targeted": true, "weak_global": true, "radius": 95.0, "color": Color("ff7a2a"),
		"desc": "火攻：指定处腾起烈焰\n地面燃烧5秒，累计130灼伤", "effect": {"kind": "fire_dot", "dmg": 130.0, "dur": 5.0}},
	"lin_sweep": {"name": "丈八横扫", "cd": 8.0, "targeted": false, "radius": 100.0, "color": Color("c0a0ff"),
		"desc": "豹子头怒扫：身边官军\n受{v}伤害并被减速", "effect": {"kind": "smite", "dmg": 25.0, "slow": 0.5, "slow_dur": 3.0}},
	"hua_shot": {"name": "百步穿杨", "cd": 9.0, "targeted": true, "radius": 48.0, "color": Color("a0e8c0"),
		"desc": "神箭：对目标处官军\n造成{v}穿透伤害", "effect": {"kind": "smite", "dmg": 50.0}},
	"chao_rally": {"name": "替天聚义", "cd": 14.0, "targeted": false, "radius": 200.0, "color": Color("ffd24a"),
		"desc": "号令七星：周围好汉\n回血40、攻击+55%（8秒）", "effect": {"kind": "rally", "heal": 40.0, "atk_mult": 1.55, "dur": 8.0}},
	"gongsun_thunder": {"name": "五雷天罡", "cd": 12.0, "targeted": true, "radius": 95.0, "color": Color("8fd3ff"),
		"desc": "作法落雷：指定处\n官军受40伤害并麻痹", "effect": {"kind": "smite", "dmg": 40.0, "slow": 0.5, "slow_dur": 2.5}},
	"liu_cleave": {"name": "赤发怒斩", "cd": 8.0, "targeted": false, "radius": 100.0, "color": Color("ff6a4a"),
		"desc": "近身横扫：身边官军\n受30伤害并被减速", "effect": {"kind": "smite", "dmg": 30.0, "slow": 0.5, "slow_dur": 3.0}},
	"bai_drug": {"name": "蒙汗药酒", "cd": 28.0, "targeted": true, "radius": 110.0, "color": Color("b8e060"),
		"desc": "下药：指定处官军被麻翻\n（移速攻防大降18秒）", "effect": {"kind": "debuff", "slow": 0.25, "atk_mult": 0.4, "dur": 18.0}},
	"li_berserk": {"name": "排头砍去", "cd": 9.0, "targeted": false, "radius": 95.0, "color": Color("ff5544"),
		"desc": "黑旋风一斧撼地：身边官军\n受{v}伤害并眩晕3秒；自身狂暴", "effect": {"kind": "smite", "dmg": 26.0, "stun": 3.0, "self_atk": 1.4, "self_dur": 5.0}},
	"dai_dash": {"name": "神行甲马", "cd": 12.0, "targeted": false, "radius": 200.0, "color": Color("9ce0a0"),
		"desc": "作神行法：周围梁山兵\n移速+50%（8秒）", "effect": {"kind": "haste", "speed_mult": 1.5, "dur": 8.0}},
	"zhang_drag": {"name": "浪里拖人", "cd": 9.0, "targeted": true, "radius": 60.0, "color": Color("5fbfe0"),
		"desc": "浪里白条：把目标处官军\n拖入水中（55伤害）", "effect": {"kind": "drag", "dmg": 55.0}},
	"shi_xiu_path": {"name": "指路·遇白杨转弯", "cd": 6.0, "targeted": false, "radius": 0.0, "color": Color("ffd866"),
		"desc": "拼命三郎探路：点亮\n前方盘陀路安全小道", "effect": {"kind": "path"}},
	"luan_smash": {"name": "铁棒横扫", "cd": 9.0, "targeted": false, "radius": 110.0, "color": Color("d0a060"),
		"desc": "（敌）栾廷玉铁棒横扫", "effect": {"kind": "smite", "dmg": 30.0, "slow": 0.5, "slow_dur": 3.0}},
	"hu_whips": {"name": "双鞭横扫", "cd": 10.0, "targeted": false, "radius": 120.0, "color": Color("d08050"),
		"desc": "（敌）呼延灼双鞭横扫", "effect": {"kind": "smite", "dmg": 32.0, "slow": 0.6, "slow_dur": 2.0}},
	"xu_drill": {"name": "钩镰枪法", "cd": 9.0, "targeted": false, "radius": 115.0, "color": Color("ffd24a"),
		"desc": "钩马腿：身边连环马\n受34破甲重伤（克骑兵翻倍）", "effect": {"kind": "smite", "dmg": 34.0, "cav_bonus": 2.0}},

	# ---- 官军大将·1v1 对战四技能组（敌方英雄用；复用现有 effect kind，名号官军化）----
	"guan_charge": {"name": "策马冲阵", "cd": 9.0, "targeted": false, "radius": 105.0, "color": Color("ff9a3a"),
		"desc": "（敌）官军大将策马冲阵\n身边梁山兵受 {v} 伤害减速，自身攻击大涨",
		"effect": {"kind": "smite", "dmg": 24.0, "slow": 0.4, "slow_dur": 1.5, "self_atk": 1.35, "self_dur": 5.0}},
	"guan_valor": {"name": "宿将之威", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("d0a060"),
		"desc": "（敌）被动·宿将之威\n生命+、攻击+", "effect": {"kind": "passive", "atk_add": 4.0, "hp_add": 80.0}},
	"guan_fury": {"name": "困兽死战", "cd": 24.0, "targeted": false, "radius": 0.0, "color": Color("ff3322"),
		"desc": "（敌）大招·困兽死战\n6 秒内 攻击大增、吸血回身",
		"effect": {"kind": "self_buff", "atk_add": 26.0, "lifesteal": 1.2, "dur": 6.0}},
	"guan_rally": {"name": "督战擂鼓", "cd": 16.0, "targeted": false, "radius": 200.0, "color": Color("ffd24a"),
		"desc": "（敌）大招·督战擂鼓\n周围官军回血、攻击+50%（8 秒）",
		"effect": {"kind": "rally", "heal": 36.0, "atk_mult": 1.5, "dur": 8.0}},
	"guan_barrage": {"name": "万箭压制", "cd": 11.0, "targeted": true, "radius": 100.0, "color": Color("cfd6dd"),
		"desc": "（敌）指定处万箭压制\n一次 {v} 伤害，箭簇钉地再灼 3 秒",
		"effect": {"kind": "smite", "dmg": 30.0, "dot_total": 18.0, "dot_dur": 3.0}},

	# ---- 第6关 大闹野猪林：鲁智深 ----
	"lu_sweep": {"name": "禅杖横扫", "cd": 8.0, "targeted": false, "radius": 120.0, "color": Color("e0c25a"),
		"desc": "花和尚抡铁禅杖横扫\n身边官军受 36 伤害打懵；自身狂禅+45%",
		"effect": {"kind": "smite", "dmg": 36.0, "slow": 0.35, "slow_dur": 2.5, "self_atk": 1.45, "self_dur": 6.0}},
	# ---- 第7关 醉打蒋门神：武松 / 蒋门神 ----
	"wu_kick": {"name": "玉环步·鸳鸯脚", "cd": 7.0, "targeted": false, "radius": 108.0, "color": Color("c8b0e8"),
		"desc": "武松醉步连环腿横扫\n身边官军受 34 伤害减速；自身嗜血狂攻",
		"effect": {"kind": "smite", "dmg": 34.0, "slow": 0.5, "slow_dur": 2.0, "self_atk": 1.35, "self_dur": 5.0, "self_lifesteal": 0.4, "self_lifesteal_dur": 5.0}},
	"jiang_smash": {"name": "泰山压顶", "cd": 8.0, "targeted": false, "radius": 122.0, "color": Color("d0703a"),
		"desc": "（敌）蒋门神挥拳横扫\n受 30 伤害并被砸退", "effect": {"kind": "smite", "dmg": 30.0, "slow": 0.5, "slow_dur": 2.0}},
	"shi_spear": {"name": "方天画戟·横扫", "cd": 8.0, "targeted": false, "radius": 125.0, "color": Color("b8c0d0"),
		"desc": "（敌）史文恭画戟横扫\n受 34 伤害·刺退眩晕 1.5 秒", "effect": {"kind": "smite", "dmg": 34.0, "stun": 1.5, "slow": 0.5, "slow_dur": 2.0}},
	# ---- 第8关 东昌府·飞石没羽箭：张清（飞石由关卡逻辑驱动，被招安后玩家可用）----
	"zhang_stone": {"name": "飞石打将", "cd": 6.0, "targeted": true, "radius": 50.0, "color": Color("cfd6dd"),
		"desc": "没羽箭飞石专打敌将\n命中 50 伤害并打落马下（重眩）", "effect": {"kind": "smite", "dmg": 50.0, "slow": 0.08, "slow_dur": 1.6}},

	# ---- 自由模式·英雄技能组（每英雄 3 主动 + 1 被动；伤害随技能等级缩放）----
	# 宋江：指挥支援
	"song_haste": {"name": "神行号令", "cd": 8.0, "cd_ranks": [12.0, 10.0, 8.0], "targeted": false, "radius": 190.0, "color": Color("9ce0a0"),
		"desc": "周围梁山兵\n移速+45%（7秒）·升级缩短冷却", "effect": {"kind": "haste", "speed_mult": 1.45, "dur": 7.0}},
	"song_fire": {"name": "火攻连营", "cd": 11.0, "targeted": true, "weak_global": true, "radius": 100.0, "color": Color("ff7a2a"),
		"desc": "指定处腾起烈焰\n地面每秒 20 灼伤，持续 5/8/10 秒(随等级)",
		"effect": {"kind": "fire_dot", "dps": 20.0, "dur_ranks": [5.0, 8.0, 10.0], "dmg": 100.0, "dur": 5.0}},
	"song_lead": {"name": "替天行道·仁义", "passive": true, "cd": 25.0, "targeted": false, "radius": 0.0, "color": Color("ffd24a"),
		"desc": "被动·仁义之名：攻击+/生命+/自身回血\n主动·号令众将：所有友方英雄回血(=Q回血量)，宋江 Q 转入冷却",
		"effect": {"kind": "passive", "atk_add": 3.0, "hp_add": 50.0, "regen": 3.0, "active_kind": "rally_heroes"}},
	# 林冲：近战突击
	"lin_charge": {"name": "豹影冲锋", "cd": 7.0, "targeted": false, "radius": 92.0, "color": Color("e0a24a"),
		"desc": "豹影突进：身边官军\n受 {v} 伤害减速；自身攻击+40%（5秒）", "effect": {"kind": "smite", "dmg": 23.0, "slow": 0.6, "slow_dur": 1.5, "self_atk": 1.4, "self_dur": 5.0}},
	"lin_storm": {"name": "横扫千军", "cd": 11.0, "targeted": false, "radius": 122.0, "color": Color("7fb0ff"),
		"desc": "大范围横扫·震地\n官军受 {v} 伤害并眩晕 3 秒", "effect": {"kind": "smite", "dmg": 25.0, "stun": 3.0}},
	"lin_drill": {"name": "禁军教头", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("c0a0ff"),
		"desc": "被动·枪法精进\n攻击+，更克骑兵", "effect": {"kind": "passive", "atk_add": 4.0, "bonus_cav": 1.0}},
	# 花荣：神射
	"hua_rain": {"name": "箭雨", "cd": 10.0, "targeted": true, "weak_global": true, "radius": 100.0, "color": Color("a0e8c0"),
		"desc": "箭雨覆盖：一次 {v} 伤害\n箭簇钉地再灼 3 秒（一级每秒 7）",
		"effect": {"kind": "smite", "dmg": 28.0, "dot_total": 21.0, "dot_dur": 3.0}},
	"hua_pin": {"name": "定身神箭", "cd": 9.0, "targeted": true, "weak_global": true, "radius": 55.0, "color": Color("8fd3ff"),
		"desc": "钉住目标处官军\n{v} 伤害 + 重减速", "effect": {"kind": "smite", "dmg": 44.0, "slow": 0.2, "slow_dur": 3.5}},
	"hua_eye": {"name": "小李广", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("a0e8c0"),
		"desc": "被动·神射\n攻击+、射程+", "effect": {"kind": "passive", "atk_add": 3.0, "range_add": 30.0}},
	"hua_blade": {"name": "拔刀·换刀", "cd": 1.5, "targeted": false, "radius": 0.0, "color": Color("cdd6df"),
		"desc": "大招·拔刀近战 +10%吸血\n再按挂弓远射（默认远程）", "effect": {"kind": "weapon_toggle"}},
	# 李逵：狂战
	"li_whirl": {"name": "黑旋风", "cd": 7.0, "targeted": false, "radius": 110.0, "color": Color("ff5544"),
		"desc": "旋身狂砍·刀旋如风\n身边官军受 {v} 伤害", "effect": {"kind": "smite", "dmg": 28.0, "self_atk": 1.3, "self_dur": 4.0}},
	"li_rage": {"name": "嗜血狂斩", "cd": 8.0, "targeted": false, "radius": 95.0, "color": Color("ff3322"),
		"desc": "血溅四方：身边官军受 {v} 伤害\n自身嗜血回血（6秒）", "effect": {"kind": "smite", "dmg": 23.0, "self_atk": 1.3, "self_dur": 6.0, "self_lifesteal": 0.5, "self_lifesteal_dur": 6.0}},
	"li_brawn": {"name": "蛮力", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("ff7766"),
		"desc": "被动·黑铁筋骨\n生命+、攻击吸血", "effect": {"kind": "passive", "hp_add": 120.0, "lifesteal": 0.15, "atk_add": 2.0}},

	# ===== DOTA 式英雄技能改版（林冲/花荣/李逵）=====
	# 林冲 Q·丈八枪破阵：朝指向猛刺一记长矛波，贯穿前方矩形区域
	"lin_thrust": {"name": "丈八·破阵突刺", "cd": 8.0, "targeted": true, "radius": 260.0, "color": Color("c0a0ff"),
		"desc": "丈八蛇矛朝指向猛刺\n前方扇形区内官军受 {v} 伤害并减速",
		"effect": {"kind": "sector_nuke", "dmg": 42.0, "range": 260.0, "arc": 70.0, "slow": 0.5, "slow_dur": 1.6}},
	# 林冲 E·禁军教头·猎杀（被动）：更克骑兵，且打骑兵 30% 概率吸血 80%
	"lin_predator": {"name": "禁军教头·猎骑", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("c8e0ff"),
		"desc": "被动·专破马军\n克骑兵伤害↑；击中骑兵 35% 几率\n按 30%/40%/50% 伤害吸血（随等级）",
		"effect": {"kind": "passive", "atk_add": 3.0, "bonus_cav": 1.5, "cav_ls_chance": 0.35, "cav_ls_frac_ranks": [0.30, 0.40, 0.50]}},
	# 林冲 R·时空封印（虚空大）：范围内时间停滞，敌军定身 10 秒
	"lin_chrono": {"name": "时空封印", "cd": 40.0, "targeted": true, "radius": 200.0, "color": Color("a070ff"),
		"desc": "撕裂时空：指定处结成封印立场\n域内官军时间停滞 10 秒（封印范围随等级扩大）",
		"effect": {"kind": "chrono", "dur": 10.0, "radius_ranks": [130.0, 165.0, 200.0]}},
	# 花荣 Q·凌空闪：射出穿云箭，沿途伤害，花荣闪现到箭矢落点
	"hua_blink": {"name": "凌空闪·穿云箭", "cd": 9.0, "targeted": true, "radius": 330.0, "color": Color("a0e8c0"),
		"desc": "闪现至落点：沿 A→B 一线\n带状范围内官军受 {v} 伤害",
		"effect": {"kind": "blink_shot", "dmg": 38.0, "len": 330.0, "width": 72.0}},
	# 李逵 Q·双斧回旋：两柄板斧绕身旋飞，持续扫伤减速
	"li_axes": {"name": "双斧回旋", "cd": 9.0, "targeted": false, "radius": 120.0, "color": Color("ff7744"),
		"desc": "两柄板斧绕身旋飞 3 秒\n身边官军反复受 {v} 伤害并被减速",
		"effect": {"kind": "orbit_axes", "dmg": 16.0, "slow": 0.5, "slow_dur": 1.0, "dur": 3.0, "tick": 0.5}},
	# 李逵 W·莽撞冲锋（矢量·单击方向）：原地蓄力 1 秒，朝指向猛冲，撞伤沿途
	"li_charge": {"name": "莽撞冲锋", "cd": 11.0, "targeted": true, "radius": 210.0, "color": Color("ff9a3a"),
		"desc": "选定方向蓄力 1 秒后猛冲出去\n撞翻沿途官军，受 {v} 伤害并减速",
		"effect": {"kind": "charge", "dmg": 36.0, "windup": 1.0, "dist": 210.0, "width": 56.0, "slow": 0.4, "slow_dur": 1.0}},
	# 李逵 R·嗜血暴走（主动）：5 秒内 +30 攻击、150% 吸血
	"li_fury": {"name": "嗜血暴走", "cd": 25.0, "targeted": false, "radius": 0.0, "color": Color("ff2a1a"),
		"desc": "大招·黑旋风嗜血暴走\n5 秒内 攻击 +30、吸血 150%",
		"effect": {"kind": "self_buff", "atk_add": 30.0, "lifesteal": 1.5, "dur": 5.0}},

	# ===== 入云龙·公孙胜 =====
	# Q·黑雨：指定处落下一片黑雨，持续 DOT（数值 = 宋江火攻原伤害 110 的 60% = 66，持续 10 秒）
	"gong_blackrain": {"name": "黑雨", "cd": 18.0, "targeted": false, "radius": 180.0, "color": Color("6a4fb0"),
		"desc": "以己为心招来漫天黑雨随身移动\n每秒 20/22/25 黑蚀伤害·持续 6/6/8 秒(随等级)",
		"effect": {"kind": "black_rain", "follow": true, "dps_ranks": [20.0, 22.0, 25.0], "dur_ranks": [6.0, 6.0, 8.0], "dmg": 120.0, "dur": 6.0}},
	# W·冰墙：朝指向竖起一道冰墙，少量伤害并阻隔敌军移动
	"gong_icewall": {"name": "冰墙", "cd": 16.0, "targeted": true, "radius": 60.0, "color": Color("9fd8ff"),
		"desc": "朝指向凝出一道冰墙\n沿墙官军受 {v} 伤害减速，墙体阻断去路 5 秒",
		"effect": {"kind": "ice_wall", "dmg": 20.0, "range": 175.0, "len": 150.0, "dur": 5.0}},
	# E·罡风减速（被动光环）：附近敌军移速降低，10%/20%/30% 随等级
	"gong_slow": {"name": "罡风·减速光环", "passive": true, "cd": 0.0, "targeted": false, "radius": 165.0, "color": Color("8fd3ff"),
		"desc": "被动·罡风缠身\n附近官军移速 −10%/−20%/−30%（随等级）",
		"effect": {"kind": "slow_aura", "slow": 0.10}},
	# R·画龙点睛：召唤一条金龙参战（血/攻同公孙胜），持续 10 秒
	"gong_dragon": {"name": "画龙点睛", "cd": 25.0, "targeted": false, "radius": 0.0, "color": Color("ffd24a"),
		"desc": "大招·点睛唤龙\n召一条远程吐火金龙助战（血/攻为本体 100%/150%/200%）\n吐火带小范围溅射·持续 10 秒",
		"effect": {"kind": "summon", "unit": "dragon_summon", "count": 1, "summon_kind": "dragon", "copy_caster": true,
			"copy_mult": [1.0, 1.5, 2.0], "dur": 10.0}},

	# ===== 行者·武松 =====
	# Q·驱使猛虎：召出两只猛虎（血/攻为骑兵基准的 70%/100%/130%，硬编码）
	"wu_tigers": {"name": "驱使猛虎", "cd": 22.0, "targeted": false, "radius": 0.0, "color": Color("e8a23c"),
		"desc": "啸聚山林·唤出两只猛虎助战\n血/攻随等级 70%/100%/130%",
		"effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "tiger",
			"hp": [105.0, 150.0, 195.0], "atk": [11.0, 15.0, 20.0]}},
	# W·三碗不过岗：饮酒，移动/攻速随机波动 30 秒
	"wu_wine": {"name": "三碗不过岗", "cd": 50.0, "targeted": false, "radius": 0.0, "color": Color("ffcf66"),
		"desc": "大碗饮酒·醉态飘忽\n30 秒内移动/攻速随机起落（随等级浮动更大）",
		"effect": {"kind": "drunk_buff", "lo": [0.9, 0.7, 0.7], "hi": [1.3, 1.5, 1.8], "dur": 30.0}},
	# E·双镔铁戒刀：横扫周围少量伤害并削甲 2/4/6
	"wu_blades": {"name": "双镔铁戒刀", "cd": 10.0, "targeted": false, "radius": 110.0, "color": Color("cdd6df"),
		"desc": "双刀横扫·周围官军受 {v} 伤害\n削甲 2/4/6 并致盲 3 秒（攻击必失）",
		"effect": {"kind": "smite", "dmg": 36.0, "def_down": [2.0, 4.0, 6.0], "def_down_dur": 8.0, "blind": 3.0}},
	# R·醉神大闹快活林：物理免疫 20 秒，每击 +10/20/30 攻，结束把所受物理伤害 50% 转血
	"wu_drunkgod": {"name": "醉神大闹快活林", "cd": 50.0, "targeted": false, "radius": 0.0, "color": Color("ffce4a"),
		"desc": "大招·醉神附体\n20 秒物理免疫，每击 +10/20/30 攻\n结束时所受物理伤害 50% 转为回血",
		"effect": {"kind": "drunk_god", "bonus": [10.0, 20.0, 30.0], "dur": 20.0}},

	# ===== 驻守战·官军地方大将 技能（敌方用；全部复用现有 effect kind，名号官军化）=====
	"jd_lance": {"name": "节度横扫", "cd": 9.0, "targeted": false, "radius": 118.0, "color": Color("d0a050"),
		"desc": "（敌）节度使挥兵横扫\n身边梁山兵受 {v} 伤害并被震退眩晕",
		"effect": {"kind": "smite", "dmg": 30.0, "stun": 1.4, "slow": 0.5, "slow_dur": 2.0}},
	"jd_charge": {"name": "策马踏阵", "cd": 9.0, "targeted": false, "radius": 110.0, "color": Color("ff9a3a"),
		"desc": "（敌）大将策马踏阵\n身边梁山兵受 {v} 伤害减速，自身攻势大涨",
		"effect": {"kind": "smite", "dmg": 26.0, "slow": 0.45, "slow_dur": 1.6, "self_atk": 1.4, "self_dur": 5.0}},
	"tong_drums": {"name": "童贯督战", "cd": 16.0, "targeted": false, "radius": 220.0, "color": Color("ffd24a"),
		"desc": "（敌）枢密使擂鼓督战\n周围官军回血 50、攻击 +60%（9 秒）",
		"effect": {"kind": "rally", "heal": 50.0, "atk_mult": 1.6, "dur": 9.0}},
	"ling_cannon": {"name": "轰天雷·火炮", "cd": 12.0, "targeted": true, "radius": 120.0, "color": Color("ff7a2a"),
		"desc": "（敌）凌振火炮轰击\n指定处炸开烈焰，每秒 28 灼伤·持续 5 秒",
		"effect": {"kind": "fire_dot", "dps": 28.0, "dur": 5.0, "dmg": 140.0}},
	"wei_fire": {"name": "神火·焚天", "cd": 13.0, "targeted": true, "radius": 105.0, "color": Color("ff5522"),
		"desc": "（敌）神火将魏定国布火阵\n指定处腾起神火，每秒 24 灼伤·持续 6 秒",
		"effect": {"kind": "fire_dot", "dps": 24.0, "dur": 6.0, "dmg": 144.0}},
	"shan_flood": {"name": "圣水·水淹", "cd": 11.0, "targeted": true, "radius": 110.0, "color": Color("5fbfe0"),
		"desc": "（敌）圣水将单廷圭引水倒灌\n指定处官军受 {v} 伤害并陷泥重减速",
		"effect": {"kind": "smite", "dmg": 36.0, "slow": 0.3, "slow_dur": 4.0}},
	"jd_valor": {"name": "宿将之威", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("d0a060"),
		"desc": "（敌）被动·宿将之威\n久经沙场，生命 +、攻击 +",
		"effect": {"kind": "passive", "atk_add": 4.0, "hp_add": 90.0}},
}


# 科技升级（在建筑里研究，完成后给玩家全局加成；每项一次）
const TECHS := {
	"tech_weapon": {"name": "锻造·利刃", "cost_gold": 130, "cost_wood": 60, "time": 30.0,
		"desc": "全军攻击 +20%", "effect": {"atk_mult": 1.2}},
	"tech_armor": {"name": "甲胄·坚铠", "cost_gold": 100, "cost_wood": 110, "time": 30.0,
		"desc": "全军生命 +25%", "effect": {"hp_mult": 1.25}},
	"tech_gather": {"name": "精耕·钱粮", "cost_gold": 80, "cost_wood": 80, "time": 24.0,
		"desc": "采集效率 +30%", "effect": {"gather_mult": 1.3}},
	# 时代进阶（聚义厅研究，单向）：解锁后期单位/建筑并给全军加成
	"tech_age2": {"name": "聚义·壮大", "cost_gold": 200, "cost_wood": 120, "time": 40.0,
		"desc": "进「聚义」时代：解锁英雄/马军/箭楼/集市，全军生命 +10%", "effect": {"advance_age": 2, "hp_mult": 1.1}},
	"tech_age3": {"name": "替天行道·鼎盛", "cost_gold": 350, "cost_wood": 220, "time": 55.0, "min_age": 2,
		"desc": "进「替天行道」时代：解锁攻城作坊/撞车，全军攻击 +10%", "effect": {"advance_age": 3, "atk_mult": 1.1}},
}


static func get_unit(key: String) -> Dictionary:
	return UNITS.get(key, {})


# 内容包：把 res://content/units.json、abilities.json 合并进本场的 defs/abilities。
# 字段级覆盖（改某单位的 hp）或整条新增（加全新单位/技能）。无文件 = 不变（向后兼容）。
# 由 Battle 在复制 _defs/_abilities 之后、spawn 之前调用一次。换皮/加内容无需改本表。
const CONTENT_DIR := "res://content"

static func apply_content_pack(defs: Dictionary, abilities: Dictionary) -> void:
	_merge_json(CONTENT_DIR + "/units.json", defs)
	_merge_json(CONTENT_DIR + "/abilities.json", abilities)

static func _merge_json(path: String, into: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	merge_into(into, JSON.parse_string(FileAccess.get_file_as_string(path)))

## 把 overrides 合并进 into（字段级覆盖 / 整条新增）。嵌套值深拷贝——
## 这样战斗里改 _defs 不会污染来源(如场景 JSON、内容包)。场景编辑器的单位/技能 override 也走它。
static func merge_into(into: Dictionary, overrides) -> void:
	if not (overrides is Dictionary):
		return
	for k in overrides:
		var v = overrides[k]
		if into.has(k) and into[k] is Dictionary and v is Dictionary:
			for f in v:
				var fv = v[f]
				into[k][f] = (fv.duplicate(true) if (fv is Dictionary or fv is Array) else fv)
		else:
			into[k] = (v.duplicate(true) if (v is Dictionary or v is Array) else v)


# 护甲值（defense）总表：每点 −约5% 普攻伤害。所有 64 个战斗单位/英雄均非 0（逐一审查定值，
# 镜像单位对称、boss 最硬 8、弓手/工人最脆 1）。未列入者按角色兜底（armor_for）。建筑/资源/非战斗=0。
const ARMOR := {
	"song_jiang": 6, "wu_yong": 4, "lin_chong": 7, "hua_rong": 5, "liang_dao": 3, "liang_qiang": 3,
	"liang_gong": 1, "guan_dao": 3, "guan_gong": 1, "guan_qi": 4, "gao_qiu": 8, "tiger_summon": 3,
	"dragon_summon": 2, "chao_gai": 6, "gongsun_sheng": 4, "liu_tang": 5, "ruan_brother": 2, "bai_sheng": 1,
	"yang_zhi": 7, "yu_hou": 2, "jun_han": 2, "li_kui": 6, "dai_zong": 4, "zhang_shun": 4,
	"yan_shun": 4, "guan_zhanzi": 2, "siege_cata": 1, "siege_ram": 5, "guan_laozi": 2, "cai_jiu": 5, "shi_xiu": 5,
	"zhu_long": 6, "zhu_hu": 6, "zhu_biao": 4, "luan_tingyu": 7, "zhu_zhaofeng": 4, "hu_sanniang": 5,
	"zhu_keke": 2, "zhu_gong": 1, "zhu_qi": 4, "lian_huan_ma": 5, "gou_lian": 3, "xu_ning": 5,
	"hu_yanzhuo": 8, "tang_long": 3, "han_tao": 5, "peng_qi": 5, "guan_zhanchuan": 2, "guan_jingqi": 4,
	"lu_zhishen": 7, "dong_chao": 3, "xue_ba": 3, "lu_qian": 4, "gong_ren": 2, "wu_song": 6,
	"shi_en": 4, "jiang_menshen": 8, "jiang_thug": 2, "zhang_tuanlian": 5, "zhang_qing": 6, "gong_wang": 5,
	"ding_desun": 4, "shi_wengong": 8, "lou_luo": 1, "liang_ma": 4,
	# 驻守战新增·兵种 + 官军大将
	"guan_musket": 2, "guan_bomber": 2, "war_elephant": 8, "camel_rider": 4,
	"wang_huan": 8, "xu_jing": 7, "wang_wende": 7, "mei_zhan": 7, "zhang_kai": 5,
	"yang_wen": 7, "li_congji": 7, "xiang_yuanzhen": 5, "jing_zhong": 7, "duan_pengju": 7,
	"tong_guan": 8, "ling_zhen": 4, "wei_dingguo": 5, "shan_tinggui": 6, "wen_da": 8,
}


## 取单位护甲：def 内显式 defense 优先 → ARMOR 表 → 按角色兜底（保证战斗单位非 0）。
static func armor_for(key: String, def: Dictionary) -> float:
	if def.has("defense"):
		return float(def["defense"])
	if ARMOR.has(key):
		return float(ARMOR[key])
	if bool(def.get("building", false)) or bool(def.get("is_resource", false)) \
			or bool(def.get("noncombat", false)) or bool(def.get("captive", false)) or bool(def.get("objective", false)):
		return 0.0
	if float(def.get("atk", 0)) <= 0.0:
		return 0.0
	if bool(def.get("hero", false)):
		return 5.0
	if bool(def.get("cavalry", false)):
		return 4.0
	if bool(def.get("ranged", false)):
		return 1.0
	if float(def.get("bonus_cav", 1.0)) > 1.0:
		return 3.0
	return 3.0


## 技能说明按当前等级缩放主数值：把描述里的 {v} 占位符替换为 base*(0.6+0.4*rank)
## ——与 Battle._do_ability 的 sc 一致（伤害/回血随技能等级放大）。rank<=0 按 1 级预览。
static func ability_desc(aid: String, rank: int) -> String:
	var ad: Dictionary = ABILITIES.get(aid, {})
	var desc := String(ad.get("desc", ""))
	if desc.find("{v}") == -1:
		return desc
	var eff: Dictionary = ad.get("effect", {})
	var base := float(eff.get("dmg", eff.get("heal", 0.0)))
	var sc := 0.6 + 0.4 * float(maxi(rank, 1))
	return desc.replace("{v}", str(int(round(base * sc))))


## 图鉴用：技能 1/2/3 级主数值速览。主动伤害/回血 ×(0.6+0.4·级)；被动加成 ×级；特殊字段单列。
static func _fmtn(v: float) -> String:
	return str(int(round(v)))


static func _l3a(base: float) -> String:   # 主动：×1.0 / ×1.4 / ×1.8
	return "%s/%s/%s" % [_fmtn(base), _fmtn(base * 1.4), _fmtn(base * 1.8)]


static func _l3p(base: float) -> String:   # 被动：×1 / ×2 / ×3
	return "%s/%s/%s" % [_fmtn(base), _fmtn(base * 2.0), _fmtn(base * 3.0)]


static func ability_levels(aid: String) -> String:
	var ad: Dictionary = ABILITIES.get(aid, {})
	if ad.is_empty():
		return ""
	var eff: Dictionary = ad.get("effect", {})
	var kind := String(eff.get("kind", ""))
	var extra := ""
	if eff.has("dot_total"):
		extra += "　续 %ss 共 %s" % [str(eff.get("dot_dur", 3.0)), _l3a(float(eff["dot_total"]))]
	if eff.has("def_down"):
		var dd: Array = eff["def_down"]
		extra += "　削甲 %d/%d/%d" % [int(dd[0]), int(dd[1]), int(dd[2])]
	if eff.has("blind"):
		extra += "　致盲 %ss(攻击必失)" % str(eff["blind"])
	match kind:
		"passive":
			var ps := ""
			if float(eff.get("atk_add", 0.0)) > 0.0: ps += "攻+%s　" % _l3p(float(eff["atk_add"]))
			if float(eff.get("hp_add", 0.0)) > 0.0: ps += "血+%s　" % _l3p(float(eff["hp_add"]))
			if float(eff.get("range_add", 0.0)) > 0.0: ps += "射程+%s　" % _l3p(float(eff["range_add"]))
			if float(eff.get("regen", 0.0)) > 0.0: ps += "回血+%s/s　" % _l3p(float(eff["regen"]))
			if float(eff.get("bonus_cav", 0.0)) > 0.0: ps += "克骑加成+%.1f/%.1f/%.1f　" % [float(eff["bonus_cav"]), float(eff["bonus_cav"]) * 2.0, float(eff["bonus_cav"]) * 3.0]
			if float(eff.get("lifesteal", 0.0)) > 0.0: ps += "吸血%d%%(固定)　" % int(float(eff["lifesteal"]) * 100.0)
			var fr: Array = eff.get("cav_ls_frac_ranks", [])
			if fr.size() == 3:
				ps += "打骑%d%%几率吸血%d/%d/%d%%" % [int(float(eff.get("cav_ls_chance", 0.0)) * 100.0), int(float(fr[0]) * 100.0), int(float(fr[1]) * 100.0), int(float(fr[2]) * 100.0)]
			return ps.strip_edges()
		"slow_aura":
			var b := float(eff.get("slow", 0.1))
			return "敌移速 −%d/−%d/−%d%%" % [int(b * 100.0), int(b * 200.0), int(b * 300.0)]
		"rally":
			return "回血 %s　攻×%s/%ss(固定)" % [_l3a(float(eff.get("heal", 0.0))), str(eff.get("atk_mult", 1.0)), str(eff.get("dur", 8.0))]
		"haste":
			return "移速+%d%% / %ss(固定)" % [int(round((float(eff.get("speed_mult", 1.0)) - 1.0) * 100.0)), str(eff.get("dur", 7.0))]
		"debuff":
			return "减速%d%%+降攻 / %ss(固定)" % [int(float(eff.get("slow", 0.0)) * 100.0), str(eff.get("dur", 0.0))]
		"chrono":
			if eff.has("radius_ranks"):
				var rr: Array = eff["radius_ranks"]
				return "定身%ss · 范围 %d/%d/%d" % [str(eff.get("dur", 10.0)), int(rr[0]), int(rr[1]), int(rr[2])]
			return "定身 %ss(固定)" % str(eff.get("dur", 10.0))
		"self_buff":
			return "攻+%s　吸血%d%%/%ss(固定)" % [_l3a(float(eff.get("atk_add", 0.0))), int(float(eff.get("lifesteal", 0.0)) * 100.0), str(eff.get("dur", 5.0))]
		"orbit_axes":
			return "每跳 %s ×%ss" % [_l3a(float(eff.get("dmg", 0.0))), str(eff.get("dur", 3.0))]
		"drag":
			return "拖入水 %s" % _l3a(float(eff.get("dmg", 0.0)))
		"fire_dot", "black_rain":
			# 每秒伤害(dps 固定 / dps_ranks 随等级) · 持续(dur_ranks 随等级)
			var dps_s := ""
			if eff.has("dps_ranks"):
				var dr: Array = eff["dps_ranks"]
				dps_s = "%d/%d/%d" % [int(dr[0]), int(dr[1]), int(dr[2])]
			elif eff.has("dps"):
				dps_s = "%d" % int(float(eff["dps"]))
			if dps_s != "":
				var dur_s := "%ss(固定)" % str(eff.get("dur", 5.0))
				if eff.has("dur_ranks"):
					var du: Array = eff["dur_ranks"]
					dur_s = "%d/%d/%ds" % [int(du[0]), int(du[1]), int(du[2])]
				return "每秒 %s · 持续 %s" % [dps_s, dur_s]
			return "%ss累计 %s" % [str(eff.get("dur", 5.0)), _l3a(float(eff.get("dmg", 0.0)))]
		"ice_wall":
			return "墙伤 %s　阻挡%ss%s" % [_l3a(float(eff.get("dmg", 0.0))), str(eff.get("dur", 5.0)), extra]
		"weapon_toggle":
			return "切近战/远程·近战吸血/击 20-40/30-50/40-60%"
		"drunk_buff":
			var lo: Array = eff.get("lo", [0.9, 0.7, 0.7])
			var hi: Array = eff.get("hi", [1.3, 1.5, 1.8])
			return "移/攻速随机 ×%.1f~%.1f / ×%.1f~%.1f / ×%.1f~%.1f　%ss" % [float(lo[0]), float(hi[0]), float(lo[1]), float(hi[1]), float(lo[2]), float(hi[2]), str(eff.get("dur", 30.0))]
		"drunk_god":
			var bo: Array = eff.get("bonus", [10.0, 20.0, 30.0])
			return "物免%ss·每击+%d/%d/%d攻·结束伤害50%%转血" % [str(eff.get("dur", 20.0)), int(bo[0]), int(bo[1]), int(bo[2])]
		"summon":
			if bool(eff.get("copy_caster", false)):
				var mtxt := "血/攻同本体"
				if eff.has("copy_mult"):
					var cm: Array = eff["copy_mult"]
					mtxt = "血/攻=本体%d/%d/%d%%" % [int(float(cm[0]) * 100.0), int(float(cm[1]) * 100.0), int(float(cm[2]) * 100.0)]
				var dtxt := "%ds" % int(float(eff.get("dur", 10.0)))
				if eff.has("dur_ranks"):
					var dr: Array = eff["dur_ranks"]
					dtxt = "%d/%d/%ds" % [int(dr[0]), int(dr[1]), int(dr[2])]
				return "召%d只·%s·持续%s" % [int(eff.get("count", 1)), mtxt, dtxt]
			var hp: Array = eff.get("hp", [])
			var atk: Array = eff.get("atk", [])
			var hs := ""
			for x in hp: hs += ("/" if hs != "" else "") + str(int(x))
			var ats := ""
			for x in atk: ats += ("/" if ats != "" else "") + str(int(x))
			return "召%d只·血%s·攻%s" % [int(eff.get("count", 1)), hs, ats]
		_:
			if eff.has("dmg"):
				return "伤害 %s%s" % [_l3a(float(eff["dmg"])), extra]
			return extra.strip_edges()
