class_name Defs
## 全战役单位与技能中央注册表。关卡按 key 引用；技能用数据化 effect 描述，
## 由 Battle._do_ability 统一结算，无需为每个技能写分支。

# 单位定义。字段：name,hp,atk,cd(出手间隔),range(像素),speed,
# ranged,cavalry,hero,bonus_cav,aura("atk"/"speed"),aura_r,aura_p,building,ability,radius,
# 以及关卡用标签：objective/captive/noncombat/scout/porter/elite_guard。
const UNITS := {
	# ---- 通用troops / 梁山主将（第5关及复用） ----
	"song_jiang": {"name": "宋江", "hp": 280, "atk": 18, "cd": 0.9, "range": 26, "speed": 78,
		"hero": true, "aura": "atk", "aura_r": 210, "aura_p": 1.25, "radius": 13, "ability": "song_rally",
		"abilities": ["song_rally", "song_banner", "song_fire", "song_lead"],
		"hero_trainable": true, "pop": 3, "cost_gold": 160, "cost_wood": 40, "train_time": 38.0, "trained_at": "hall", "min_age": 1, "dota": "Omniknight"},
	"wu_yong": {"name": "吴用", "hp": 150, "atk": 11, "cd": 1.2, "range": 200, "speed": 78,
		"ranged": true, "hero": true, "aura": "speed", "aura_r": 170, "aura_p": 1.15, "radius": 12, "ability": "wu_fire", "abilities": ["wu_yong_q", "wu_yong_w", "wu_yong_e", "wu_yong_r"], "dota": "Puck", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"lin_chong": {"name": "林冲", "hp": 320, "atk": 24, "cd": 0.8, "range": 30, "speed": 88,
		"hero": true, "bonus_cav": 1.0, "radius": 13, "ability": "lin_sweep",
		"abilities": ["lin_thrust", "lin_sweep", "lin_predator", "lin_chrono"],
		"hero_trainable": true, "pop": 3, "cost_gold": 156, "cost_wood": 32, "train_time": 38.0, "trained_at": "hall", "min_age": 1, "dota": "Faceless Void"},
	"hua_rong": {"name": "花荣", "hp": 180, "atk": 16, "cd": 0.9, "range": 230, "speed": 82,
		"ranged": true, "hero": true, "radius": 12, "ability": "hua_shot",
		"abilities": ["hua_blink", "hua_rain", "hua_pin", "hua_blade"],
		"hero_trainable": true, "pop": 3, "cost_gold": 152, "cost_wood": 44, "train_time": 36.0, "trained_at": "hall", "min_age": 1, "dota": "Sniper"},
	# 兵种价 2026-07 rebalance：英雄(150-200金)战力远超同价兵堆 → 全线降兵价约 35% 对齐性价比；
	# 攻城械(后期兵)改以木为主，给后期积压的木头一个刚性去向。英雄价与复活价保持不动。
	"liang_dao": {"name": "朴刀手", "hp": 110, "atk": 12, "cd": 1.0, "range": 24, "speed": 72,
		"pop": 1, "cost_gold": 25, "cost_wood": 8, "train_time": 16.0, "trained_at": "barracks"},
	"liang_qiang": {"name": "长枪手", "hp": 115, "atk": 10, "cd": 1.1, "range": 30, "speed": 66, "bonus_cav": 2.2,
		"pop": 1, "cost_gold": 24, "cost_wood": 14, "train_time": 17.0, "trained_at": "barracks"},
	"liang_gong": {"name": "弓手", "hp": 65, "atk": 10, "cd": 1.4, "range": 185, "speed": 74, "ranged": true, "radius": 10,
		"pop": 1, "cost_gold": 24, "cost_wood": 14, "train_time": 16.0, "trained_at": "barracks"},
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
		"hero_trainable": true, "pop": 3, "cost_gold": 168, "cost_wood": 56, "train_time": 40.0, "trained_at": "hall", "min_age": 1, "dota": "Invoker"},
	"liu_tang": {"name": "刘唐", "hp": 210, "atk": 22, "cd": 0.8, "range": 26, "speed": 86, "hero": true, "radius": 13, "ability": "liu_cleave", "abilities": ["liu_tang_q", "liu_tang_w", "liu_tang_e", "liu_tang_r"], "dota": "Bloodseeker", "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"ruan_brother": {"name": "阮氏好汉", "hp": 130, "atk": 14, "cd": 0.9, "range": 26, "speed": 92, "radius": 11, "abilities": ["ruan_brother_q", "ruan_brother_w", "ruan_brother_e", "ruan_brother_r"], "dota": "Morphling", "hero_trainable": true, "pop": 3, "cost_gold": 188, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"bai_sheng": {"name": "白胜", "hp": 70, "atk": 8, "cd": 1.1, "range": 24, "speed": 96, "radius": 10, "scout": true, "ability": "bai_drug", "abilities": ["bai_sheng_q", "bai_sheng_w", "bai_sheng_e", "bai_sheng_r"], "dota": "Hoodwink", "hero_trainable": true, "pop": 3, "cost_gold": 165, "cost_wood": 30, "train_time": 38, "trained_at": "hall", "min_age": 1},
	"yang_zhi": {"name": "杨志", "hp": 360, "atk": 23, "cd": 0.8, "range": 30, "speed": 90, "hero": true, "radius": 14, "elite_guard": true, "abilities": ["yang_zhi_q", "yang_zhi_w", "yang_zhi_e", "yang_zhi_r"], "dota": "Slardar", "hero_trainable": true, "pop": 3, "cost_gold": 170, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"yu_hou": {"name": "虞候", "hp": 95, "atk": 11, "cd": 1.0, "range": 26, "speed": 70, "radius": 11},
	"jun_han": {"name": "军汉", "hp": 80, "atk": 9, "cd": 1.1, "range": 24, "speed": 64, "radius": 10, "porter": true},
	"lao_duguan": {"name": "老都管", "hp": 70, "atk": 4, "cd": 1.4, "range": 24, "speed": 58, "radius": 10, "noncombat": true},
	"treasure_cart": {"name": "生辰纲宝车", "hp": 900, "atk": 0, "building": true, "radius": 20, "objective": true},

	# ---- 第2关 江州劫法场 ----
	"li_kui": {"name": "李逵", "hp": 320, "atk": 21, "cd": 0.75, "range": 28, "speed": 80, "hero": true, "radius": 13, "ability": "li_berserk",
		"abilities": ["li_axes", "li_charge", "li_brawn", "li_fury"],
		"hero_trainable": true, "pop": 3, "cost_gold": 148, "cost_wood": 24, "train_time": 36.0, "trained_at": "hall", "min_age": 1, "dota": "Lifestealer"},
	"dai_zong": {"name": "戴宗", "hp": 200, "atk": 15, "cd": 0.9, "range": 26, "speed": 150,
		"hero": true, "aura": "speed", "aura_r": 180, "aura_p": 1.15, "radius": 12, "ability": "dai_dash", "abilities": ["dai_zong_q", "dai_zong_w", "dai_zong_e", "dai_zong_r"], "dota": "Spirit Breaker", "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"zhang_shun": {"name": "张顺", "hp": 210, "atk": 16, "cd": 0.85, "range": 26, "speed": 88, "hero": true, "radius": 12, "ability": "zhang_drag", "abilities": ["zhang_shun_q", "zhang_shun_w", "zhang_shun_e", "zhang_shun_r"], "dota": "Slark", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"yan_shun": {"name": "燕顺", "hp": 190, "atk": 16, "cd": 0.85, "range": 28, "speed": 78, "hero": true, "radius": 12, "abilities": ["yan_shun_q", "yan_shun_w", "yan_shun_e", "yan_shun_r"], "dota": "Lycan", "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"guan_zhanzi": {"name": "刽子手", "hp": 130, "atk": 14, "cd": 1.1, "range": 26, "speed": 60, "radius": 12},
	# 攻城投石车：射程很远、移速慢；对箭楼 ×3 伤害(仅箭楼，其余建筑/单位无加成)，约 5 下拆一座箭楼。
	"siege_cata": {"name": "投石车", "hp": 260, "atk": 47, "cd": 3.0, "range": 280, "speed": 32, "ranged": true,
		"radius": 16, "vs_tower": 3.0, "vs_hero": 0.3, "xp": 30.0,
		"pop": 3, "cost_gold": 100, "cost_wood": 75, "train_time": 30.0, "trained_at": "siege_workshop", "min_age": 3},
	# 撞车：硬克制攻城——对一切建筑 ×8 巨伤、护甲厚抗箭，但对人只挠痒(atk低)且移速慢，必须有兵护着推。
	"siege_ram": {"name": "撞车", "hp": 380, "atk": 6, "cd": 2.0, "range": 30, "speed": 30,
		"radius": 16, "vs_building": 8.0, "vs_hero": 0.3, "xp": 26.0,
		"pop": 3, "cost_gold": 70, "cost_wood": 90, "train_time": 26.0, "trained_at": "siege_workshop", "min_age": 3},
	"guan_laozi": {"name": "江州牢子", "hp": 80, "atk": 9, "cd": 1.05, "range": 24, "speed": 62, "radius": 11},
	"cai_jiu": {"name": "蔡九知府", "hp": 260, "atk": 12, "cd": 1.0, "range": 26, "speed": 70,
		"hero": true, "aura": "atk", "aura_r": 180, "aura_p": 1.2, "radius": 13},
	"scaffold": {"name": "法场刑台", "hp": 1200, "atk": 0, "building": true, "radius": 46},
	"song_jiang_bound": {"name": "宋江", "hp": 200, "atk": 0, "building": true, "radius": 13, "captive": true},
	"dai_zong_bound": {"name": "戴宗", "hp": 150, "atk": 0, "building": true, "radius": 12, "captive": true},

	# ---- 第3关 三打祝家庄 ----
	"shi_xiu": {"name": "石秀", "hp": 230, "atk": 19, "cd": 0.85, "range": 26, "speed": 86, "hero": true, "radius": 12, "ability": "shi_xiu_path", "abilities": ["shi_xiu_q", "shi_xiu_w", "shi_xiu_e", "shi_xiu_r"], "dota": "Troll Warlord", "hero_trainable": true, "pop": 3, "cost_gold": 194, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"zhu_long": {"name": "祝龙", "hp": 1200, "atk": 51, "cd": 0.85, "range": 30, "speed": 108, "cavalry": true, "hero": true, "radius": 13},
	"zhu_hu": {"name": "祝虎", "hp": 320, "atk": 20, "cd": 0.9, "range": 28, "speed": 106, "cavalry": true,
		"hero": true, "aura": "atk", "aura_r": 180, "aura_p": 1.2, "radius": 13},
	"zhu_biao": {"name": "祝彪", "hp": 800, "atk": 39, "cd": 1.1, "range": 210, "speed": 96, "ranged": true, "hero": true, "radius": 12},
	"luan_tingyu": {"name": "栾廷玉", "hp": 1400, "atk": 56, "cd": 1.0, "range": 30, "speed": 80, "hero": true, "radius": 13, "ability": "luan_smash",
		"abilities": ["luan_smash", "guan_charge", "guan_valor", "guan_fury"]},
	"zhu_zhaofeng": {"name": "祝朝奉", "hp": 670, "atk": 28, "cd": 1.4, "range": 28, "speed": 60, "hero": true, "radius": 12},
	"hu_sanniang": {"name": "扈三娘", "hp": 420, "atk": 42, "cd": 0.8, "range": 26, "speed": 112, "cavalry": true, "hero": true, "radius": 13, "abilities": ["hu_sanniang_q", "hu_sanniang_w", "hu_sanniang_e", "hu_sanniang_r"], "dota": "Vengeful Spirit", "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"zhu_keke": {"name": "祝家庄客", "hp": 95, "atk": 11, "cd": 1.0, "range": 24, "speed": 66},
	"zhu_gong": {"name": "祝家弓手", "hp": 60, "atk": 9, "cd": 1.4, "range": 180, "speed": 64, "ranged": true, "radius": 10},
	"zhu_qi": {"name": "祝家马军", "hp": 200, "atk": 13, "cd": 1.0, "range": 26, "speed": 110, "cavalry": true, "radius": 13},
	"zhu_gate": {"name": "祝家庄门", "hp": 1600, "atk": 0, "building": true, "radius": 22},

	# ---- 第4关 大破连环马 ----
	"lian_huan_ma": {"name": "连环马", "hp": 300, "atk": 15, "cd": 1.0, "range": 26, "speed": 118, "cavalry": true, "radius": 13},
	"gou_lian": {"name": "钩镰枪手", "hp": 105, "atk": 11, "cd": 1.1, "range": 30, "speed": 68, "bonus_cav": 3.5},
	"xu_ning": {"name": "徐宁", "hp": 210, "atk": 20, "cd": 0.85, "range": 30, "speed": 80, "hero": true, "bonus_cav": 2.0, "radius": 13, "ability": "xu_drill", "abilities": ["xu_ning_q", "xu_ning_w", "xu_ning_e", "xu_ning_r"], "dota": "Magnus", "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"hu_yanzhuo": {"name": "呼延灼", "hp": 780, "atk": 53, "cd": 0.8, "range": 30, "speed": 110, "cavalry": true,
		"hero": true, "aura": "atk", "aura_r": 190, "aura_p": 1.2, "radius": 15, "ability": "hu_yanzhuo_q",
		"abilities": ["hu_yanzhuo_q", "hu_yanzhuo_w", "hu_yanzhuo_e", "hu_yanzhuo_r"], "dota": "Sven", "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 60, "train_time": 43, "trained_at": "hall", "min_age": 1},
	"tang_long": {"name": "汤隆", "hp": 160, "atk": 12, "cd": 1.2, "range": 160, "speed": 78, "ranged": true, "hero": true, "radius": 12, "abilities": ["tang_long_q", "tang_long_w", "tang_long_e", "tang_long_r"], "dota": "Timbersaw", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"han_tao": {"name": "韩滔", "hp": 450, "atk": 42, "cd": 0.9, "range": 26, "speed": 114, "cavalry": true, "hero": true, "radius": 13, "abilities": ["han_tao_q", "han_tao_w", "han_tao_e", "han_tao_r"], "dota": "Shadow Fiend", "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 54, "train_time": 44, "trained_at": "hall", "min_age": 1},
	"peng_qi": {"name": "彭玘", "hp": 450, "atk": 42, "cd": 0.9, "range": 26, "speed": 114, "cavalry": true, "hero": true, "radius": 13, "abilities": ["peng_qi_q", "peng_qi_w", "peng_qi_e", "peng_qi_r"], "dota": "Pudge", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 50, "train_time": 42, "trained_at": "hall", "min_age": 1},
	"jiangtai": {"name": "中军帅旗", "hp": 1600, "atk": 0, "building": true, "radius": 40},

	# ---- 第5关 可选增强 ----
	"guan_zhanchuan": {"name": "官军战船", "hp": 220, "atk": 14, "cd": 1.8, "range": 200, "speed": 70, "ranged": true, "radius": 16},
	"guan_jingqi": {"name": "官军精骑", "hp": 175, "atk": 16, "cd": 0.9, "range": 26, "speed": 100, "cavalry": true, "radius": 13},

	# ---- 第6关 大闹野猪林（鲁智深救林冲）----
	"lu_zhishen": {"name": "鲁智深", "hp": 540, "atk": 28, "cd": 0.78, "range": 30, "speed": 86,
		"hero": true, "radius": 14, "ability": "lu_sweep", "abilities": ["lu_zhishen_q", "lu_zhishen_w", "lu_zhishen_e", "lu_zhishen_r"], "dota": "Earthshaker", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 55, "train_time": 40, "trained_at": "hall", "min_age": 1},
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
		"hero_trainable": true, "pop": 3, "cost_gold": 160, "cost_wood": 32, "train_time": 40.0, "trained_at": "hall", "min_age": 1, "dota": "Ursa"},
	"shi_en": {"name": "施恩", "hp": 210, "atk": 15, "cd": 0.95, "range": 26, "speed": 80, "hero": true, "radius": 12, "abilities": ["shi_en_q", "shi_en_w", "shi_en_e", "shi_en_r"], "dota": "Viper", "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1},
	"jiang_menshen": {"name": "蒋门神", "hp": 1870, "atk": 53, "cd": 0.88, "range": 30, "speed": 76,
		"hero": true, "aura": "atk", "aura_r": 160, "aura_p": 1.1, "radius": 16, "ability": "jiang_smash", "elite_guard": true},
	"jiang_thug": {"name": "蒋家打手", "hp": 95, "atk": 11, "cd": 1.0, "range": 24, "speed": 66, "radius": 11},
	"zhang_tuanlian": {"name": "张团练", "hp": 1000, "atk": 42, "cd": 0.9, "range": 28, "speed": 96, "cavalry": true, "hero": true, "radius": 13},
	"tavern": {"name": "酒望", "hp": 100000, "atk": 0, "building": true, "radius": 18, "noncombat": true},
	"signboard": {"name": "蒋家招牌", "hp": 800, "atk": 0, "building": true, "radius": 20, "objective": true},

	# ---- 第8关 东昌府·飞石没羽箭（招安张清）----
	"zhang_qing": {"name": "张清", "hp": 690, "atk": 37, "cd": 1.1, "range": 235, "speed": 96,
		"ranged": true, "hero": true, "radius": 12, "ability": "zhang_stone", "abilities": ["zhang_qing_q", "zhang_qing_w", "zhang_qing_e", "zhang_qing_r"], "dota": "Mirana", "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1},
	"gong_wang": {"name": "龚旺", "hp": 315, "atk": 37, "cd": 0.9, "range": 26, "speed": 110, "cavalry": true, "hero": true, "radius": 13, "abilities": ["gong_wang_q", "gong_wang_w", "gong_wang_e", "gong_wang_r"], "dota": "Death Prophet", "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 55, "train_time": 42, "trained_at": "hall", "min_age": 1},
	"ding_desun": {"name": "丁得孙", "hp": 315, "atk": 37, "cd": 0.95, "range": 28, "speed": 80, "hero": true, "radius": 12, "abilities": ["ding_desun_q", "ding_desun_w", "ding_desun_e", "ding_desun_r"], "dota": "Huskar", "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 42, "train_time": 42, "trained_at": "hall", "min_age": 1},
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
		"cost_gold": 110, "cost_wood": 55, "build_time": 28.0,
		"produces": ["liang_dao", "liang_qiang", "liang_gong", "liang_ma"],
		"researches": ["tech_weapon", "tech_armor"]},
	"liang_ma": {"name": "梁山马军", "hp": 210, "atk": 15, "cd": 0.95, "range": 26, "speed": 112, "cavalry": true, "radius": 13,
		"pop": 2, "cost_gold": 42, "cost_wood": 30, "train_time": 22.0, "trained_at": "barracks", "min_age": 2},
	"arrow_tower": {"name": "箭楼", "hp": 700, "atk": 51, "cd": 1.3, "range": 215, "speed": 0, "ranged": true,
		"building": true, "radius": 20, "buildable": true, "build_cat": "tower", "build_order": 2, "cost_gold": 65, "cost_wood": 30, "build_time": 24.0,
		"garrison_cap": 5, "min_age": 1},
	# 霹雳炮：群伤炮塔——慢射速、落点小范围溅射（克密集小兵）。proj_kind=bomb 抛射炸弹视觉。
	"thunder_tower": {"name": "霹雳炮", "hp": 650, "atk": 66, "cd": 2.2, "range": 200, "speed": 0, "ranged": true,
		"building": true, "radius": 20, "buildable": true, "build_cat": "tower", "build_order": 7, "cost_gold": 95, "cost_wood": 45, "build_time": 26.0,
		"splash": 75.0, "proj_kind": "bomb", "min_age": 1},
	# 五雷法坛：紫雷球——优先索敌英雄、对英雄 2× 伤害（克对方大将）。
	"altar_tower": {"name": "五雷法坛", "hp": 600, "atk": 39, "cd": 1.6, "range": 235, "speed": 0, "ranged": true,
		"building": true, "radius": 20, "buildable": true, "build_cat": "tower", "build_order": 8, "cost_gold": 100, "cost_wood": 45, "build_time": 26.0,
		"proj_kind": "magic", "bonus_hero": 2.0, "target_priority": "hero", "min_age": 1},
	# 拒马（绊马坑）：控场塔——伤害很低，命中减速 ~55%/1.3s，拖住敌人挨别的塔火力。
	"caltrop_tower": {"name": "拒马", "hp": 700, "atk": 15, "cd": 1.1, "range": 180, "speed": 0, "ranged": true,
		"building": true, "radius": 20, "buildable": true, "build_cat": "tower", "build_order": 9, "cost_gold": 60, "cost_wood": 30, "build_time": 20.0,
		"slow_mult": 0.45, "slow_dur": 1.3, "min_age": 1},
	"house": {"name": "民居", "hp": 480, "atk": 0, "building": true, "radius": 20, "buildable": true, "build_order": 3,
		"cost_gold": 0, "cost_wood": 40, "build_time": 16.0, "provides_pop": 10},
	"depot": {"name": "仓库", "hp": 560, "atk": 0, "building": true, "radius": 20, "buildable": true, "build_order": 4,
		"cost_gold": 0, "cost_wood": 60, "build_time": 18.0, "drop_off": true},
	"market": {"name": "集市", "hp": 650, "atk": 0, "building": true, "radius": 22, "buildable": true, "build_order": 5,
		"cost_gold": 0, "cost_wood": 100, "build_time": 22.0, "trades": true, "min_age": 1},
	"siege_workshop": {"name": "攻城作坊", "hp": 820, "atk": 0, "building": true, "radius": 28, "buildable": true, "build_order": 6,
		"cost_gold": 110, "cost_wood": 55, "build_time": 30.0, "min_age": 1,
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
		"proj_kind": "fireball", "splash": 38.0, "ability": "ling_zhen_q", "abilities": ["ling_zhen_q", "ling_zhen_w", "ling_zhen_e", "ling_zhen_r"], "dota": "Techies", "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 60, "train_time": 42, "trained_at": "hall", "min_age": 1},
	"wei_dingguo": {"name": "魏定国", "hp": 1070, "atk": 42, "cd": 2.0, "range": 200, "speed": 84, "ranged": true, "hero": true, "radius": 12,
		"ability": "wei_dingguo_q", "abilities": ["wei_dingguo_q", "wei_dingguo_w", "wei_dingguo_e", "wei_dingguo_r"], "dota": "Batrider", "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 55, "train_time": 44, "trained_at": "hall", "min_age": 1},
	"shan_tinggui": {"name": "单廷圭", "hp": 1200, "atk": 44, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 14,
		"ability": "shan_tinggui_q", "abilities": ["shan_tinggui_q", "shan_tinggui_w", "shan_tinggui_e", "shan_tinggui_r"], "dota": "Razor", "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 60, "train_time": 44, "trained_at": "hall", "min_age": 1},
	"wen_da": {"name": "闻达", "hp": 1600, "atk": 51, "cd": 1.0, "range": 30, "speed": 92, "hero": true, "radius": 15,
		"aura": "atk", "aura_r": 170, "aura_p": 1.12, "ability": "jd_lance", "abilities": ["jd_lance", "jd_valor"]},
	# __DOTA_UNITS_HERE__
	# __DOTA_GEN_UNITS_START__
	"lu_junyi": {"name": "卢俊义", "hp": 360, "atk": 30, "cd": 0.85, "range": 28, "speed": 105, "radius": 13, "hero": true, "abilities": ["lu_junyi_q", "lu_junyi_w", "lu_junyi_e", "lu_junyi_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 60, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 2, "dota": "Juggernaut"},
	"guan_sheng": {"name": "关胜", "hp": 480, "atk": 32, "cd": 0.95, "range": 30, "speed": 108, "radius": 13, "hero": true, "cavalry": true, "abilities": ["guan_sheng_q", "guan_sheng_w", "guan_sheng_e", "guan_sheng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 55, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 5, "dota": "Kunkka"},
	"qin_ming": {"name": "秦明", "hp": 180, "atk": 14, "cd": 1.15, "range": 220, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["qin_ming_q", "qin_ming_w", "qin_ming_e", "qin_ming_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 7, "dota": "Zeus"},
	"chai_jin": {"name": "柴进", "hp": 680, "atk": 28, "cd": 1, "range": 30, "speed": 95, "radius": 13, "hero": true, "abilities": ["chai_jin_q", "chai_jin_w", "chai_jin_e", "chai_jin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 65, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 10, "dota": "Wraith King"},
	"li_ying": {"name": "李应", "hp": 240, "atk": 34, "cd": 0.9, "range": 230, "speed": 100, "radius": 13, "hero": true, "ranged": true, "proj_kind": "arrow", "abilities": ["li_ying_q", "li_ying_w", "li_ying_e", "li_ying_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 11, "dota": "Drow Ranger"},
	"zhu_tong": {"name": "朱仝", "hp": 620, "atk": 30, "cd": 0.95, "range": 30, "speed": 100, "radius": 13, "hero": true, "cavalry": true, "abilities": ["zhu_tong_q", "zhu_tong_w", "zhu_tong_e", "zhu_tong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 60, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 12, "dota": "Dragon Knight"},
	"dong_ping": {"name": "董平", "hp": 320, "atk": 30, "cd": 0.78, "range": 28, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["dong_ping_q", "dong_ping_w", "dong_ping_e", "dong_ping_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 15, "dota": "Phantom Lancer"},
	"suo_chao": {"name": "索超", "hp": 480, "atk": 26, "cd": 0.85, "range": 28, "speed": 88, "radius": 14, "hero": true, "abilities": ["suo_chao_q", "suo_chao_w", "suo_chao_e", "suo_chao_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 38, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 19, "dota": "Axe"},
	"shi_jin": {"name": "史进", "hp": 300, "atk": 30, "cd": 0.78, "range": 28, "speed": 92, "radius": 13, "hero": true, "abilities": ["shi_jin_q", "shi_jin_w", "shi_jin_e", "shi_jin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 38, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 23, "dota": "Monkey King"},
	"mu_hong": {"name": "穆弘", "hp": 520, "atk": 30, "cd": 1, "range": 28, "speed": 80, "radius": 14, "hero": true, "abilities": ["mu_hong_q", "mu_hong_w", "mu_hong_e", "mu_hong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 40, "train_time": 44, "trained_at": "hall", "min_age": 1, "star": 24, "dota": "Tiny"},
	"lei_heng": {"name": "雷横", "hp": 420, "atk": 26, "cd": 1, "range": 28, "speed": 95, "radius": 13, "hero": true, "abilities": ["lei_heng_q", "lei_heng_w", "lei_heng_e", "lei_heng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 176, "cost_wood": 44, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 25, "dota": "Beastmaster"},
	"li_jun": {"name": "李俊", "hp": 640, "atk": 24, "cd": 1.1, "range": 28, "speed": 86, "radius": 13, "hero": true, "abilities": ["li_jun_q", "li_jun_w", "li_jun_e", "li_jun_r"], "hero_trainable": true, "pop": 3, "cost_gold": 196, "cost_wood": 56, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 26, "dota": "Tidehunter"},
	"zhang_heng": {"name": "张横", "hp": 320, "atk": 28, "cd": 0.85, "range": 26, "speed": 92, "radius": 13, "hero": true, "abilities": ["zhang_heng_q", "zhang_heng_w", "zhang_heng_e", "zhang_heng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 192, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 28, "dota": "Naga Siren"},
	"ruan_xiaowu": {"name": "阮小五", "hp": 300, "atk": 30, "cd": 0.8, "range": 26, "speed": 110, "radius": 13, "hero": true, "abilities": ["ruan_xiaowu_q", "ruan_xiaowu_w", "ruan_xiaowu_e", "ruan_xiaowu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 198, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 29, "dota": "Phantom Assassin"},
	"ruan_xiaoqi": {"name": "阮小七", "hp": 240, "atk": 14, "cd": 1.1, "range": 200, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["ruan_xiaoqi_q", "ruan_xiaoqi_w", "ruan_xiaoqi_e", "ruan_xiaoqi_r"], "hero_trainable": true, "pop": 3, "cost_gold": 186, "cost_wood": 30, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 31, "dota": "Necrophos"},
	"yang_xiong": {"name": "杨雄", "hp": 660, "atk": 26, "cd": 1.1, "range": 28, "speed": 88, "radius": 13, "hero": true, "abilities": ["yang_xiong_q", "yang_xiong_w", "yang_xiong_e", "yang_xiong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 58, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 32, "dota": "Doom"},
	"xie_zhen": {"name": "解珍", "hp": 220, "atk": 14, "cd": 1.1, "range": 200, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "fireball", "abilities": ["xie_zhen_q", "xie_zhen_w", "xie_zhen_e", "xie_zhen_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 34, "dota": "Jakiro"},
	"xie_bao": {"name": "解宝", "hp": 480, "atk": 28, "cd": 1, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["xie_bao_q", "xie_bao_w", "xie_bao_e", "xie_bao_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 44, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 35, "dota": "Sand King"},
	"yan_qing": {"name": "燕青", "hp": 320, "atk": 30, "cd": 0.8, "range": 26, "speed": 118, "radius": 13, "hero": true, "abilities": ["yan_qing_q", "yan_qing_w", "yan_qing_e", "yan_qing_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 38, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 36, "dota": "Riki"},
	"zhu_wu": {"name": "朱武", "hp": 240, "atk": 16, "cd": 1, "range": 180, "speed": 84, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["zhu_wu_q", "zhu_wu_w", "zhu_wu_e", "zhu_wu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 42, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 37, "dota": "Anti-Mage"},
	"huang_xin": {"name": "黄信", "hp": 600, "atk": 30, "cd": 1, "range": 26, "speed": 105, "radius": 13, "hero": true, "cavalry": true, "abilities": ["huang_xin_q", "huang_xin_w", "huang_xin_e", "huang_xin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 48, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 38, "dota": "Bane"},
	"sun_li": {"name": "孙立", "hp": 520, "atk": 34, "cd": 0.9, "range": 26, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["sun_li_q", "sun_li_w", "sun_li_e", "sun_li_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 50, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 39, "dota": "Chaos Knight"},
	"xuan_zan": {"name": "宣赞", "hp": 620, "atk": 30, "cd": 1, "range": 26, "speed": 108, "radius": 13, "hero": true, "cavalry": true, "abilities": ["xuan_zan_q", "xuan_zan_w", "xuan_zan_e", "xuan_zan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 52, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 40, "dota": "Centaur Warrunner"},
	"hao_siwen": {"name": "郝思文", "hp": 560, "atk": 26, "cd": 1, "range": 26, "speed": 105, "radius": 13, "hero": true, "cavalry": true, "abilities": ["hao_siwen_q", "hao_siwen_w", "hao_siwen_e", "hao_siwen_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 46, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 41, "dota": "Crystal Maiden"},
	"xiao_rang": {"name": "萧让", "hp": 200, "atk": 14, "cd": 1.1, "range": 220, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["xiao_rang_q", "xiao_rang_w", "xiao_rang_e", "xiao_rang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 170, "cost_wood": 30, "train_time": 38, "trained_at": "hall", "min_age": 1, "star": 46, "dota": "Keeper of the Light"},
	"pei_xuan": {"name": "裴宣", "hp": 230, "atk": 16, "cd": 1, "range": 210, "speed": 82, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["pei_xuan_q", "pei_xuan_w", "pei_xuan_e", "pei_xuan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 32, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 47, "dota": "Silencer"},
	"ou_peng": {"name": "欧鹏", "hp": 220, "atk": 26, "cd": 0.7, "range": 210, "speed": 100, "radius": 13, "hero": true, "ranged": true, "proj_kind": "arrow", "abilities": ["ou_peng_q", "ou_peng_w", "ou_peng_e", "ou_peng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 48, "dota": "Weaver"},
	"deng_fei": {"name": "邓飞", "hp": 520, "atk": 24, "cd": 1, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["deng_fei_q", "deng_fei_w", "deng_fei_e", "deng_fei_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 49, "dota": "Clockwerk"},
	"yang_lin": {"name": "杨林", "hp": 420, "atk": 28, "cd": 0.9, "range": 26, "speed": 110, "radius": 13, "hero": true, "abilities": ["yang_lin_q", "yang_lin_w", "yang_lin_e", "yang_lin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 42, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 51, "dota": "Bounty Hunter"},
	"jiang_jing": {"name": "蒋敬", "hp": 220, "atk": 14, "cd": 1, "range": 210, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["jiang_jing_q", "jiang_jing_w", "jiang_jing_e", "jiang_jing_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 53, "dota": "Outworld Destroyer"},
	"lu_fang": {"name": "吕方", "hp": 460, "atk": 30, "cd": 0.9, "range": 28, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["lu_fang_q", "lu_fang_w", "lu_fang_e", "lu_fang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 54, "dota": "Legion Commander"},
	"guo_sheng": {"name": "郭盛", "hp": 520, "atk": 34, "cd": 1, "range": 30, "speed": 100, "radius": 13, "hero": true, "cavalry": true, "abilities": ["guo_sheng_q", "guo_sheng_w", "guo_sheng_e", "guo_sheng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 50, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 55, "dota": "Mars"},
	"an_daoquan": {"name": "安道全", "hp": 200, "atk": 14, "cd": 1.1, "range": 200, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["an_daoquan_q", "an_daoquan_w", "an_daoquan_e", "an_daoquan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 35, "train_time": 39, "trained_at": "hall", "min_age": 1, "star": 56, "dota": "Dazzle"},
	"huangfu_duan": {"name": "皇甫端", "hp": 210, "atk": 14, "cd": 1.1, "range": 200, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["huangfu_duan_q", "huangfu_duan_w", "huangfu_duan_e", "huangfu_duan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 57, "dota": "Chen"},
	"wang_ying": {"name": "王英", "hp": 560, "atk": 30, "cd": 1.2, "range": 28, "speed": 100, "radius": 13, "hero": true, "cavalry": true, "abilities": ["wang_ying_q", "wang_ying_w", "wang_ying_e", "wang_ying_r"], "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 55, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 58, "dota": "Ogre Magi"},
	"bao_xu": {"name": "鲍旭", "hp": 480, "atk": 30, "cd": 0.9, "range": 28, "speed": 100, "radius": 13, "hero": true, "abilities": ["bao_xu_q", "bao_xu_w", "bao_xu_e", "bao_xu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 48, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 60, "dota": "Storm Spirit"},
	"fan_rui": {"name": "樊瑞", "hp": 200, "atk": 14, "cd": 1.15, "range": 195, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["fan_rui_q", "fan_rui_w", "fan_rui_e", "fan_rui_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 61, "dota": "Shadow Demon"},
	"kong_ming": {"name": "孔明", "hp": 210, "atk": 14, "cd": 1.1, "range": 190, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "fireball", "abilities": ["kong_ming_q", "kong_ming_w", "kong_ming_e", "kong_ming_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 42, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 62, "dota": "Phoenix"},
	"kong_liang": {"name": "孔亮", "hp": 340, "atk": 30, "cd": 0.95, "range": 26, "speed": 112, "radius": 13, "hero": true, "abilities": ["kong_liang_q", "kong_liang_w", "kong_liang_e", "kong_liang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 63, "dota": "Ember Spirit"},
	"xiang_chong": {"name": "项充", "hp": 330, "atk": 28, "cd": 0.9, "range": 26, "speed": 110, "radius": 13, "hero": true, "abilities": ["xiang_chong_q", "xiang_chong_w", "xiang_chong_e", "xiang_chong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 64, "dota": "Windranger"},
	"li_gun": {"name": "李衮", "hp": 320, "atk": 28, "cd": 0.92, "range": 26, "speed": 110, "radius": 13, "hero": true, "abilities": ["li_gun_q", "li_gun_w", "li_gun_e", "li_gun_r"], "hero_trainable": true, "pop": 3, "cost_gold": 192, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 65, "dota": "Lina"},
	"jin_dajian": {"name": "金大坚", "hp": 190, "atk": 13, "cd": 1.15, "range": 200, "speed": 78, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["jin_dajian_q", "jin_dajian_w", "jin_dajian_e", "jin_dajian_r"], "hero_trainable": true, "pop": 3, "cost_gold": 188, "cost_wood": 44, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 66, "dota": "Tinker"},
	"ma_lin": {"name": "马麟", "hp": 360, "atk": 28, "cd": 0.95, "range": 26, "speed": 108, "radius": 13, "hero": true, "abilities": ["ma_lin_q", "ma_lin_w", "ma_lin_e", "ma_lin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 194, "cost_wood": 38, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 67, "dota": "Pangolier"},
	"tong_wei": {"name": "童威", "hp": 560, "atk": 20, "cd": 1.1, "range": 26, "speed": 90, "radius": 13, "hero": true, "abilities": ["tong_wei_q", "tong_wei_w", "tong_wei_e", "tong_wei_r"], "hero_trainable": true, "pop": 3, "cost_gold": 196, "cost_wood": 48, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 68, "dota": "Lion"},
	"tong_meng": {"name": "童猛", "hp": 300, "atk": 26, "cd": 0.95, "range": 26, "speed": 108, "radius": 13, "hero": true, "abilities": ["tong_meng_q", "tong_meng_w", "tong_meng_e", "tong_meng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 194, "cost_wood": 40, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 69, "dota": "Shadow Shaman"},
	"meng_kang": {"name": "孟康", "hp": 230, "atk": 30, "cd": 1, "range": 200, "speed": 95, "radius": 13, "hero": true, "ranged": true, "proj_kind": "arrow", "abilities": ["meng_kang_q", "meng_kang_w", "meng_kang_e", "meng_kang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 60, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 70, "dota": "Gyrocopter"},
	"hou_jian": {"name": "侯健", "hp": 300, "atk": 22, "cd": 1, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["hou_jian_q", "hou_jian_w", "hou_jian_e", "hou_jian_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 40, "train_time": 38, "trained_at": "hall", "min_age": 1, "star": 71, "dota": "Witch Doctor"},
	"chen_da": {"name": "陈达", "hp": 340, "atk": 26, "cd": 0.95, "range": 26, "speed": 110, "radius": 13, "hero": true, "abilities": ["chen_da_q", "chen_da_w", "chen_da_e", "chen_da_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 72, "dota": "Nyx Assassin"},
	"yang_chun": {"name": "杨春", "hp": 240, "atk": 30, "cd": 1.05, "range": 210, "speed": 90, "radius": 13, "hero": true, "ranged": true, "proj_kind": "arrow", "abilities": ["yang_chun_q", "yang_chun_w", "yang_chun_e", "yang_chun_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 60, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 73, "dota": "Medusa"},
	"zheng_tianshou": {"name": "郑天寿", "hp": 300, "atk": 22, "cd": 1, "range": 26, "speed": 105, "radius": 13, "hero": true, "abilities": ["zheng_tianshou_q", "zheng_tianshou_w", "zheng_tianshou_e", "zheng_tianshou_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 74, "dota": "Enigma"},
	"tao_zongwang": {"name": "陶宗旺", "hp": 600, "atk": 24, "cd": 1, "range": 26, "speed": 90, "radius": 14, "hero": true, "abilities": ["tao_zongwang_q", "tao_zongwang_w", "tao_zongwang_e", "tao_zongwang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 55, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 75, "dota": "Bristleback"},
	"song_qing": {"name": "宋清", "hp": 200, "atk": 14, "cd": 1.1, "range": 190, "speed": 82, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["song_qing_q", "song_qing_w", "song_qing_e", "song_qing_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 40, "train_time": 38, "trained_at": "hall", "min_age": 1, "star": 76, "dota": "Oracle"},
	"yue_he": {"name": "乐和", "hp": 210, "atk": 15, "cd": 1.1, "range": 185, "speed": 84, "radius": 13, "hero": true, "ranged": true, "proj_kind": "fireball", "abilities": ["yue_he_q", "yue_he_w", "yue_he_e", "yue_he_r"], "hero_trainable": true, "pop": 3, "cost_gold": 185, "cost_wood": 45, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 77, "dota": "Snapfire"},
	"mu_chun": {"name": "穆春", "hp": 360, "atk": 30, "cd": 0.9, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["mu_chun_q", "mu_chun_w", "mu_chun_e", "mu_chun_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 38, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 80, "dota": "Marci"},
	"cao_zheng": {"name": "曹正", "hp": 300, "atk": 16, "cd": 1, "range": 28, "speed": 86, "radius": 13, "hero": true, "abilities": ["cao_zheng_q", "cao_zheng_w", "cao_zheng_e", "cao_zheng_r"], "hero_trainable": true, "pop": 3, "cost_gold": 180, "cost_wood": 52, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 81, "dota": "Pugna"},
	"song_wan": {"name": "宋万", "hp": 600, "atk": 22, "cd": 1.1, "range": 26, "speed": 80, "radius": 13, "hero": true, "abilities": ["song_wan_q", "song_wan_w", "song_wan_e", "song_wan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 175, "cost_wood": 46, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 82, "dota": "Elder Titan"},
	"du_qian": {"name": "杜迁", "hp": 640, "atk": 26, "cd": 1.1, "range": 26, "speed": 82, "radius": 13, "hero": true, "abilities": ["du_qian_q", "du_qian_w", "du_qian_e", "du_qian_r"], "hero_trainable": true, "pop": 3, "cost_gold": 178, "cost_wood": 48, "train_time": 41, "trained_at": "hall", "min_age": 1, "star": 83, "dota": "Primal Beast"},
	"xue_yong": {"name": "薛永", "hp": 320, "atk": 28, "cd": 0.85, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["xue_yong_q", "xue_yong_w", "xue_yong_e", "xue_yong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 84, "dota": "Templar Assassin"},
	"li_zhong": {"name": "李忠", "hp": 460, "atk": 24, "cd": 1, "range": 26, "speed": 90, "radius": 13, "hero": true, "abilities": ["li_zhong_q", "li_zhong_w", "li_zhong_e", "li_zhong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 176, "cost_wood": 42, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 86, "dota": "Tusk"},
	"zhou_tong": {"name": "周通", "hp": 380, "atk": 28, "cd": 0.9, "range": 26, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["zhou_tong_q", "zhou_tong_w", "zhou_tong_e", "zhou_tong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 196, "cost_wood": 44, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 87, "dota": "Luna"},
	"du_xing": {"name": "杜兴", "hp": 320, "atk": 27, "cd": 0.95, "range": 26, "speed": 115, "radius": 13, "hero": true, "abilities": ["du_xing_q", "du_xing_w", "du_xing_e", "du_xing_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 89, "dota": "Void Spirit"},
	"zou_yuan": {"name": "邹渊", "hp": 360, "atk": 31, "cd": 1, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["zou_yuan_q", "zou_yuan_w", "zou_yuan_e", "zou_yuan_r"], "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 90, "dota": "Terrorblade"},
	"zou_run": {"name": "邹润", "hp": 300, "atk": 26, "cd": 1, "range": 28, "speed": 110, "radius": 13, "hero": true, "abilities": ["zou_run_q", "zou_run_w", "zou_run_e", "zou_run_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 38, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 91, "dota": "Clinkz"},
	"zhu_gui": {"name": "朱贵", "hp": 620, "atk": 24, "cd": 1.2, "range": 26, "speed": 88, "radius": 14, "hero": true, "abilities": ["zhu_gui_q", "zhu_gui_w", "zhu_gui_e", "zhu_gui_r"], "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 50, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 92, "dota": "Underlord"},
	"zhu_fu": {"name": "朱富", "hp": 180, "atk": 14, "cd": 1.2, "range": 205, "speed": 80, "radius": 12, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["zhu_fu_q", "zhu_fu_w", "zhu_fu_e", "zhu_fu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 195, "cost_wood": 34, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 93, "dota": "Grimstroke"},
	"cai_fu": {"name": "蔡福", "hp": 540, "atk": 22, "cd": 1.15, "range": 26, "speed": 86, "radius": 14, "hero": true, "abilities": ["cai_fu_q", "cai_fu_w", "cai_fu_e", "cai_fu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 46, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 94, "dota": "Leshrac"},
	"cai_qing": {"name": "蔡庆", "hp": 210, "atk": 29, "cd": 1, "range": 200, "speed": 95, "radius": 12, "hero": true, "ranged": true, "proj_kind": "arrow", "abilities": ["cai_qing_q", "cai_qing_w", "cai_qing_e", "cai_qing_r"], "hero_trainable": true, "pop": 3, "cost_gold": 205, "cost_wood": 36, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 95, "dota": "Muerta"},
	"li_li": {"name": "李立", "hp": 190, "atk": 16, "cd": 1.2, "range": 200, "speed": 80, "radius": 12, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["li_li_q", "li_li_w", "li_li_e", "li_li_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 36, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 96, "dota": "Visage"},
	"li_yun": {"name": "李云", "hp": 410, "atk": 30, "cd": 1, "range": 26, "speed": 108, "radius": 13, "hero": true, "abilities": ["li_yun_q", "li_yun_w", "li_yun_e", "li_yun_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 40, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 97, "dota": "Night Stalker"},
	"jiao_ting": {"name": "焦挺", "hp": 420, "atk": 28, "cd": 1, "range": 26, "speed": 104, "radius": 13, "hero": true, "abilities": ["jiao_ting_q", "jiao_ting_w", "jiao_ting_e", "jiao_ting_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 42, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 98, "dota": "Earth Spirit"},
	"shi_yong": {"name": "石勇", "hp": 620, "atk": 30, "cd": 1.05, "range": 26, "speed": 94, "radius": 13, "hero": true, "abilities": ["shi_yong_q", "shi_yong_w", "shi_yong_e", "shi_yong_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 50, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 99, "dota": "Dawnbreaker"},
	"sun_xin": {"name": "孙新", "hp": 600, "atk": 28, "cd": 1, "range": 28, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["sun_xin_q", "sun_xin_w", "sun_xin_e", "sun_xin_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 50, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 100, "dota": "Abaddon"},
	"gu_dasao": {"name": "顾大嫂", "hp": 360, "atk": 24, "cd": 1, "range": 28, "speed": 100, "radius": 13, "hero": true, "abilities": ["gu_dasao_q", "gu_dasao_w", "gu_dasao_e", "gu_dasao_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 44, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 101, "dota": "Nature's Prophet"},
	"zhang_qing_cai": {"name": "张青", "hp": 240, "atk": 16, "cd": 1, "range": 200, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["zhang_qing_cai_q", "zhang_qing_cai_w", "zhang_qing_cai_e", "zhang_qing_cai_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 102, "dota": "Venomancer"},
	"sun_erniang": {"name": "孙二娘", "hp": 230, "atk": 15, "cd": 1.1, "range": 210, "speed": 80, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["sun_erniang_q", "sun_erniang_w", "sun_erniang_e", "sun_erniang_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 36, "train_time": 40, "trained_at": "hall", "min_age": 1, "star": 103, "dota": "Winter Wyvern"},
	"wang_dingliu": {"name": "王定六", "hp": 230, "atk": 18, "cd": 1, "range": 220, "speed": 96, "radius": 13, "hero": true, "ranged": true, "proj_kind": "magic", "abilities": ["wang_dingliu_q", "wang_dingliu_w", "wang_dingliu_e", "wang_dingliu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 104, "dota": "Arc Warden"},
	"yu_baosi": {"name": "郁保四", "hp": 480, "atk": 30, "cd": 1.05, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["yu_baosi_q", "yu_baosi_w", "yu_baosi_e", "yu_baosi_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 46, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 105, "dota": "Dark Seer"},
	"shi_qian": {"name": "时迁", "hp": 330, "atk": 26, "cd": 1, "range": 26, "speed": 100, "radius": 13, "hero": true, "abilities": ["shi_qian_q", "shi_qian_w", "shi_qian_e", "shi_qian_r"], "hero_trainable": true, "pop": 3, "cost_gold": 190, "cost_wood": 40, "train_time": 42, "trained_at": "hall", "min_age": 1, "star": 107, "dota": "Spectre"},
	"duan_jingzhu": {"name": "段景住", "hp": 360, "atk": 30, "cd": 0.95, "range": 28, "speed": 110, "radius": 13, "hero": true, "cavalry": true, "abilities": ["duan_jingzhu_q", "duan_jingzhu_w", "duan_jingzhu_e", "duan_jingzhu_r"], "hero_trainable": true, "pop": 3, "cost_gold": 200, "cost_wood": 50, "train_time": 44, "trained_at": "hall", "min_age": 1, "star": 108, "dota": "Kez"},
	# __DOTA_GEN_UNITS_END__
}

# 陷阱（喽啰 E 子菜单）：一次性地面机关。布在必经之路，敌人进 trigger_r 即触发一次后消失。
# 由 Battle._traps + _trap_pass 结算；art_db TRAP_CELLS / 程序化绘制。
# effect.kind: aoe(落点范围物理伤) / stun(范围眩晕+微伤) / fire(地面长燃 DoT，复用 _spawn_ground_fire)
const TRAPS := {
	"trap_logs": {"name": "滚木礌石", "cost_gold": 40, "cost_wood": 20, "trigger_r": 70.0, "arm_t": 1.0,
		"color": Color("9c6b3a"), "effect": {"kind": "aoe", "dmg": 120.0, "radius": 90.0}},
	"trap_pit": {"name": "陷坑", "cost_gold": 35, "cost_wood": 18, "trigger_r": 60.0, "arm_t": 1.0,
		"color": Color("6b5a3a"), "effect": {"kind": "stun", "dur": 2.0, "dmg": 15.0, "radius": 80.0}},
	"trap_oil": {"name": "火油", "cost_gold": 50, "cost_wood": 25, "trigger_r": 65.0, "arm_t": 1.0,
		"color": Color("ff7a2a"), "effect": {"kind": "fire", "total": 150.0, "dur": 6.0, "radius": 95.0}},
}

# 技能定义：name,cd,targeted,radius,color,desc(UI), 以及 effect(数据化结算描述)。
# effect.kind: rally(治疗+攻击buff队友) / haste(队友移速) / smite(范围伤敌,可附slow,可cav加成,可self自身buff)
#              / debuff(减速+削攻于敌) / drag(拖入水+伤害) / path(交给关卡处理)
const ABILITIES := {
	"song_rally": {"name": "替天行道", "cd": 12.0, "targeted": false, "radius": 300.0, "color": Color("ffd24a"),
		"desc": "号令群雄：周围梁山兵\n回血{v}、攻击+60%（8秒）·范围加大", "effect": {"kind": "rally", "heal": 42.0, "atk_mult": 1.6, "dur": 8.0}},
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
	"song_banner": {"name": "忠义双旗", "cd": 10.0, "max_charges": 2, "charge_recovery": 10.0, "targeted": true,
		"weak_global": true, "radius": 130.0, "color": Color("ffd24a"),
		"desc": "2点能量，每10秒恢复1点；依次插下蓝色「忠」旗与黄色「义」旗\n两旗均持续 5/7/9 秒：英雄减伤 20%/30%/40%，小兵与召唤物减伤 50%/70%/90%\n忠旗每秒回血 20/25/30；义旗攻速 +50%/+70%/+90%",
		"effect": {"kind": "ward", "ward_mode": "banner", "ward_style": "banner", "ward_radius": 130.0,
			"dur_ranks": [5.0, 7.0, 9.0], "hero_reduction_ranks": [0.20, 0.30, 0.40],
			"troop_reduction_ranks": [0.50, 0.70, 0.90], "heal_ranks": [20.0, 25.0, 30.0],
			"atkspeed_ranks": [1.50, 1.70, 1.90], "banner_variants": ["loyalty", "righteous"], "pulse": 1.0}},
	"song_fire": {"name": "火攻连营", "cd": 11.0, "targeted": true, "weak_global": true, "radius": 100.0, "color": Color("ff7a2a"),
		"desc": "指定处腾起烈焰\n地面每秒 20 灼伤，持续 5/8/10 秒(随等级)",
		"effect": {"kind": "fire_dot", "dps": 20.0, "dur_ranks": [5.0, 8.0, 10.0], "dmg": 100.0, "dur": 5.0}},
	"song_lead": {"name": "替天行道·仁义", "passive": true, "cd": 25.0, "targeted": false, "radius": 170.0, "color": Color("ffd24a"),
		"desc": "被动·仁义之名：攻击+3 / 生命+50 / 每秒回血3 / 常驻全军移速光环 +5%/10%/15%(随本技能等级)\n仗义疏财：宋江在场，全军击杀赏金 +25%\n主动·号令众将：所有友方英雄回血(=Q回血量)，宋江 Q 同时转入冷却",
		"effect": {"kind": "passive", "atk_add": 3.0, "hp_add": 50.0, "regen": 3.0, "speed_aura_ranks": [1.05, 1.10, 1.15], "active_kind": "rally_heroes"}},
	# 林冲：近战突击
	"lin_charge": {"name": "豹影冲锋", "cd": 7.0, "targeted": false, "radius": 92.0, "color": Color("e0a24a"),
		"desc": "豹影突进：身边官军\n受 {v} 伤害减速；自身攻击+40%（5秒）", "effect": {"kind": "smite", "dmg": 23.0, "slow": 0.6, "slow_dur": 1.5, "self_atk": 1.4, "self_dur": 5.0}},
	"lin_storm": {"name": "横扫千军", "cd": 11.0, "targeted": false, "radius": 122.0, "color": Color("7fb0ff"),
		"desc": "大范围横扫·震地\n官军受 {v} 伤害并眩晕 3 秒", "effect": {"kind": "smite", "dmg": 25.0, "stun": 3.0}},
	"lin_drill": {"name": "禁军教头", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("c0a0ff"),
		"desc": "被动·枪法精进\n攻击+，更克骑兵", "effect": {"kind": "passive", "atk_add": 4.0, "bonus_cav": 1.0}},
	# 花荣：神射
	"hua_rain": {"name": "箭雨", "cd": 10.0, "targeted": true, "weak_global": true, "radius": 100.0, "color": Color("a0e8c0"),
		"desc": "箭雨覆盖：一次 {v} 伤害\n箭簇钉地再灼 3 秒；命中减速 50%，持续 3 秒",
		"effect": {"kind": "smite", "dmg": 28.0, "dot_total": 21.0, "dot_dur": 3.0, "slow": 0.5, "slow_dur": 3.0}},
	"hua_pin": {"name": "定身神箭·五连珠", "cd": 9.0, "targeted": true, "target": "unit", "unit_team": "enemy",
		"combat_only": true, "weak_global": true, "radius": 0.0, "color": Color("8fd3ff"),
		"desc": "无限射程单体神箭：造成 24/34/43 伤害并定身 2/2.5/3 秒\n接下来五次普攻优先射击该目标，且无视攻击距离",
		"effect": {"kind": "hua_pin_target", "dmg_ranks": [24.0, 34.0, 43.0],
			"root_ranks": [2.0, 2.5, 3.0], "lock_shots": 5}},
	"hua_eye": {"name": "小李广", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("a0e8c0"),
		"desc": "被动·神射\n攻击+、射程+", "effect": {"kind": "passive", "atk_add": 3.0, "range_add": 30.0}},
	"hua_blade": {"name": "百步穿杨", "cd": 22.0, "cd_ranks": [22.0, 20.0, 18.0], "cast_windup": 1.0,
		"targeted": true, "target": "unit", "unit_team": "enemy", "combat_only": true, "weak_global": true,
		"radius": 0.0, "color": Color("ffd86a"),
		"desc": "蓄力 1 秒射击单个目标；秒杀非敌将单位\n敌将受最大生命 20%/25%/30% 伤害，并在 5 秒内每秒再受最大生命 3%/4%/5% 伤害",
		"effect": {"kind": "hua_snipe", "hero_burst_ranks": [0.20, 0.25, 0.30],
			"hero_dot_ranks": [0.03, 0.04, 0.05], "dot_dur": 5.0, "dot_tick": 1.0, "cast_range": 760.0}},
	# 李逵：狂战
	"li_whirl": {"name": "黑旋风", "cd": 7.0, "targeted": false, "radius": 110.0, "color": Color("ff5544"),
		"desc": "旋身狂砍·刀旋如风\n身边官军受 {v} 伤害", "effect": {"kind": "smite", "dmg": 28.0, "self_atk": 1.3, "self_dur": 4.0}},
	"li_rage": {"name": "嗜血狂斩", "cd": 8.0, "targeted": false, "radius": 95.0, "color": Color("ff3322"),
		"desc": "血溅四方：身边官军受 {v} 伤害\n自身嗜血回血（6秒）", "effect": {"kind": "smite", "dmg": 23.0, "self_atk": 1.3, "self_dur": 6.0, "self_lifesteal": 0.5, "self_lifesteal_dur": 6.0}},
	"li_brawn": {"name": "蛮力", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("ff7766"),
		"desc": "被动·黑铁筋骨\n生命+、攻击吸血；普攻30%概率\n向120范围所有官军各投一斧（普攻伤害）",
		"effect": {"kind": "passive", "hp_add": 120.0, "lifesteal": 0.15, "atk_add": 2.0,
			"axe_chance": 0.30, "axe_radius": 120.0, "axe_art": "axe"}},

	# ===== DOTA 式英雄技能改版（林冲/花荣/李逵）=====
	# 林冲 Q·丈八枪破阵：朝指向猛刺一记长矛波，贯穿前方矩形区域
	"lin_thrust": {"name": "丈八·破阵突刺", "cd": 8.0, "targeted": true, "radius": 260.0, "color": Color("c0a0ff"),
		"desc": "丈八蛇矛朝指向猛刺\n前方扇形区内官军受 {v} 伤害并减速",
		"effect": {"kind": "sector_nuke", "dmg": 42.0, "range": 260.0, "arc": 70.0, "slow": 0.5, "slow_dur": 1.6}},
	# 林冲 E·禁军教头·猎杀（被动）：更克骑兵，且打骑兵 30% 概率吸血 80%
	"lin_predator": {"name": "禁军教头·猎骑", "passive": true, "cd": 0.0, "targeted": false, "radius": 0.0, "color": Color("c8e0ff"),
		"desc": "被动·专破马军\n克骑兵伤害 +0.3/0.6/0.9（满级 1.9×）；攻击 35% 几率\n按 90%/120%/150% 伤害吸血（打骑兵满额、非骑兵半额）",
		"effect": {"kind": "passive", "atk_add": 3.0, "bonus_cav": 0.3, "cav_ls_chance": 0.35, "cav_ls_frac_ranks": [0.90, 1.20, 1.50]}},
	# 林冲 R·时空封印（虚空大）：范围内时间停滞，敌军定身 10 秒
	"lin_chrono": {"name": "时空封印", "cd": 40.0, "targeted": true, "radius": 200.0, "color": Color("a070ff"),
		"desc": "撕裂时空：指定处结成封印立场\n域内官军时间停滞 10 秒（封印范围随等级扩大）",
		"effect": {"kind": "chrono", "dur": 10.0, "radius_ranks": [130.0, 165.0, 200.0]}},
	# 花荣 Q·凌空闪：闪现落地后进入 5 秒身法强化，不再造成沿途范围伤害
	"hua_blink": {"name": "凌空闪·穿云箭", "cd": 9.0, "targeted": true, "radius": 330.0, "color": Color("a0e8c0"),
		"desc": "闪现至落点；落地后 5 秒内获得 30%/60%/90% 闪避\n并提升 30%/40%/50% 移动速度",
		"effect": {"kind": "blink_shot", "len": 330.0, "width": 72.0, "buff_dur": 5.0,
			"evasion_ranks": [0.30, 0.60, 0.90], "move_ranks": [1.30, 1.40, 1.50]}},
	# 李逵 Q·双斧回旋：两柄板斧绕身旋飞，持续扫伤减速
	"li_axes": {"name": "双斧回旋", "cd": 9.0, "targeted": false, "radius": 120.0, "color": Color("ff7744"),
		"desc": "两柄板斧绕身旋飞 3 秒，自身减伤50%\n身边官军反复受 {v} 伤害并被减速",
		"effect": {"kind": "orbit_axes", "dmg": 16.0, "slow": 0.5, "slow_dur": 1.0, "dur": 3.0, "tick": 0.5,
			"self_reduction": 0.50, "orbit_art": "axe"}},
	# 李逵 W·莽撞冲锋（矢量·单击方向）：原地蓄力 1 秒，朝指向猛冲，撞伤沿途
	"li_charge": {"name": "莽撞冲锋", "cd": 11.0, "targeted": true, "radius": 210.0, "color": Color("ff9a3a"),
		"desc": "选定方向蓄力 1 秒后猛冲，期间物理免疫\n撞翻沿途官军，受 {v} 伤害并减速",
		"effect": {"kind": "charge", "dmg": 36.0, "windup": 1.0, "dist": 210.0, "width": 56.0,
			"slow": 0.4, "slow_dur": 1.0, "phys_immune": true}},
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
	# R·画龙点睛：召唤一条金龙参战（血/攻同公孙胜），持续 15 秒
	"gong_dragon": {"name": "画龙点睛", "cd": 25.0, "targeted": false, "radius": 0.0, "color": Color("ffd24a"),
		"desc": "大招·点睛唤龙\n召一条远程吐火金龙助战（血/攻为本体 100%/150%/200%）\n吐火带小范围溅射·持续 15 秒",
		"effect": {"kind": "summon", "unit": "dragon_summon", "count": 1, "summon_kind": "dragon", "copy_caster": true,
			"copy_mult": [1.0, 1.5, 2.0], "dur": 15.0}},

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
	# __DOTA_ABILITIES_HERE__
	# __DOTA_GEN_ABIL_START__
	"lu_junyi_q": {"name": "枪走龙蛇", "cd": 10, "targeted": false, "radius": 250, "color": Color("ffd24a"), "desc": "玉麒麟舞动银枪化作一阵旋风，绕身横扫四方，期间近敌持续受创并迟滞 {v}。", "effect": {"kind": "orbit_axes", "dmg": 30, "slow": 0.7, "slow_dur": 1.5, "dur": 3, "tick": 0.5}},
	"lu_junyi_w": {"name": "疗伤金创", "cd": 26, "targeted": true, "radius": 220, "color": Color("a0e8c0"), "desc": "玉麒麟于阵中钉下一根金创疗伤桩，立在原地不断为四周弟兄回血——桩在血不止，可随大军前推再插。", "effect": {"kind": "ward", "ward_mode": "heal", "ward_style": "heal", "ward_radius": 220, "pulse": 1.0, "heal_ranks": [14, 20, 28], "dur_ranks": [14, 16, 18]}},
	"lu_junyi_e": {"name": "棍棒天下", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "卢俊义棍棒枪法俱为天下无双，出手时有几率施出致命重击。", "effect": {"kind": "passive", "crit_chance": 0.08, "crit_mult": 1.8}},
	"lu_junyi_r": {"name": "万军取首", "cd": 40, "targeted": true, "radius": 70, "color": Color("ff3322"), "desc": "玉麒麟身形如电连斩数刀，于乱军之中直取敌将首级，爆发巨创 {v}。", "effect": {"kind": "smite", "dmg": 110, "stun": 0.6, "self_lifesteal": 0.8, "self_lifesteal_dur": 3}},
	"wu_yong_q": {"name": "智珠破阵", "cd": 10, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "智多星掐指放出一颗流转的智珠，沿线贯穿敌阵，所过者受创 {v} 并迟滞。", "effect": {"kind": "line_nuke", "dmg": 45, "len": 300, "width": 40, "slow": 0.6, "slow_dur": 2}},
	"wu_yong_w": {"name": "迷魂困雾", "cd": 12, "targeted": false, "radius": 240, "color": Color("6a4fb0"), "desc": "周身骤起一团乱雾，迷障近敌耳目，受创 {v} 且片刻无法施法。", "effect": {"kind": "smite", "dmg": 40, "silence": 2}},
	"wu_yong_e": {"name": "神出鬼没", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "吴用行踪诡谲虚实难测，临敌时常令对手扑空，凭空避开来袭。", "effect": {"kind": "passive", "evasion": 0.1}},
	"wu_yong_r": {"name": "锁链连环", "cd": 40, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "布下连环锁阵将一片敌将牢牢牵制，凡妄动者皆被定身，困其 {v} 时。", "effect": {"kind": "chrono", "dur": 4, "radius_ranks": [180, 200, 220]}},
	"guan_sheng_q": {"name": "怒涛冲霄", "cd": 11, "targeted": true, "radius": 180, "color": Color("9fd8ff"), "desc": "大刀关胜引动潜流，于落点掀起冲天怒涛，敌众被掀翻昏厥并受创 {v}。", "effect": {"kind": "smite", "dmg": 45, "stun": 1.4, "slow": 0.6, "slow_dur": 2}},
	"guan_sheng_w": {"name": "潮涌偃月", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "青龙偃月刀沉如潮涌，挥刀必带横扫之劲，连斩刀锋两侧之敌。", "effect": {"kind": "passive", "on_hit_dmg": 12}},
	"guan_sheng_e": {"name": "标定要津", "cd": 14, "targeted": true, "radius": 0, "color": Color("a0e8c0"), "desc": "于战场要津暗下标记，关胜身随刀走、瞬移占据有利之位。", "effect": {"kind": "blink", "dist": 220, "dmg": 30.0}},
	"guan_sheng_r": {"name": "幽冥战舸", "cd": 45, "targeted": true, "radius": 250, "color": Color("9fd8ff"), "desc": "召来一艘幽冥战舸破浪压境，撞翻一片敌军、重创 {v} 并将其昏厥镇住。", "effect": {"kind": "smite", "dmg": 90, "stun": 1.5, "slow": 0.5, "slow_dur": 3}},
	"qin_ming_q": {"name": "霹雳连枝", "cd": 7, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "霹雳火掷出一道连枝惊雷，在敌群间逐个跳跃弹射，每跳威力递减，初击 {v}。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 5, "jump": 200, "falloff": 0.85}},
	"qin_ming_w": {"name": "落雷殛敌", "cd": 8, "targeted": true, "radius": 50, "color": Color("8fd3ff"), "desc": "凝空一道焦雷直劈落点之敌，轰然炸裂、致创 {v} 并震得对手呆立。", "effect": {"kind": "smite", "dmg": 50, "stun": 0.6}},
	"qin_ming_e": {"name": "电芒缠身", "cd": 0, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "passive": true, "desc": "秦明周身常绕电芒，每次施法皆有余电外泄，灼伤近旁之敌。", "effect": {"kind": "passive", "on_hit_dmg": 10}},
	"qin_ming_r": {"name": "雷霆之怒", "cd": 45, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "desc": "霹雳火召动满天雷霆，无论敌军藏于何处皆遭天罚轰顶，全图重创 {v}。", "effect": {"kind": "global_nuke", "dmg": 40, "slow": 0.7, "slow_dur": 1.5}},
	"hu_yanzhuo_q": {"name": "风雷双鞭", "cd": 11, "targeted": true, "radius": 120, "color": Color("8fd3ff"), "desc": "双鞭呼啸如风雷砸落，落点之敌受创 {v}、震得踉跄，兵器脱手 2.5 秒打不出招（缴械）。", "effect": {"kind": "smite", "dmg": 45, "stun": 0.8, "disarm": 2.5}},
	"hu_yanzhuo_w": {"name": "横扫千军", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "呼延灼鞭势开阔，一鞭抡出余威波及左右连伤群敌；连环马阵法愈熟，麾下弟兄攻势愈盛（攻击光环随等级增强）。", "effect": {"kind": "passive", "on_hit_dmg": 12, "aura_power_ranks": [1.14, 1.22, 1.30]}},
	"hu_yanzhuo_e": {"name": "连环护甲", "cd": 18, "targeted": false, "radius": 250, "color": Color("a0e8c0"), "desc": "以连环马阵法护住周遭弟兄，为其披上一层可挡刀枪的甲气，吸伤 {v}。", "effect": {"kind": "shield", "shield": 150, "dur": 6, "allies": true, "radius": 250}},
	"hu_yanzhuo_r": {"name": "神威鞭法", "cd": 40, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "呼延灼神威贯顶，双鞭之力暴涨，平攻大增 {v} 并大口吸取敌血，持续一阵。", "effect": {"kind": "self_buff", "atk_add": 30, "lifesteal": 0.4, "dur": 8}},
	"chai_jin_q": {"name": "幽火重锤", "cd": 10, "targeted": true, "radius": 100, "color": Color("6a4fb0"), "desc": "小旋风掷出一记缠着幽火的重锤，砸晕敌众、致创 {v}，余烬尚要灼烧片刻。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.2, "dot_total": 40, "dot_dur": 3}},
	"chai_jin_w": {"name": "饮血之魂", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "柴进刀刃附有索命之魂，每次砍杀都将敌血回补己身。", "effect": {"kind": "passive", "lifesteal": 0.5}},
	"chai_jin_e": {"name": "夺命一击", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "出手之间暗藏夺命杀招，时而一击致命，造成成倍重创。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 2}},
	"chai_jin_r": {"name": "丹书铁券", "cd": 45, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "凭祖传丹书铁券护身，柴进周身罩起一层化解致命之伤的魂甲，吸伤 {v}。", "effect": {"kind": "shield", "shield": 250, "dur": 6, "allies": false}},
	"li_ying_q": {"name": "寒霜飞爪", "cd": 0, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "passive": true, "desc": "扑天雕箭如寒霜，凡中箭者周身冻凝、步履迟滞难行。", "effect": {"kind": "passive", "on_hit_slow": 0.6, "on_hit_slow_dur": 1.5}},
	"li_ying_w": {"name": "罡风扑面", "cd": 14, "targeted": true, "radius": 150, "color": Color("9fd8ff"), "desc": "振翅卷起一阵罡风，将正面敌众尽数掀退并震得呆立，附带 {v} 伤。", "effect": {"kind": "knockback", "dmg": 20, "push": 120, "radius": 150, "stun": 1}},
	"li_ying_e": {"name": "乱箭攒射", "cd": 12, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "李应张弓朝前方泼出一片箭雨，扇面之内敌众皆受箭创 {v}。", "effect": {"kind": "sector_nuke", "dmg": 35, "range": 280, "arc": 60, "slow": 0.7, "slow_dur": 1.5}},
	"li_ying_r": {"name": "百步穿杨", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "扑天雕箭术登峰造极，射程更远、平攻更狠，且时有穿心一箭重创敌将。", "effect": {"kind": "passive", "atk_add": 5, "crit_chance": 0.08, "crit_mult": 1.8, "range_add": 20}},
	"zhu_tong_q": {"name": "苍龙吐焰", "cd": 11, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "美髯公催动龙威朝前喷出一道烈焰，扇面之敌尽被灼烧、受创 {v}。", "effect": {"kind": "sector_nuke", "dmg": 40, "range": 280, "arc": 50}},
	"zhu_tong_w": {"name": "龙尾拍击", "cd": 10, "targeted": true, "target": "unit", "radius": 0, "color": Color("ffd24a"), "desc": "美髯公挥龙尾直取一将（单体指向）：拍伤 {v} 并击晕 1.8 秒——先手开团的铁控。", "effect": {"kind": "bolt", "dmg": 35, "stun": 1.8, "proj_speed": 520}},
	"zhu_tong_e": {"name": "龙血之躯", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "朱仝身负龙血，气血雄厚、伤创自愈，临阵愈久愈坚。", "effect": {"kind": "passive", "regen": 3, "hp_add": 80}},
	"zhu_tong_r": {"name": "神龙化身", "cd": 45, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "美髯公化身巨龙 16 秒：龙躯庞大、气血雄浑、爪牙裂金，平攻大涨且愈战愈坚（变身·到期还原）。", "effect": {"kind": "transform", "dur": 16, "form": {"atk_mult": 1.6, "hp_mult": 1.4, "atk_cd_mult": 0.85, "radius": 18.0, "tint": Color(1.2, 0.95, 0.7)}}},
	"lu_zhishen_q": {"name": "倒拔垂杨", "cd": 13, "targeted": true, "radius": 0, "color": Color("8a5a2a"), "desc": "花和尚奋力一杖砸地，劈出一道贯穿地裂——沿途官军受创 {v} 并被掀晕，裂沟更拱起一道阻路石墙，将去路硬生生截断数息。", "effect": {"kind": "fissure", "dmg": 45, "len": 320, "width": 40, "stun": 1.2, "slow": 0.5, "slow_dur": 2, "wall_dur": 4}},
	"lu_zhishen_w": {"name": "运禅蓄力", "cd": 9, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "鲁智深运起禅杖之力凝聚一身，接下来几下重击平攻暴增 {v}。", "effect": {"kind": "self_buff", "atk_add": 40, "lifesteal": 0, "dur": 5}},
	"lu_zhishen_e": {"name": "余震撼地", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "passive": true, "desc": "禅杖落处地动山摇，每次重击都有几率震晕近旁之敌。", "effect": {"kind": "passive", "bash_chance": 0.2, "bash_dur": 0.8}},
	"lu_zhishen_r": {"name": "禅杖回音", "cd": 45, "targeted": false, "radius": 280, "color": Color("8a5a2a"), "desc": "花和尚禅杖狠砸大地，层层回荡震波撼裂四方——身周每多一名敌军，每人便多挨一记回音，敌越密则人人伤越重（基础 {v}）并震晕。", "effect": {"kind": "echo", "dmg": 55, "echo": 16, "stun": 1.2, "slow": 0.5, "slow_dur": 1.5}},
	"dong_ping_q": {"name": "双枪贯刺", "cd": 8, "targeted": true, "radius": 60, "color": Color("8fd3ff"), "desc": "掷出双枪贯穿落点，刺中者重创并迟滞 {v} 移速。", "effect": {"kind": "smite", "dmg": 50, "slow": 0.5, "slow_dur": 2}},
	"dong_ping_w": {"name": "幻身遁影", "cd": 12, "targeted": true, "radius": 100.0, "color": Color("a0c8ff"), "desc": "虚晃一枪化作幻影瞬移至指定处，避开围杀。", "effect": {"kind": "blink", "dist": 260, "dmg": 30.0}},
	"dong_ping_e": {"name": "枪诀疾驰", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "passive": true, "desc": "枪法愈练愈疾，被动提升移速、攻速与攻击。", "effect": {"kind": "passive", "speed_mult": 0.05, "atkspeed_add": 0.1, "atk_add": 3}},
	"dong_ping_r": {"name": "百枪分身", "cd": 40, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "desc": "枪影重重，董平裂出 3 名与本体一般无二的双枪分身（承本体三~五成战力、半透蓝影现形），真假难辨乱敌阵脚。", "effect": {"kind": "summon", "summon_kind": "phantom", "count": 3, "copy_caster": true, "copy_mult": [0.3, 0.4, 0.5], "dur": 18, "unit": "tiger_summon"}},
	"zhang_qing_q": {"name": "没羽神石", "cd": 9, "targeted": true, "radius": 0, "color": Color("c0d8ff"), "desc": "没羽箭遥掷一记神石破空直飞，砸中路径上第一个敌人造成 {v} 巨伤并砸晕 1.6 秒——可被走位闪避。", "effect": {"kind": "bolt", "homing": false, "dmg": 60, "stun": 1.6, "proj_speed": 640, "len": 560, "width": 44}},
	"zhang_qing_w": {"name": "没羽飞石", "cd": 14, "targeted": true, "radius": 40, "color": Color("8fd3ff"), "desc": "远掷一记神石正中目标，重创并定身 {v} 不能动。", "effect": {"kind": "smite", "dmg": 55, "stun": 1.8}},
	"zhang_qing_e": {"name": "纵身一跃", "cd": 12, "targeted": true, "radius": 100.0, "color": Color("a0e8c0"), "desc": "足尖一点纵跃而出，瞬移腾挪拉开身位。", "effect": {"kind": "blink", "dist": 220, "dmg": 30.0}},
	"zhang_qing_r": {"name": "月华隐踪", "cd": 40, "targeted": false, "radius": 330, "color": Color("c0d8ff"), "desc": "借月色掩护全军身形，范围友军加速疾行掩袭。", "effect": {"kind": "haste", "speed_mult": 1.5, "dur": 12}},
	"yang_zhi_q": {"name": "豹突奔袭", "cd": 12, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "desc": "青面兽暴起发力，骤增 {v} 移速猛扑先手。", "effect": {"kind": "haste", "speed_mult": 1.45, "dur": 8}},
	"yang_zhi_w": {"name": "震地碎", "cd": 9, "targeted": false, "radius": 180, "color": Color("ff7a2a"), "desc": "重刀顿地，四周之敌震伤、眩晕并减速。", "effect": {"kind": "smite", "dmg": 45, "stun": 1.4, "slow": 0.5, "slow_dur": 2}},
	"yang_zhi_e": {"name": "重锤", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "passive": true, "desc": "刀沉力猛，平攻有几率震晕敌人并附加伤害。", "effect": {"kind": "passive", "bash_chance": 0.18, "bash_dur": 0.9, "atk_add": 3}},
	"yang_zhi_r": {"name": "破甲锁敌", "cd": 28, "targeted": true, "radius": 40, "color": Color("ff7a2a"), "desc": "看破甲缝重劈，大幅削减目标护甲 {v} 秒，群殴必杀。", "effect": {"kind": "smite", "dmg": 30, "def_down": 8, "def_down_dur": 15}},
	"xu_ning_q": {"name": "枪气冲波", "cd": 9, "targeted": true, "radius": 100.0, "color": Color("8fd3ff"), "desc": "金枪荡出一道贯地枪气，沿线伤敌并减速。", "effect": {"kind": "line_nuke", "dmg": 45, "len": 300, "width": 80, "slow": 0.5, "slow_dur": 1.5}},
	"xu_ning_w": {"name": "钩镰激励", "cd": 12, "targeted": false, "radius": 250, "color": Color("ffd24a"), "desc": "传授钩镰枪法，范围友军回血并大涨攻击 {v}。", "effect": {"kind": "rally", "heal": 20, "atk_mult": 1.3, "dur": 25}},
	"xu_ning_e": {"name": "钩镰穿击", "cd": 14, "targeted": true, "radius": 100.0, "color": Color("a0c8ff"), "desc": "挺枪猛冲，把沿途之敌钩带穿插一线之上。", "effect": {"kind": "charge", "dmg": 50, "windup": 0.3, "dist": 300, "width": 70, "slow": 0.5, "slow_dur": 1.5}},
	"xu_ning_r": {"name": "天崩枪威", "cd": 40, "targeted": false, "radius": 220, "color": Color("ff7a2a"), "desc": "枪罡爆发将四方之敌尽数卷住定身 {v} 秒。", "effect": {"kind": "smite", "dmg": 40, "stun": 2.5}},
	"suo_chao_q": {"name": "急锋叱喝", "cd": 12, "targeted": false, "radius": 180, "color": Color("ff3322"), "desc": "急先锋一声暴喝，逼周围之敌撇下一切与他死战 2 秒，震伤并自披一层硬甲护盾。", "effect": {"kind": "smite", "dmg": 10, "taunt": 2.0, "self_shield": 70, "self_shield_dur": 4.0}},
	"suo_chao_w": {"name": "战饥追命", "cd": 12, "targeted": true, "radius": 30, "color": Color("ff7a2a"), "desc": "标定一敌穷追猛打，持续灼伤并拖慢其移速。", "effect": {"kind": "smite", "dmg": 15, "dot_total": 80, "dot_dur": 8, "slow": 0.6, "slow_dur": 8}},
	"suo_chao_e": {"name": "反旋斩", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "passive": true, "desc": "大斧旋身回斩，被动赋予暴击与额外攻击。", "effect": {"kind": "passive", "crit_chance": 0.12, "crit_mult": 1.6, "atk_add": 2}},
	"suo_chao_r": {"name": "掷斧斩首", "cd": 30, "targeted": true, "target": "unit", "radius": 0, "color": Color("ff3322"), "desc": "急先锋掷出大斧直取一将首级（单体指向）：{v} 巨伤，残血者必应声落首。", "effect": {"kind": "bolt", "dmg": 120, "proj_speed": 560, "bolt_art": "axe"}},
	"dai_zong_q": {"name": "神行冲撞", "cd": 14, "targeted": true, "radius": 100.0, "color": Color("8fd3ff"), "desc": "踏甲马疾风千里直撞目标，沿途冲伤并减速。", "effect": {"kind": "charge", "dmg": 55, "windup": 0.4, "dist": 600, "width": 60, "slow": 0.5, "slow_dur": 1.5}},
	"dai_zong_w": {"name": "推山阔步", "cd": 12, "targeted": false, "radius": 100.0, "color": Color("a0e8c0"), "desc": "运起神行之术阔步如飞，骤增 {v} 移速势不可挡。", "effect": {"kind": "haste", "speed_mult": 1.5, "dur": 6}},
	"dai_zong_e": {"name": "巨力重击", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "passive": true, "desc": "行势带力，平攻有几率震晕敌人、附伤并略增移速。", "effect": {"kind": "passive", "bash_chance": 0.17, "bash_dur": 1, "on_hit_dmg": 10, "speed_mult": 0.04}},
	"dai_zong_r": {"name": "神行夺魄", "cd": 50, "targeted": true, "radius": 100.0, "color": Color("8fd3ff"), "desc": "瞬掠至目标背后猛击 {v} 重伤夺魄并减速。", "effect": {"kind": "blink", "dist": 600, "dmg": 90, "slow": 0.5, "slow_dur": 1.5, "radius": 40}},
	"liu_tang_q": {"name": "血怒", "cd": 10, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "desc": "赤发鬼血气上涌，狂增攻速 {v} 并提升自身攻击。", "effect": {"kind": "atkspeed", "atkspeed": 1.5, "dur": 9, "self_atk": 1.3}},
	"liu_tang_w": {"name": "赤血祭", "cd": 12, "targeted": true, "radius": 200, "color": Color("ff3322"), "desc": "洒血结阵，范围内之敌受伤且被噤声 {v} 秒不得施法。", "effect": {"kind": "smite", "dmg": 50, "silence": 3}},
	"liu_tang_e": {"name": "嗜血", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "passive": true, "desc": "嗜血成性，被动获得移速、吸血与额外攻击。", "effect": {"kind": "passive", "speed_mult": 0.05, "lifesteal": 0.4, "atk_add": 2}},
	"liu_tang_r": {"name": "裂血", "cd": 30, "targeted": true, "target": "unit", "radius": 0, "color": Color("ff3322"), "desc": "撕裂一将血脉（单体指向）：重创 {v}，伤口 6 秒不合——受到的一切伤害大增三成、移速大减。", "effect": {"kind": "bolt", "dmg": 100, "slow": 0.5, "slow_dur": 3, "amp": 0.3, "amp_dur": 6, "proj_speed": 500}},
	"shi_jin_q": {"name": "无界棍", "cd": 9, "targeted": true, "radius": 100.0, "color": Color("ffd24a"), "desc": "九纹龙抡棍贯出一线棍气，沿途重击并减速。", "effect": {"kind": "line_nuke", "dmg": 50, "len": 320, "width": 80, "slow": 0.5, "slow_dur": 1.5}},
	"shi_jin_w": {"name": "腾跃", "cd": 8, "targeted": true, "radius": 100.0, "color": Color("a0e8c0"), "desc": "借棍一点腾身跃起，瞬移至指定处突袭或脱身。", "effect": {"kind": "blink", "dist": 240, "dmg": 30.0}},
	"shi_jin_e": {"name": "金箍精通", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "passive": true, "desc": "棍法纯熟，被动获暴击、吸血与额外攻击。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.8, "lifesteal": 0.5, "atk_add": 3}},
	"shi_jin_r": {"name": "齐天分身", "cd": 40, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "desc": "棍影化身召出群猴助战，围成棍阵乱打来敌。", "effect": {"kind": "summon", "summon_kind": "monkey", "count": 4, "copy_caster": true, "copy_mult": [0.3, 0.4, 0.5], "dur": 16, "unit": "tiger_summon"}},
	"mu_hong_q": {"name": "天石崩坠", "cd": 10, "targeted": true, "radius": 180, "color": Color("ff7a2a"), "desc": "撼天巨力震落乱石砸向落点，伤敌并眩晕 {v} 秒。", "effect": {"kind": "smite", "dmg": 45, "stun": 1.4}},
	"mu_hong_w": {"name": "投掷", "cd": 12, "targeted": true, "radius": 100.0, "color": Color("ffd24a"), "desc": "一把擒住近敌猛掷出去，落地砸伤并定身。", "effect": {"kind": "pull", "dmg": 50, "len": 300, "width": 80, "pull_dist": 200, "stun": 1}},
	"mu_hong_e": {"name": "拔树横扫", "cd": 11, "targeted": true, "radius": 100.0, "color": Color("a0e8c0"), "desc": "连根拔树横扫一线，沿途之敌尽数砸伤减速。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 280, "width": 90, "slow": 0.5, "slow_dur": 1.5}},
	"mu_hong_r": {"name": "撼天巨化", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ff7a2a"), "passive": true, "desc": "没遮拦体魄愈壮，被动巨增攻击、血量与攻击距离。", "effect": {"kind": "passive", "atk_add": 5, "hp_add": 140, "range_add": 10}},
	"lei_heng_q": {"name": "野斧横飞", "cd": 8, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "向阵前掷出旋斧贯穿一线，劈伤{v}并放缓敌势。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 200, "width": 36, "slow": 0.7, "slow_dur": 1.5}},
	"lei_heng_w": {"name": "唤虎引豹", "cd": 30, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "插翅虎啸聚林中猛兽两头助阵，共逐官军。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "beast", "hp": [260, 320, 380], "atk": [18, 22, 26], "dur": 35}},
	"lei_heng_e": {"name": "野性本能", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "久走江湖练就的野性，周身儿郎出手更疾、伤愈更快。", "effect": {"kind": "passive", "atkspeed_add": 0.12, "regen": 1}},
	"lei_heng_r": {"name": "震天怒吼", "cd": 40, "targeted": true, "radius": 60, "color": Color("ff3322"), "desc": "一声虎吼震慑当面之敌，定身{v}秒动弹不得。", "effect": {"kind": "smite", "dmg": 120, "stun": 2}},
	"li_jun_q": {"name": "怒涛冲击", "cd": 9, "targeted": true, "radius": 50, "color": Color("9fd8ff"), "desc": "卷起一道急流冲砸目标，伤{v}、久缓其行并破其护甲。", "effect": {"kind": "smite", "dmg": 50, "slow": 0.55, "slow_dur": 4, "def_down": 3, "def_down_dur": 4}},
	"li_jun_w": {"name": "巨鲨甲", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "混江龙皮糙肉厚如鲨甲，气血雄厚、伤口自愈。", "effect": {"kind": "passive", "hp_add": 120, "regen": 3}},
	"li_jun_e": {"name": "猛锚横扫", "cd": 7, "targeted": false, "radius": 130, "color": Color("8fd3ff"), "desc": "抡起船锚横扫四周，劈伤{v}并削去敌甲。", "effect": {"kind": "smite", "dmg": 36, "def_down": 3, "def_down_dur": 6}},
	"li_jun_r": {"name": "翻江倒海", "cd": 40, "targeted": false, "radius": 320, "color": Color("6a4fb0"), "desc": "混江龙以身为漩搅动满江波涛：周遭敌军越多、浪头砸得越狠（每多一敌回响加伤），重创 {v} 并久震。", "effect": {"kind": "echo", "dmg": 70, "echo": 14, "stun": 1.8, "slow": 0.5, "slow_dur": 2}},
	"ruan_brother_q": {"name": "踏浪斩", "cd": 9, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "化作一道水线疾掠而过，沿途劈伤{v}。", "effect": {"kind": "charge", "dmg": 45, "windup": 0.3, "dist": 300, "width": 40}},
	"ruan_brother_w": {"name": "顺水推舟", "cd": 10, "targeted": true, "radius": 30, "color": Color("8fd3ff"), "desc": "顺势一推化作激流撞击目标，伤{v}并震晕。", "effect": {"kind": "smite", "dmg": 55, "stun": 1.4}},
	"ruan_brother_e": {"name": "形随水变", "cd": 14, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "身形如水般凝聚劲力，短时内平攻大增、攻击吸血。", "effect": {"kind": "self_buff", "atk_add": 14, "lifesteal": 0.4, "dur": 10}},
	"ruan_brother_r": {"name": "化形分身", "cd": 40, "targeted": true, "radius": 0, "color": Color("ffd24a"), "desc": "水中映出另一个自己并肩厮杀，承袭本体之力。", "effect": {"kind": "summon", "summon_kind": "copy", "count": 1, "copy_caster": true, "copy_mult": [0.6, 0.75, 0.9], "dur": 30, "unit": "dragon_summon"}},
	"zhang_heng_q": {"name": "水镜分身", "cd": 30, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "desc": "水面映出两道虚影，真假难辨一同搏杀。", "effect": {"kind": "summon", "summon_kind": "copy", "count": 2, "copy_caster": true, "copy_mult": [0.3, 0.4, 0.5], "dur": 30, "unit": "tiger_summon"}},
	"zhang_heng_w": {"name": "渔网缚敌", "cd": 12, "targeted": true, "radius": 30, "color": Color("a0e8c0"), "desc": "抛出渔网将一敌牢牢缚住，伤{v}并定身{v}秒。", "effect": {"kind": "smite", "dmg": 20, "stun": 2}},
	"zhang_heng_e": {"name": "急流拍岸", "cd": 8, "targeted": false, "radius": 110, "color": Color("8fd3ff"), "desc": "拍起急浪洗刷四周，伤{v}并冲薄敌甲。", "effect": {"kind": "smite", "dmg": 40, "def_down": 4, "def_down_dur": 5}},
	"zhang_heng_r": {"name": "海妖之歌", "cd": 45, "targeted": true, "radius": 0, "color": Color("6a4fb0"), "desc": "唱起摄魂船歌，范围内敌军昏沉入眠、动弹不得。", "effect": {"kind": "chrono", "dur": 5, "radius_ranks": [300, 330, 360]}},
	"ruan_xiaowu_q": {"name": "镖钉锁喉", "cd": 7, "targeted": true, "radius": 24, "color": Color("ffd24a"), "desc": "飞镖钉住目标咽喉，伤{v}并大幅迟滞其行。", "effect": {"kind": "smite", "dmg": 45, "slow": 0.5, "slow_dur": 3}},
	"ruan_xiaowu_w": {"name": "鬼魅突袭", "cd": 9, "targeted": true, "radius": 24, "color": Color("6a4fb0"), "desc": "鬼影般瞬掠至目标身畔，落处补伤{v}。", "effect": {"kind": "blink", "dist": 340, "dmg": 30, "radius": 24}},
	"ruan_xiaowu_e": {"name": "魅影迷踪", "cd": 0, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "passive": true, "desc": "身形虚渺难以瞄准，凭空闪躲来袭刀箭。", "effect": {"kind": "passive", "evasion": 0.1}},
	"ruan_xiaowu_r": {"name": "致命一击", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "短命二郎索命无情，出手偶得致命暴击，一击索魂。", "effect": {"kind": "passive", "crit_chance": 0.15, "crit_mult": 2.2}},
	"zhang_shun_q": {"name": "暗影契约", "cd": 8, "targeted": false, "radius": 100, "color": Color("6a4fb0"), "desc": "以身缠暗影净去缠身之毒，并向四周泼洒伤{v}。", "effect": {"kind": "smite", "dmg": 50}},
	"zhang_shun_w": {"name": "浪里扑食", "cd": 10, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "如鱼跃浪扑向落点，撞伤{v}并钉住当面之敌。", "effect": {"kind": "charge", "dmg": 40, "windup": 0.2, "dist": 280, "width": 36, "slow": 0.6, "slow_dur": 2}},
	"zhang_shun_e": {"name": "蚀魂", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "每击皆夺敌一分气力补己，越战越强、攻击吸血。", "effect": {"kind": "passive", "atk_add": 3, "lifesteal": 0.4}},
	"zhang_shun_r": {"name": "浪影潜形", "cd": 40, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "desc": "浪里白条潜形疾走，短时内移速、攻速与平攻俱涨。", "effect": {"kind": "atkspeed", "atkspeed": 1.5, "dur": 8, "speed_mult": 1.3, "self_atk": 1.3}},
	"ruan_xiaoqi_q": {"name": "亡魂脉冲", "cd": 8, "targeted": false, "radius": 160, "color": Color("6a4fb0"), "desc": "活阎罗放出一圈亡魂之气，灼伤四周敌军{v}。", "effect": {"kind": "smite", "dmg": 48}},
	"ruan_xiaoqi_w": {"name": "心绞之气", "cd": 12, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "周身弥漫绞心阴气，近身之敌持续掉血、形如索命。", "effect": {"kind": "black_rain", "follow": true, "dps_ranks": [8, 12, 16], "dur_ranks": [6, 6, 6], "dmg": 8, "dur": 6}},
	"ruan_xiaoqi_e": {"name": "残虐回生", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "见敌殒命便添己阳寿，气血更厚、伤愈极快。", "effect": {"kind": "passive", "regen": 4, "hp_add": 80}},
	"ruan_xiaoqi_r": {"name": "夺命镰刀", "cd": 45, "targeted": true, "radius": 40, "color": Color("ff3322"), "desc": "挥镰收魂重击一敌，伤{v}并定身{v}秒，残血者难逃。", "effect": {"kind": "smite", "dmg": 130, "stun": 2}},
	"yang_xiong_q": {"name": "吞噬", "cd": 14, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "病关索气吞山河，短时内平攻大涨、攻击重重吸血。", "effect": {"kind": "self_buff", "atk_add": 8, "lifesteal": 0.5, "dur": 12}},
	"yang_xiong_w": {"name": "焦土", "cd": 14, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "脚下燃起焦土随身炙烤，灼伤近敌并迟滞其行。", "effect": {"kind": "orbit_axes", "dmg": 14, "dur": 10, "tick": 0.5, "slow": 0.8, "slow_dur": 1}},
	"yang_xiong_e": {"name": "炼狱之刃", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "刀锋淬以业火，攻击附带灼伤，偶尔将敌震得目眩。", "effect": {"kind": "passive", "on_hit_dmg": 10, "bash_chance": 0.15, "bash_dur": 0.6}},
	"yang_xiong_r": {"name": "末日审判", "cd": 50, "targeted": true, "radius": 40, "color": Color("6a4fb0"), "desc": "判一敌入末日炼狱，长时灼烧并封其法术，求生不能。", "effect": {"kind": "smite", "dmg": 60, "dot_total": 240, "dot_dur": 12, "silence": 12}},
	"shi_xiu_q": {"name": "飞斧旋舞", "cd": 8, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "拼命三郎掷出旋斧扫向前方扇面，劈伤{v}并放缓众敌。", "effect": {"kind": "sector_nuke", "dmg": 40, "range": 200, "arc": 60, "slow": 0.7, "slow_dur": 1.5}},
	"shi_xiu_w": {"name": "盲目斧风", "cd": 9, "targeted": false, "radius": 120, "color": Color("ffd24a"), "desc": "近身抡斧搅起一片乱风，伤{v}并使四周敌人短时看不清、屡屡落空。", "effect": {"kind": "smite", "dmg": 36, "blind": 2}},
	"shi_xiu_e": {"name": "狂热", "cd": 0, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "passive": true, "desc": "拼命厮杀越打越快，连击不歇则出手如风。", "effect": {"kind": "passive", "atkspeed_add": 0.14}},
	"shi_xiu_r": {"name": "血战之志", "cd": 40, "targeted": false, "radius": 300, "color": Color("ff3322"), "desc": "一声血战令带动身边儿郎，攻速暴涨、平攻大增，杀红了眼。", "effect": {"kind": "atkspeed", "atkspeed": 1.6, "dur": 7, "allies": true, "radius": 300, "self_atk": 1.3}},
	"xie_zhen_q": {"name": "两头吞吐", "cd": 10, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "两头蛇一口冰一口火\n朝前喷出扇形毒焰，{v}伤害并减速", "effect": {"kind": "sector_nuke", "dmg": 38, "range": 200, "arc": 60, "slow": 0.55, "slow_dur": 2.5}},
	"xie_zhen_w": {"name": "寒蛇冰径", "cd": 11, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "吐出一道寒蛇冰径\n冻住踩上的官军，{v}伤害·阻路减速", "effect": {"kind": "ice_wall", "dmg": 30, "range": 150, "len": 160, "dur": 3}},
	"xie_zhen_e": {"name": "毒液灼骨", "cd": 9, "targeted": true, "radius": 70, "color": Color("a0e8c0"), "desc": "泼出毒蛇涎液\n落点官军{v}伤害，黏地续灼并迟缓", "effect": {"kind": "smite", "dmg": 28, "dot_total": 24, "dot_dur": 4, "slow": 0.6, "slow_dur": 3}},
	"xie_zhen_r": {"name": "双头烈焰阵", "cd": 34, "targeted": true, "radius": 60, "color": Color("ff5522"), "desc": "两头蛇朝指向喷出一线长焰焚尽来路\n地火沿直线延烧 8 秒，踏者每秒受灼", "effect": {"kind": "fire_line", "dps": 22, "dur": 8, "len": 340, "patch_r": 60}},
	"xie_bao_q": {"name": "穿地刺突", "cd": 11, "targeted": true, "radius": 60, "color": Color("d0a060"), "desc": "双尾蝎遁地猛冲\n钻出处沿途官军{v}伤害并被掀翻减速", "effect": {"kind": "charge", "dmg": 36, "windup": 0.4, "dist": 160, "width": 60, "slow": 0.5, "slow_dur": 2}},
	"xie_bao_w": {"name": "风沙蔽天", "cd": 12, "targeted": false, "radius": 110, "color": Color("c8a850"), "desc": "卷起漫天风沙裹身\n绕身狂沙持续{v}撕割并迷眼减速", "effect": {"kind": "orbit_axes", "dmg": 14, "slow": 0.55, "slow_dur": 1.5, "dur": 5, "tick": 0.5}},
	"xie_bao_e": {"name": "蝎尾余毒", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "被动·尾针淬毒\n每次劈砍附带蚀骨毒伤并拖慢敌身", "effect": {"kind": "passive", "on_hit_dmg": 10, "on_hit_slow": 0.7, "on_hit_slow_dur": 1.5}},
	"xie_bao_r": {"name": "穿地突刺", "cd": 30, "targeted": true, "radius": 0, "color": Color("e0a040"), "desc": "双尾蝎催动地龙贯线穿行\n沿途官军 {v} 重创、被地龙掀上半空僵立", "effect": {"kind": "line_nuke", "dmg": 40, "len": 300, "width": 56, "stun": 1.4}},
	"yan_qing_q": {"name": "烟障迷踪", "cd": 10, "targeted": true, "radius": 90, "color": Color("8a8a9a"), "desc": "撒一把迷烟障目\n范围官军{v}伤害·噤声闭口、挥刀难中", "effect": {"kind": "smite", "dmg": 18, "silence": 2.5, "blind": 2.5, "slow": 0.6, "slow_dur": 2.5}},
	"yan_qing_w": {"name": "燕青闪步", "cd": 7, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "浪子飘身一闪\n瞬现敌后给目标处{v}重击", "effect": {"kind": "blink", "dist": 170, "dmg": 40, "radius": 40}},
	"yan_qing_e": {"name": "背剑暗算", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "被动·相扑暗手\n身法飘忽善避，绕背一击屡屡致命", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.8, "evasion": 0.1}},
	"yan_qing_r": {"name": "隐入烟尘", "cd": 30, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "浪子隐入烟尘无影无踪\n敌军无法锁定，直到他出手；破隐背刺一击致命", "effect": {"kind": "invis", "dur": 8, "strike_bonus": 80}},
	"zhu_wu_q": {"name": "破法点穴", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "被动·神机破法\n指算如刀，每击焚去敌气并回补己身", "effect": {"kind": "passive", "on_hit_dmg": 12, "lifesteal": 0.4}},
	"zhu_wu_w": {"name": "踏罡步斗", "cd": 8, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "依阵图踏罡换位\n一步遁出落于指定阵眼", "effect": {"kind": "blink", "dist": 200, "dmg": 30.0}},
	"zhu_wu_e": {"name": "八阵护身", "cd": 12, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "布奇门遁甲护身\n结一道挡灾护罡，吸{v}伤害", "effect": {"kind": "shield", "shield": 180, "dur": 6}},
	"zhu_wu_r": {"name": "夺魂神机", "cd": 32, "targeted": true, "radius": 80, "color": Color("6a4fb0"), "desc": "算尽敌命门一击\n落点官军{v}雷霆爆杀并被定身", "effect": {"kind": "smite", "dmg": 120, "stun": 1.6}},
	"huang_xin_q": {"name": "镇山慑魄", "cd": 10, "targeted": true, "radius": 80, "color": Color("6a4fb0"), "desc": "镇三山一声厉喝\n落点官军{v}伤害·破甲削力士气尽丧", "effect": {"kind": "smite", "dmg": 22, "def_down": 6, "def_down_dur": 6, "slow": 0.6, "slow_dur": 3}},
	"huang_xin_w": {"name": "吸髓夺神", "cd": 9, "targeted": true, "radius": 55, "color": Color("8a3a6a"), "desc": "锁喉夺其精血\n目标处官军{v}重伤，回补自身血气", "effect": {"kind": "smite", "dmg": 48, "self_lifesteal": 1, "self_lifesteal_dur": 4}},
	"huang_xin_e": {"name": "黑甜噩梦", "cd": 12, "targeted": true, "target": "unit", "radius": 0, "color": Color("4a3a6a"), "desc": "掷一道梦魇黑焰缠上一将（单体指向）：{v} 伤并昏睡 2.2 秒僵立无措——点谁谁睡。", "effect": {"kind": "bolt", "dmg": 20, "stun": 2.2, "proj_speed": 440, "bolt_art": "dark"}},
	"huang_xin_r": {"name": "锁魂噩缚", "cd": 36, "targeted": true, "radius": 60, "color": Color("3a2a5a"), "desc": "十指扣魂死缚\n目标处官军{v}噬骨剧痛·禁声久缚动弹不得", "effect": {"kind": "smite", "dmg": 90, "stun": 2.6, "silence": 2.6}},
	"sun_li_q": {"name": "病尉迟掷鞭", "cd": 10, "targeted": true, "target": "unit", "radius": 0, "color": Color("d08050"), "desc": "钢鞭裹混沌之力掷向一将（单体指向）\n{v} 伤害·缠身眩晕 1.8 秒", "effect": {"kind": "bolt", "dmg": 40, "stun": 1.8, "proj_speed": 480}},
	"sun_li_w": {"name": "裂地突阵", "cd": 9, "targeted": true, "radius": 45, "color": Color("8a5fb0"), "desc": "撕开战阵瞬步贴敌\n现身落点{v}伤害·撕甲拖慢官军", "effect": {"kind": "blink", "dist": 160, "dmg": 32, "slow": 0.55, "slow_dur": 2.5}},
	"sun_li_e": {"name": "混世悍力", "cd": 0, "targeted": false, "radius": 0, "color": Color("d0a060"), "passive": true, "desc": "被动·尉迟蛮力\n钢鞭乱劈时有重击暴伤，并吮血回身", "effect": {"kind": "passive", "crit_chance": 0.12, "crit_mult": 1.7, "lifesteal": 0.5}},
	"sun_li_r": {"name": "登州马军幻阵", "cd": 38, "targeted": false, "radius": 0, "color": Color("9a6fd0"), "desc": "幻分数骑同形而战\n召出三道分身助阵{v}秒，齐冲乱敌", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 3, "summon_kind": "rider", "copy_caster": true, "copy_mult": [0.5, 0.55, 0.6], "dur": 22}},
	"xuan_zan_q": {"name": "顿马踏阵", "cd": 11, "targeted": false, "radius": 110, "color": Color("d0a060"), "desc": "丑郡马勒马顿蹄\n身边官军{v}伤害·铁蹄震得人仰马翻", "effect": {"kind": "smite", "dmg": 26, "stun": 1.6}},
	"xuan_zan_w": {"name": "郡马冲撞", "cd": 10, "targeted": true, "radius": 60, "color": Color("ff5522"), "desc": "丑郡马纵马猛冲一线\n沿途官军{v}撞伤·人仰马翻迟滞难行", "effect": {"kind": "charge", "dmg": 45, "windup": 0.4, "dist": 260, "width": 64, "slow": 0.5, "slow_dur": 2}},
	"xuan_zan_e": {"name": "铁骑反击", "cd": 0, "targeted": false, "radius": 0, "color": Color("c0a060"), "passive": true, "desc": "被动·郡马蛮筋\n体魄雄健生命大增，挨打必反震伤来犯者", "effect": {"kind": "passive", "hp_add": 120, "on_hit_dmg": 10}},
	"xuan_zan_r": {"name": "千骑奔腾", "cd": 34, "targeted": false, "radius": 220, "color": Color("ffd24a"), "desc": "号令全军纵马狂奔\n周围梁山兵移速暴涨{v}秒，踏平来路", "effect": {"kind": "haste", "speed_mult": 1.7, "dur": 6}},
	"hao_siwen_q": {"name": "霜爆破阵", "cd": 10, "targeted": true, "radius": 100, "color": Color("9fd8ff"), "desc": "井木犴呼出寒星\n落点炸开{v}冰伤，霜气漫地大减官军步速", "effect": {"kind": "smite", "dmg": 32, "slow": 0.5, "slow_dur": 3}},
	"hao_siwen_w": {"name": "寒冰锁体", "cd": 11, "targeted": true, "target": "unit", "radius": 0, "color": Color("9fd8ff"), "desc": "掷出玄冰珠冻缚一将（单体指向）：{v} 伤、冰枷缠足 1.8 秒动弹不得（仍可反击）、余寒续冻刺骨。", "effect": {"kind": "bolt", "dmg": 24, "dot_total": 30, "dot_dur": 3, "root": 1.8, "proj_speed": 430, "bolt_art": "ice"}},
	"hao_siwen_e": {"name": "玄机护气", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "被动·星宿护体\n气血绵长自愈不息，筋骨愈发坚厚", "effect": {"kind": "passive", "regen": 4, "hp_add": 100}},
	"hao_siwen_r": {"name": "极寒冰封原", "cd": 40, "targeted": false, "radius": 150, "color": Color("9fd8ff"), "desc": "周天寒气倾泻而下\n绕身极寒连环炸裂{v}，封冻整片官军", "effect": {"kind": "orbit_axes", "dmg": 18, "slow": 0.45, "slow_dur": 1.5, "dur": 5, "tick": 0.5}},
	"han_tao_q": {"name": "百胜枪贯阵", "cd": 8, "targeted": true, "radius": 0, "color": Color("3a3a4a"), "desc": "百胜将一枪荡出\n前方直线官军尽数{v}贯穿、势不可挡", "effect": {"kind": "line_nuke", "dmg": 40, "len": 180, "width": 60, "slow": 0.5, "slow_dur": 1.5}},
	"han_tao_w": {"name": "聚魂蓄锐", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "被动·摄魂炼锐\n每战吞噬亡魂，枪势日盛、枪尖噬血", "effect": {"kind": "passive", "atk_add": 4, "on_hit_dmg": 8}},
	"han_tao_e": {"name": "煞气慑敌", "cd": 10, "targeted": true, "radius": 100, "color": Color("4a3a5a"), "desc": "周身煞气压顶\n落点官军{v}伤害·甲胄崩裂胆气尽丧", "effect": {"kind": "smite", "dmg": 22, "def_down": 7, "def_down_dur": 6}},
	"han_tao_r": {"name": "群魂索命阵", "cd": 34, "targeted": false, "radius": 170, "color": Color("3a2a4a"), "desc": "尽放积蓄之亡魂\n四面群魂齐扑{v}爆杀，扑者皆被缠住迟滞", "effect": {"kind": "smite", "dmg": 32, "slow": 0.5, "slow_dur": 2.5, "stun": 0.8}},
	"peng_qi_q": {"name": "钩镰拖钩", "cd": 11, "targeted": true, "radius": 24, "color": Color("9a6a3a"), "desc": "甩出钩镰枪贯线而出，链条铮铮——钩中第一个敌人便 {v} 伤拖回身前，短暂踉跄任你处置。", "effect": {"kind": "hook", "dmg": 50, "len": 320, "width": 26, "stun": 0.8, "proj_speed": 540}},
	"peng_qi_w": {"name": "缠斗腐毒", "cd": 8, "targeted": false, "radius": 90, "color": Color("6a8f3a"), "desc": "周身瘴毒翻滚，近身者每跳受{v}腐伤并被拖滞。", "effect": {"kind": "orbit_axes", "dmg": 18, "slow": 0.7, "slow_dur": 0.4, "dur": 4, "tick": 0.5}},
	"peng_qi_e": {"name": "厚甲横肉", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("888888"), "passive": true, "desc": "杀伐越多血肉越厚，每级永久增{v}气血并缓缓自愈。", "effect": {"kind": "passive", "hp_add": 120, "regen": 1.5}},
	"peng_qi_r": {"name": "分筋断尸", "cd": 30, "targeted": true, "radius": 30, "color": Color("ff3322"), "desc": "擒住一敌将寸寸分解，{v}重伤兼定身，自身大量回吸血气。", "effect": {"kind": "smite", "dmg": 90, "stun": 2, "self_lifesteal": 0.8, "self_lifesteal_dur": 3}},
	"shan_tinggui_q": {"name": "圣水雷环", "cd": 8, "targeted": true, "radius": 240, "color": Color("8fd3ff"), "desc": "激水化雷扩成一环，环过处{v}伤并裹足难行。", "effect": {"kind": "smite", "dmg": 36, "slow": 0.6, "slow_dur": 1.5}},
	"shan_tinggui_w": {"name": "圣水连雷", "cd": 12, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "圣水将军引水为引、纵雷而出：雷光在敌群间逐个弹跳，每跳递减，初击 {v}。", "effect": {"kind": "chain_nuke", "dmg": 34, "jumps": 5, "jump": 180, "falloff": 0.85}},
	"shan_tinggui_e": {"name": "涌动疾雷", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "passive": true, "desc": "雷气贯体，每级被动增攻速并略提移速。", "effect": {"kind": "passive", "atkspeed_add": 0.12, "speed_mult": 1.06}},
	"shan_tinggui_r": {"name": "风暴之眼", "cd": 40, "targeted": false, "radius": 120, "color": Color("8fd3ff"), "desc": "召一片雷暴随身游走，域内敌将持续遭{v}雷击并迟缓。", "effect": {"kind": "orbit_axes", "dmg": 30, "slow": 0.7, "slow_dur": 0.5, "dur": 6, "tick": 0.8}},
	"wei_dingguo_q": {"name": "黏油神火", "cd": 7, "targeted": true, "radius": 110, "color": Color("ff7a2a"), "desc": "泼洒火油裹身，{v}伤并引燃成片地火，被沾者迟缓。", "effect": {"kind": "smite", "dmg": 30, "dot_total": 40, "dot_dur": 4, "slow": 0.7, "slow_dur": 1.5}},
	"wei_dingguo_w": {"name": "烈焰爆裂", "cd": 12, "targeted": true, "radius": 120, "color": Color("ff7a2a"), "desc": "掷火球轰然炸开，{v}伤将四周敌将震飞推离。", "effect": {"kind": "knockback", "dmg": 40, "push": 120, "radius": 120, "slow": 0.6, "slow_dur": 1.5}},
	"wei_dingguo_e": {"name": "火萤流", "cd": 16, "targeted": false, "radius": 100.0, "color": Color("ff7a2a"), "desc": "神火将军纵火驰骋，此后每行一步都在脚下落下一段地火，连成一条长燃火尾——官军追来踏入便持续受灼。", "effect": {"kind": "fire_trail", "dps_ranks": [14, 18, 22], "dur_ranks": [5, 6, 7], "drop": 0.3, "patch_dur": 2.0, "patch_r": 50}},
	"wei_dingguo_r": {"name": "火索擒拿", "cd": 30, "targeted": true, "radius": 24, "color": Color("ff3322"), "desc": "甩出火绳缚住一敌将拖至近前，{v}重伤兼长时定身。", "effect": {"kind": "pull", "dmg": 60, "len": 260, "width": 24, "pull_dist": 200, "stun": 2.5}},
	"xiao_rang_q": {"name": "圣手挥毫", "cd": 9, "targeted": true, "radius": 60, "color": Color("ffd24a"), "desc": "凝神蓄笔一挥而下，正气化光成线贯敌，沿途{v}伤。", "effect": {"kind": "line_nuke", "dmg": 55, "len": 300, "width": 60}},
	"xiao_rang_w": {"name": "灵泉回真", "cd": 12, "targeted": false, "radius": 200, "color": Color("a0e8c0"), "desc": "书符引灵泉普润，范围友军回{v}血并短时增攻。", "effect": {"kind": "rally", "heal": 90, "atk_mult": 1.2, "dur": 6}},
	"xiao_rang_e": {"name": "致盲圣光", "cd": 12, "targeted": true, "radius": 150, "color": Color("ffd24a"), "desc": "圣光暴绽，{v}伤将敌将逼退推离并裹足。", "effect": {"kind": "knockback", "dmg": 30, "push": 140, "radius": 150, "slow": 0.6, "slow_dur": 1.5}},
	"xiao_rang_r": {"name": "化灵神笔", "cd": 40, "targeted": false, "radius": 240, "color": Color("ffd24a"), "desc": "笔走龙蛇灵化全军，范围友军大幅增攻速与移速。", "effect": {"kind": "atkspeed", "atkspeed": 1.5, "allies": true, "radius": 240, "speed_mult": 1.2, "dur": 8}},
	"pei_xuan_q": {"name": "禁言判咒", "cd": 12, "targeted": true, "radius": 30, "color": Color("6a4fb0"), "desc": "落下判词封口，{v}伤并久久禁声，持续侵蚀心神。", "effect": {"kind": "smite", "dmg": 30, "silence": 3, "dot_total": 50, "dot_dur": 5}},
	"pei_xuan_w": {"name": "智慧之刃", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "passive": true, "desc": "胸藏律例化作锋刃，每次出手附加{v}法术真伤。", "effect": {"kind": "passive", "on_hit_dmg": 12, "atk_add": 3}},
	"pei_xuan_e": {"name": "一言定谳", "cd": 14, "targeted": true, "target": "unit", "radius": 0, "color": Color("6a4fb0"), "desc": "铁面孔目当庭点名定谳（单体指向）：判词化墨直贯其口，{v} 伤并禁声 4 秒不得施法。", "effect": {"kind": "bolt", "dmg": 40, "silence": 4, "proj_speed": 520, "bolt_art": "dark"}},
	"pei_xuan_r": {"name": "满堂封口", "cd": 45, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "铁面孔目当堂拍案封禁——【全图】敌将 {v} 伤并长久哑然不能施法，任他天涯海角一体禁声。", "effect": {"kind": "global_nuke", "dmg": 40, "heroes_only": true, "silence": 5}},
	"ou_peng_q": {"name": "金翅噬甲", "cd": 10, "targeted": true, "radius": 120, "color": Color("a0e8c0"), "desc": "放出群羽附敌啃啮，{v}伤并破甲减防，持续蚀肉。", "effect": {"kind": "smite", "dmg": 30, "def_down": 3, "def_down_dur": 6, "dot_total": 30, "dot_dur": 6}},
	"ou_peng_w": {"name": "金翅掠袭", "cd": 9, "targeted": true, "radius": 60, "color": Color("9fd8ff"), "desc": "摩云金翅俯身掠地疾冲一线，沿途之敌 {v} 撞伤、翼风扫得踉跄难行。", "effect": {"kind": "charge", "dmg": 40, "windup": 0.3, "dist": 300, "width": 60, "slow": 0.4, "slow_dur": 1.5}},
	"ou_peng_e": {"name": "双星连击", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "passive": true, "desc": "翼速倍添，被动增攻速且每击附加{v}真伤。", "effect": {"kind": "passive", "atkspeed_add": 0.12, "on_hit_dmg": 8}},
	"ou_peng_r": {"name": "时光回溯", "cd": 40, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "desc": "逆抚光阴护住己身，化出{v}护盾抵御一切伤害数息。", "effect": {"kind": "shield", "shield": 220, "dur": 5}},
	"deng_fei_q": {"name": "连珠链弹", "cd": 12, "targeted": false, "radius": 90, "color": Color("ff7a2a"), "desc": "周身迸射铁弹幕，近敌每跳遭{v}伤并被滞步。", "effect": {"kind": "orbit_axes", "dmg": 16, "slow": 0.8, "slow_dur": 0.3, "dur": 5, "tick": 0.4}},
	"deng_fei_w": {"name": "齿轮囚笼", "cd": 12, "targeted": true, "radius": 100, "color": Color("888888"), "desc": "立起铁齿围栏，{v}伤将冲撞的敌将弹退困住。", "effect": {"kind": "knockback", "dmg": 20, "push": 100, "radius": 100, "stun": 0.5}},
	"deng_fei_e": {"name": "火眼信炮", "cd": 16, "targeted": false, "radius": 100.0, "color": Color("ff7a2a"), "desc": "火眼狻猊纵观全场，一炮轰落全图敌军各受{v}伤。", "effect": {"kind": "global_nuke", "dmg": 40, "heroes_only": false}},
	"deng_fei_r": {"name": "钩索擒将", "cd": 30, "targeted": true, "radius": 24, "color": Color("ff7a2a"), "desc": "甩出长钩远索一敌将拖近，{v}伤兼定身锁喉。", "effect": {"kind": "pull", "dmg": 60, "len": 340, "width": 24, "pull_dist": 340, "stun": 1.5}},
	"yan_shun_q": {"name": "唤啸双虎", "cd": 12, "targeted": false, "radius": 100.0, "color": Color("a0e8c0"), "desc": "锦毛虎长啸召出两头猛兽随阵厮杀，伴战许久。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "tiger", "hp": [260, 320, 380], "atk": [22, 26, 30], "dur": 40}},
	"yan_shun_w": {"name": "虎啸号令", "cd": 14, "targeted": false, "radius": 220, "color": Color("ffd24a"), "desc": "一声虎吼壮全军胆气，范围友军增攻并回{v}血。", "effect": {"kind": "rally", "heal": 40, "atk_mult": 1.3, "dur": 8}},
	"yan_shun_e": {"name": "野性嗜血", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "passive": true, "desc": "兽血贲张，每级被动增攻、附吸血并略提暴击。", "effect": {"kind": "passive", "atk_add": 3, "lifesteal": 0.4, "crit_chance": 0.06}},
	"yan_shun_r": {"name": "化身猛虎", "cd": 40, "targeted": false, "radius": 100.0, "color": Color("ff7a2a"), "desc": "锦毛虎现兽形真身 14 秒：平攻大涨、出手如风、身法迅疾，扑咬撕裂势不可挡（变身·到期还原）。", "effect": {"kind": "transform", "dur": 14, "form": {"atk_mult": 1.5, "atk_cd_mult": 0.6, "speed_mult": 1.35, "radius": 15.0, "tint": Color(1.35, 0.85, 0.6)}}},
	"yang_lin_q": {"name": "飞镖手里剑", "cd": 9, "targeted": true, "radius": 30, "color": Color("8fd3ff"), "desc": "暗掷飞镖锁喉，{v}伤并令敌将一瞬眩晕。", "effect": {"kind": "smite", "dmg": 45, "stun": 0.6}},
	"yang_lin_w": {"name": "暗袭杀机", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("444466"), "passive": true, "desc": "豹子身手，被动附暴击且时而一击重创使其踉跄。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.8, "bash_chance": 0.12, "bash_dur": 0.5}},
	"yang_lin_e": {"name": "影行潜踪", "cd": 12, "targeted": true, "radius": 100.0, "color": Color("444466"), "desc": "隐身疾掠潜至落点，现身一击{v}伤，来去无影。", "effect": {"kind": "blink", "dist": 300, "dmg": 30}},
	"yang_lin_r": {"name": "追踪标记", "cd": 30, "targeted": false, "radius": 240, "color": Color("ffd24a"), "desc": "锁定猎物号令同袍合围，范围友军大幅提速穷追不舍。", "effect": {"kind": "haste", "speed_mult": 1.25, "dur": 12}},
	"ling_zhen_q": {"name": "轰天连炮", "cd": 13, "targeted": true, "radius": 110, "color": Color("ff7a2a"), "desc": "凌振架炮引导，连番轰击落点战场：每半秒落弹一轮，每轮 {v} 伤并减速逃敌——引导中不能动，被眩晕/沉默即止。", "effect": {"kind": "channel", "dur": 3.0, "tick": 0.5, "dmg": 22, "slow": 0.5, "slow_dur": 1.2}},
	"ling_zhen_w": {"name": "机关定身", "cd": 11, "targeted": true, "radius": 80, "color": Color("8fd3ff"), "desc": "暗设机括，踏中者被困定身 1.6 秒，受伤 {v}。", "effect": {"kind": "smite", "dmg": 20, "stun": 1.6}},
	"ling_zhen_e": {"name": "引爆轰身", "cd": 14, "targeted": true, "radius": 70, "color": Color("ff3322"), "desc": "舍身近爆，烈焰伤 {v}，震得敌将耳鸣口噤、3 秒不能施法。", "effect": {"kind": "smite", "dmg": 70, "silence": 3}},
	"ling_zhen_r": {"name": "架设神炮", "cd": 40, "targeted": true, "radius": 40, "color": Color("ff7a2a"), "desc": "轰天雷在落点架起一门神炮：自行锁定最近官军连珠轰击 {v}——阵地战的看家火力。", "effect": {"kind": "ward", "ward_mode": "attack", "ward_style": "death", "ward_radius": 280, "pulse": 0.5, "dmg_ranks": [24, 32, 42], "ward_dur": 10}},
	"jiang_jing_q": {"name": "神算珠", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "神算子运筹于算珠，每击附带玄奥真气，额外法伤 {v}。", "effect": {"kind": "passive", "on_hit_dmg": 12}},
	"jiang_jing_w": {"name": "心算崩击", "cd": 9, "targeted": true, "radius": 100, "color": Color("6a4fb0"), "desc": "推演敌阵破绽，一算定崩，范围法伤 {v}。", "effect": {"kind": "smite", "dmg": 50}},
	"jiang_jing_e": {"name": "星界囚牢", "cd": 12, "targeted": true, "radius": 40, "color": Color("9fd8ff"), "desc": "将敌将摄入星界囚困 2 秒，出狱时受伤 {v}。", "effect": {"kind": "smite", "dmg": 40, "stun": 2}},
	"jiang_jing_r": {"name": "神算月蚀", "cd": 40, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "蒋敬掐指通天，月蚀降临，全场敌将同遭天算，法伤 {v}。", "effect": {"kind": "global_nuke", "dmg": 50, "heroes_only": true}},
	"lu_fang_q": {"name": "群势压顶", "cd": 9, "targeted": true, "radius": 110, "color": Color("ffd24a"), "desc": "小温侯方天画戟横扫成群之敌，敌越众伤越重，伤 {v} 并减速。", "effect": {"kind": "smite", "dmg": 45, "slow": 0.6, "slow_dur": 2}},
	"lu_fang_w": {"name": "趁势猛攻", "cd": 12, "targeted": false, "radius": 130, "color": Color("a0e8c0"), "desc": "鼓舞袍泽乘胜追击，范围友军回血 {v} 并增攻 5 秒。", "effect": {"kind": "rally", "heal": 60, "atk_mult": 1.3, "dur": 5}},
	"lu_fang_e": {"name": "临阵骁勇", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "越战越勇，受创之际反激杀意，平攻附带 40% 吸血。", "effect": {"kind": "passive", "lifesteal": 0.4}},
	"lu_fang_r": {"name": "单挑", "cd": 30, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "吕方戟指点将，纵马冲阵直取敌酋，撞伤 {v} 并锁住其步。", "effect": {"kind": "charge", "dmg": 100, "windup": 0.3, "dist": 130, "width": 36, "slow": 0.5, "slow_dur": 2}},
	"guo_sheng_q": {"name": "画戟投枪", "cd": 9, "targeted": true, "radius": 0, "color": Color("ffd24a"), "desc": "赛仁贵掷戟如电，贯穿一线之敌，伤 {v} 钉敌减速。", "effect": {"kind": "line_nuke", "dmg": 55, "len": 220, "width": 34, "slow": 0.5, "slow_dur": 1.5}},
	"guo_sheng_w": {"name": "神戟回击", "cd": 8, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "戟锋前扫一记神威回击，扇面斩伤 {v} 并迟滞来敌。", "effect": {"kind": "sector_nuke", "dmg": 45, "range": 120, "arc": 120, "slow": 0.5, "slow_dur": 1.5}},
	"guo_sheng_e": {"name": "铁壁", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "披甲执戟自成壁垒，临敌沉稳，10% 几率闪避来袭。", "effect": {"kind": "passive", "evasion": 0.1}},
	"guo_sheng_r": {"name": "血斗之环", "cd": 40, "targeted": true, "radius": 160, "color": Color("ff3322"), "desc": "戟列成环困敌于内，环壁撞退群敌、撞伤 {v} 并震晕。", "effect": {"kind": "knockback", "dmg": 50, "push": 90, "radius": 160, "stun": 1.5}},
	"an_daoquan_q": {"name": "毒手点穴", "cd": 10, "targeted": true, "radius": 0, "color": Color("a0e8c0"), "desc": "神医反用医术点敌经脉，一线封穴，伤 {v} 并重缓其行。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 200, "width": 30, "slow": 0.5, "slow_dur": 2.5}},
	"an_daoquan_w": {"name": "救命浅坟", "cd": 14, "targeted": false, "radius": 120, "color": Color("ffd24a"), "desc": "施回春续命之术，为范围友军罩上 {v} 护体真气并解去缠身控制减益（神医解控），垂死可救。", "effect": {"kind": "shield", "shield": 180, "dur": 5, "allies": true, "radius": 120, "dispel": "debuffs"}},
	"an_daoquan_e": {"name": "影波", "cd": 8, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "desc": "神医自身起波，一道波纹在敌我之间往复弹跳——撞到官军灼伤 {v}，掠过弟兄则同量回血，于乱战中边伤敌边救死扶伤。", "effect": {"kind": "heal_wave", "dmg": 40, "heal": 40, "jumps": 6, "jump": 150}},
	"an_daoquan_r": {"name": "编织", "cd": 40, "targeted": true, "radius": 220, "color": Color("6a4fb0"), "desc": "安道全暗运歧黄之毒交织战场，大范围持续削敌护甲。", "effect": {"kind": "smite", "dmg": 10, "def_down": 3, "def_down_dur": 12}},
	"huangfu_duan_q": {"name": "苦修", "cd": 10, "targeted": true, "radius": 50, "color": Color("6a4fb0"), "desc": "紫髯伯以驯兽鞭笞缚敌，伤 {v}、迟其步并破其甲 4 秒。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.5, "slow_dur": 4, "def_down": 2, "def_down_dur": 4}},
	"huangfu_duan_w": {"name": "神驹召唤", "cd": 24, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "皇甫端善相马驯兽，唤来山林猛兽两头助阵厮杀。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "tiger", "hp": [300, 360, 420], "atk": [22, 26, 30], "dur": 35}},
	"huangfu_duan_e": {"name": "天恩", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "通晓兽性亦解人病，自身气血绵绵自复，每秒回血 {v}。", "effect": {"kind": "passive", "regen": 4}},
	"huangfu_duan_r": {"name": "神手回春", "cd": 40, "targeted": false, "radius": 300, "color": Color("ffd24a"), "desc": "妙手回春之术普被三军，全场友军同沐生机、回血 {v} 并振奋。", "effect": {"kind": "rally", "heal": 160, "atk_mult": 1.2, "dur": 4}},
	"wang_ying_q": {"name": "烈焰冲击", "cd": 9, "targeted": true, "radius": 60, "color": Color("ff7a2a"), "desc": "矮脚虎一掌拍出烈焰，轰伤 {v} 并震晕敌将 1.6 秒。", "effect": {"kind": "smite", "dmg": 50, "stun": 1.6}},
	"wang_ying_w": {"name": "燎原之火", "cd": 11, "targeted": true, "radius": 90, "color": Color("ff3322"), "desc": "矮脚虎把火油泼上落点，地面烈焰久燃不熄——5 秒累计灼伤 {v}，站在火里的官军插翅难逃。", "effect": {"kind": "fire_dot", "dmg": 90, "dur": 5}},
	"wang_ying_e": {"name": "嗜血术", "cd": 14, "targeted": false, "radius": 130, "color": Color("ff3322"), "desc": "为范围友军灌注狂血，出手如风、奔走如电，攻速移速大涨。", "effect": {"kind": "atkspeed", "atkspeed": 1.5, "dur": 12, "allies": true, "radius": 130, "speed_mult": 1.2}},
	"wang_ying_r": {"name": "多重施法", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "粗中有灵，时而妙手连发，平攻 12% 几率暴起重击。", "effect": {"kind": "passive", "crit_chance": 0.12, "crit_mult": 1.5}},
	"hu_sanniang_q": {"name": "飞索打将", "cd": 9, "targeted": true, "radius": 50, "color": Color("8fd3ff"), "desc": "一丈青甩出红锦套索擒将，缚伤 {v} 并震晕 1.6 秒。", "effect": {"kind": "smite", "dmg": 50, "stun": 1.6}},
	"hu_sanniang_w": {"name": "红锦套索", "cd": 12, "targeted": true, "target": "unit", "radius": 0, "color": Color("ff5a7a"), "desc": "掷出红锦套索直取一将（单体指向）：索到便 {v} 伤、缚身眩晕 1.4 秒、卸其护甲 8 秒。", "effect": {"kind": "bolt", "dmg": 30, "stun": 1.4, "def_down": 3, "def_down_dur": 8, "proj_speed": 460, "bolt_art": "lasso"}},
	"hu_sanniang_e": {"name": "复仇光环", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "巾帼煞气贯于阵中，激励左右袍泽平攻同涨 {v}。", "effect": {"kind": "passive", "atk_add": 4}},
	"hu_sanniang_r": {"name": "乾坤挪移", "cd": 30, "targeted": true, "target": "unit", "unit_team": "any", "radius": 0, "color": Color("9fd8ff"), "desc": "扈三娘索法通神，与目标瞬间互换位置（敌我皆可点）——可把敌将换进阵中围杀 {v}，也可把残血袍泽换出险地。", "effect": {"kind": "swap", "dmg": 50, "stun": 0.9, "cast_range": 480}},
	"bao_xu_q": {"name": "静电残影", "cd": 7, "targeted": false, "radius": 90, "color": Color("8fd3ff"), "desc": "丧门神留下一道带电残影，触之即炸，环身电伤 {v}。", "effect": {"kind": "smite", "dmg": 45}},
	"bao_xu_w": {"name": "电磁旋涡", "cd": 14, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "卷起电磁漩涡将敌将吸入旋心，定身 1.5 秒、伤 {v}。", "effect": {"kind": "pull", "dmg": 20, "len": 200, "width": 40, "pull_dist": 150, "stun": 1.5}},
	"bao_xu_e": {"name": "超负荷", "cd": 0, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "passive": true, "desc": "周身雷电过载，平攻附带电击额外伤 {v} 并迟滞其行。", "effect": {"kind": "passive", "on_hit_dmg": 10, "on_hit_slow": 0.6, "on_hit_slow_dur": 1}},
	"bao_xu_r": {"name": "球状闪电", "cd": 30, "targeted": true, "radius": 110, "color": Color("8fd3ff"), "desc": "鲍旭化作一团滚雷掠地飞袭，骤现敌阵、落点炸伤 {v} 并减速。", "effect": {"kind": "blink", "dist": 400, "dmg": 60, "slow": 0.6, "slow_dur": 1.5, "radius": 110}},
	"fan_rui_q": {"name": "影蛊毒雾", "cd": 8, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "撒落幽冥毒雾，敌军踏入持续中毒蚀骨，每秒掉血 {v}。", "effect": {"kind": "fire_dot", "dps": 14, "dur": 5, "dmg": 20}},
	"fan_rui_w": {"name": "摄魂咒", "cd": 10, "targeted": true, "radius": 110, "color": Color("6a4fb0"), "desc": "勾摄敌魂烙下易伤咒印，范围官军受创 {v}、抹去其护盾增益，并在 6 秒内受到的一切伤害大增三成——配合群攻成片收割。", "effect": {"kind": "smite", "dmg": 30, "amp": 0.3, "amp_dur": 6, "slow": 0.4, "slow_dur": 2, "dispel": "buffs"}},
	"fan_rui_e": {"name": "幽冥放逐", "cd": 9, "targeted": true, "radius": 90, "color": Color("8a5fd0"), "desc": "一道魔气将敌将打入幽冥，定身昏厥 {v} 秒。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.4}},
	"fan_rui_r": {"name": "魔王降世", "cd": 30, "targeted": true, "radius": 160, "color": Color("ff3322"), "desc": "混世魔王现形，邪火洗地：重创、减速并持续焚魂。", "effect": {"kind": "smite", "dmg": 60, "slow": 0.5, "slow_dur": 4, "dot_total": 120, "dot_dur": 5}},
	"kong_ming_q": {"name": "火凤俯冲", "cd": 10, "targeted": true, "radius": 60, "color": Color("ff7a2a"), "desc": "化作赤凤掠空俯冲，沿途焚灼敌军并拖慢其步。", "effect": {"kind": "charge", "dmg": 45, "windup": 0.4, "dist": 180, "width": 60, "slow": 0.6, "slow_dur": 2}},
	"kong_ming_w": {"name": "三昧灵火", "cd": 9, "targeted": true, "radius": 110, "color": Color("ff9a3a"), "desc": "放出灵火精魄，黏附敌身持续灼烧。", "effect": {"kind": "smite", "dmg": 30, "dot_total": 80, "dot_dur": 4}},
	"kong_ming_e": {"name": "赤乌天炎", "cd": 11, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "引一线赤日烈焰前射，贯穿灼伤一线之敌。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 200, "width": 50}},
	"kong_ming_r": {"name": "凤鸣超新星", "cd": 32, "targeted": false, "radius": 160, "color": Color("ff3322"), "desc": "毛头星化炎日凝丹，骤然炸裂，灼遍四方并震慑敌军。", "effect": {"kind": "smite", "dmg": 55, "stun": 2}},
	"kong_liang_q": {"name": "焦炼锁链", "cd": 9, "targeted": true, "radius": 100, "color": Color("ff7a2a"), "desc": "甩出灼热火链缠住敌人，定身焚烧。", "effect": {"kind": "smite", "dmg": 35, "stun": 1.2, "dot_total": 50, "dot_dur": 3}},
	"kong_liang_w": {"name": "残影连斩", "cd": 10, "targeted": true, "radius": 120, "color": Color("ff9a3a"), "desc": "独火星化残影瞬掠，落点一片刀光斩尽群敌。", "effect": {"kind": "blink", "dist": 200, "dmg": 40, "radius": 120}},
	"kong_liang_e": {"name": "烈焰护体", "cd": 12, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "周身腾起火罩，化作护盾抵御来犯。", "effect": {"kind": "shield", "shield": 160, "dur": 5}},
	"kong_liang_r": {"name": "炎魂残烬", "cd": 28, "targeted": true, "radius": 50, "color": Color("ff3322"), "desc": "留火为引，纵身长驱猛冲，烬火扫荡一线之敌。", "effect": {"kind": "charge", "dmg": 50, "windup": 0.2, "dist": 240, "width": 50}},
	"xiang_chong_q": {"name": "缚兽镖", "cd": 11, "targeted": true, "radius": 80, "color": Color("a0e8c0"), "desc": "掷出索镖将敌缚于原地，昏厥动弹不得。", "effect": {"kind": "smite", "dmg": 30, "stun": 1.6}},
	"xiang_chong_w": {"name": "穿云箭", "cd": 9, "targeted": true, "radius": 0, "color": Color("ffd24a"), "desc": "蓄力一记劲射，箭破长空贯穿一线之敌。", "effect": {"kind": "line_nuke", "dmg": 55, "len": 220, "width": 36}},
	"xiang_chong_e": {"name": "疾风步", "cd": 12, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "御风疾行，身法暴涨如飞。", "effect": {"kind": "haste", "speed_mult": 1.5, "dur": 4}},
	"xiang_chong_r": {"name": "八臂连珠", "cd": 30, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "八臂哪吒附身，连珠急击，攻速暴涨平攻倍增。", "effect": {"kind": "atkspeed", "atkspeed": 1.7, "dur": 6, "self_atk": 1.4}},
	"li_gun_q": {"name": "火龙箭", "cd": 8, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "射出一道火龙之箭，烈焰直线席卷敌阵。", "effect": {"kind": "line_nuke", "dmg": 45, "len": 220, "width": 40}},
	"li_gun_w": {"name": "烈焰天罡", "cd": 10, "targeted": true, "radius": 90, "color": Color("ff9a3a"), "desc": "落点天罡烈焰骤起，灼伤并震慑其中之敌。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.5}},
	"li_gun_e": {"name": "焚心", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "passive": true, "desc": "心火不熄，每施法身手愈快，攻势如烈焰升腾。", "effect": {"kind": "passive", "atkspeed_add": 0.14, "speed_mult": 1.04}},
	"li_gun_r": {"name": "天火神雷", "cd": 35, "targeted": true, "target": "unit", "radius": 0, "color": Color("ff3322"), "desc": "飞天大圣引天火神雷直贯一将（单体指向）：雷光追身而至，重创 {v}——躲无可躲的点名绝杀。", "effect": {"kind": "bolt", "dmg": 120, "proj_speed": 620}},
	"jin_dajian_q": {"name": "镜钢激光", "cd": 9, "targeted": true, "radius": 60, "color": Color("8fd3ff"), "desc": "玉臂匠以磨镜钢反射烈光灼敌，强光致其睁眼难视、屡射不中。", "effect": {"kind": "smite", "dmg": 35, "blind": 2.5}},
	"jin_dajian_w": {"name": "追魂火箭", "cd": 8, "targeted": true, "radius": 70, "color": Color("ff9a3a"), "desc": "巧造追魂火箭自寻敌将，凌空轰落。", "effect": {"kind": "smite", "dmg": 45}},
	"jin_dajian_e": {"name": "机关械阵", "cd": 11, "targeted": true, "radius": 130, "color": Color("8fd3ff"), "desc": "布下机关械阵，铁械纵横绞杀踏入之敌。", "effect": {"kind": "fire_dot", "dps": 16, "dur": 5, "dmg": 15}},
	"jin_dajian_r": {"name": "重整军械", "cd": 30, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "一夜赶造，军械重整，机关连发攻势如潮。", "effect": {"kind": "atkspeed", "atkspeed": 1.8, "dur": 6, "self_atk": 1.5}},
	"ma_lin_q": {"name": "铁笛乱刺", "cd": 9, "targeted": true, "radius": 0, "color": Color("ffd24a"), "desc": "铁笛仙连环突刺，一线之敌尽遭剑笛点穴。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 180, "width": 44}},
	"ma_lin_w": {"name": "盾撞", "cd": 11, "targeted": true, "radius": 120, "color": Color("8fd3ff"), "desc": "纵身盾撞落地，震开四周敌军并拖慢其步。", "effect": {"kind": "knockback", "dmg": 35, "push": 120, "radius": 120, "slow": 0.6, "slow_dur": 2}},
	"ma_lin_e": {"name": "幸运一击", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "笛声暗藏杀机，平攻偶有幸运重击震慑敌人。", "effect": {"kind": "passive", "bash_chance": 0.18, "bash_dur": 0.8, "on_hit_dmg": 8}},
	"ma_lin_r": {"name": "滚地惊雷", "cd": 30, "targeted": true, "radius": 60, "color": Color("8fd3ff"), "desc": "蜷身成球滚地如雷，长驱碾压并拖滞沿途之敌。", "effect": {"kind": "charge", "dmg": 55, "windup": 0.3, "dist": 260, "width": 60, "slow": 0.5, "slow_dur": 2}},
	"tong_wei_q": {"name": "蛟龙出水", "cd": 10, "targeted": true, "radius": 90, "color": Color("9fd8ff"), "desc": "出洞蛟破水而起，掀浪击敌，定身昏厥。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.5}},
	"tong_wei_w": {"name": "妖法易形", "cd": 12, "targeted": true, "radius": 80, "color": Color("6a4fb0"), "desc": "施一道妖法乱敌心智，使其封口缄声、步履迟滞。", "effect": {"kind": "smite", "dmg": 25, "silence": 2, "slow": 0.5, "slow_dur": 2}},
	"tong_wei_e": {"name": "噬魂", "cd": 11, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "吞噬敌魂滋养己身，一段时间内攻击大幅吸血。", "effect": {"kind": "self_buff", "atk_add": 0, "lifesteal": 1.2, "dur": 6}},
	"tong_wei_r": {"name": "断魂指", "cd": 34, "targeted": true, "radius": 30, "color": Color("ff3322"), "desc": "一指断魂，单点倾泻死亡之力，敌将魂飞魄散。", "effect": {"kind": "smite", "dmg": 130}},
	"tong_meng_q": {"name": "翻江雷", "cd": 9, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "翻江蜃唤出一道连环水雷，逐敌弹击层层击晕。", "effect": {"kind": "chain_nuke", "dmg": 35, "jumps": 4, "jump": 120, "falloff": 0.8, "stun": 0.3}},
	"tong_meng_w": {"name": "妖蜃幻形", "cd": 12, "targeted": true, "target": "unit", "unit_team": "enemy", "radius": 0, "color": Color("6a4fb0"), "desc": "蜃气幻形，指定一名敌将变作一团蠢物 2.5 秒：不能施法、不能挥兵、寸步难行（仍可反击）——单体点控。", "effect": {"kind": "smite", "dmg": 25, "hex": 2.5}},
	"tong_meng_e": {"name": "锁蛟枷", "cd": 11, "targeted": true, "radius": 60, "color": Color("9fd8ff"), "desc": "锁枷加身，长缚敌将，重创且久久昏厥。", "effect": {"kind": "smite", "dmg": 50, "stun": 2}},
	"tong_meng_r": {"name": "群蛇阵", "cd": 32, "targeted": true, "radius": 90, "color": Color("a0e8c0"), "desc": "唤起满潭群蛇助阵，蜿蜒齐出咬噬来犯之敌。", "effect": {"kind": "summon", "unit": "dragon_summon", "count": 4, "summon_kind": "serpent", "hp": [80, 120, 160], "atk": [14, 18, 22], "dur": 20}},
	"meng_kang_q": {"name": "连珠火箭", "cd": 8, "targeted": false, "radius": 110, "color": Color("ff7a2a"), "desc": "玉幡竿身藏火铳，绕身倾泻火箭如雨，持续灼烧周遭近敌，每跳伤 {v}。", "effect": {"kind": "orbit_axes", "dmg": 14, "dur": 3, "tick": 0.35, "slow": 0.85, "slow_dur": 0.4}},
	"meng_kang_w": {"name": "追命导弹", "cd": 11, "targeted": true, "radius": 70, "color": Color("ffb347"), "desc": "锁定一处放出追命火弹，命中炸开 {v} 点伤并震晕来敌。", "effect": {"kind": "smite", "dmg": 55, "stun": 1.4}},
	"meng_kang_e": {"name": "高射散花", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "炮管改作高射连发，每次普攻溅射周遭群敌，额外造成 {v} 伤，出手更疾。", "effect": {"kind": "passive", "on_hit_dmg": 9, "atkspeed_add": 0.1}},
	"meng_kang_r": {"name": "天降神火", "cd": 32, "targeted": true, "radius": 150, "color": Color("ff5a1a"), "desc": "玉幡竿唤来神火覆压指定战阵：火雨倾泻数息、持续烧灼 {v}——覆盖阵地的空袭。", "effect": {"kind": "black_rain", "dps_ranks": [18, 22, 26], "dur_ranks": [5, 6, 7], "dmg": 50, "dur": 6}},
	"hou_jian_q": {"name": "麻沸散弹", "cd": 9, "targeted": true, "radius": 80, "color": Color("6a4fb0"), "desc": "通臂猿掷出麻沸药囊，在敌阵间弹跳爆开，逐个震晕，每跳伤 {v}。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 4, "jump": 90, "falloff": 0.9, "stun": 0.9}},
	"hou_jian_w": {"name": "巫祝回春", "cd": 10, "targeted": false, "radius": 130, "color": Color("a0e8c0"), "desc": "默念蛮巫祷词，持续为周遭义军回复气血，每息 {v}。", "effect": {"kind": "rally", "heal": 22, "atk_mult": 1, "dur": 4}},
	"hou_jian_e": {"name": "恶咒缠身", "cd": 11, "targeted": true, "radius": 90, "color": Color("8a3ffb"), "desc": "诅咒一片敌军，咒力持续蚀骨，咒终引爆累计伤害，总伤 {v}。", "effect": {"kind": "smite", "dmg": 20, "dot_total": 80, "dot_dur": 4}},
	"hou_jian_r": {"name": "死神之眼", "cd": 40, "targeted": true, "radius": 260, "color": Color("ff3322"), "desc": "通臂猿立起一尊噬魂木桩，原地飞快连珠射击射程内最近的官军，存续 8 秒间箭无虚发。", "effect": {"kind": "ward", "ward_mode": "attack", "ward_style": "death", "ward_radius": 260, "pulse": 0.4, "dmg_ranks": [22, 30, 40], "ward_dur": 8}},
	"chen_da_q": {"name": "穿地枪", "cd": 9, "targeted": true, "radius": 80, "color": Color("c08a3a"), "desc": "跳涧虎枪势破土，钉穿正前一线敌军，重伤 {v} 并将其牢牢钉死。", "effect": {"kind": "smite", "dmg": 50, "stun": 1.6}},
	"chen_da_w": {"name": "夺气一击", "cd": 8, "targeted": true, "radius": 60, "color": Color("8fd3ff"), "desc": "一枪挑散敌将气力，伤 {v} 并令其短促失声难施招法。", "effect": {"kind": "smite", "dmg": 38, "silence": 1.6}},
	"chen_da_e": {"name": "倒竖甲刺", "cd": 12, "targeted": false, "radius": 0, "color": Color("b5b5b5"), "desc": "周身甲刺反竖，结起护体硬壳吸伤 {v}，挡下迎面攻势。", "effect": {"kind": "shield", "shield": 160, "dur": 4}},
	"chen_da_r": {"name": "暗影夺命", "cd": 34, "targeted": true, "radius": 70, "color": Color("3a2a55"), "desc": "遁入暗影掠至猎物身侧，骤起致命一击，落点重创 {v} 并减速。", "effect": {"kind": "blink", "dist": 260, "dmg": 110, "slow": 0.5, "slow_dur": 2, "radius": 70}},
	"yang_chun_q": {"name": "分梢箭", "cd": 0, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "passive": true, "desc": "白花蛇箭法分梢，一矢化数羽齐发，普攻溅伤旁敌额外 {v}，射程更远。", "effect": {"kind": "passive", "on_hit_dmg": 8, "range_add": 12}},
	"yang_chun_w": {"name": "灵蛇穿珠", "cd": 9, "targeted": true, "radius": 80, "color": Color("6fd86a"), "desc": "放出灵蛇于敌群间游走啮咬，逐跳吞噬，每跳伤 {v}。", "effect": {"kind": "chain_nuke", "dmg": 36, "jumps": 5, "jump": 95, "falloff": 1}},
	"yang_chun_e": {"name": "鳞甲护身", "cd": 13, "targeted": false, "radius": 0, "color": Color("7fe0d0"), "desc": "白鳞凝成护体软甲，吸收来袭伤害 {v}，临阵不溃。", "effect": {"kind": "shield", "shield": 200, "dur": 5}},
	"yang_chun_r": {"name": "石化凝睇", "cd": 36, "targeted": false, "radius": 200, "color": Color("9fb0c0"), "desc": "蛇瞳一睁，正面之敌僵立石化，重伤 {v} 并定身减速。", "effect": {"kind": "smite", "dmg": 48, "stun": 2, "slow": 0.5, "slow_dur": 3}},
	"zheng_tianshou_q": {"name": "锁魂咒", "cd": 9, "targeted": true, "radius": 70, "color": Color("6a4fb0"), "desc": "白面郎君指处魂锁加身，敌将反复僵直，受创 {v} 且寸步难移。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.8, "slow": 0.5, "slow_dur": 2}},
	"zheng_tianshou_w": {"name": "役鬼成军", "cd": 11, "targeted": false, "radius": 0, "color": Color("5a3f8a"), "desc": "摄魄炼出数只役鬼随阵厮杀，各携利刃 {v}，分敌火力。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "eidolon", "hp": [120, 150, 180], "atk": [18, 24, 30], "dur": 12}},
	"zheng_tianshou_e": {"name": "子夜阴脉", "cd": 12, "targeted": true, "radius": 160, "color": Color("4a2f6a"), "desc": "在敌阵下布开一片阴脉，立身其上者按命数持续蚀血，每息 {v}。", "effect": {"kind": "fire_dot", "dps": 16, "dur": 5, "dmg": 8}},
	"zheng_tianshou_r": {"name": "黑煞天坑", "cd": 42, "targeted": true, "radius": 150, "color": Color("1f1430"), "desc": "撕开吞天黑坑，将范围之敌尽数吸入定死，持续眩晕动弹不得。", "effect": {"kind": "chrono", "dur": 4, "radius_ranks": [130, 160, 190]}},
	"tao_zongwang_q": {"name": "黏胶污泥", "cd": 8, "targeted": true, "radius": 90, "color": Color("9a8a3a"), "desc": "九尾龟甩出黏胶污泥糊住敌军，伤 {v}、减速并削其护甲。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.55, "slow_dur": 3, "def_down": 3, "def_down_dur": 4}},
	"tao_zongwang_w": {"name": "掘地裂沟", "cd": 12, "targeted": true, "radius": 0, "color": Color("a0a060"), "desc": "九尾龟抡起铁锹贯线掘地：沿线之敌 {v} 伤震翻，掘出的土垄挡路 3.5 秒——断后路的活城墙。", "effect": {"kind": "fissure", "dmg": 38, "len": 300, "width": 40, "stun": 1.0, "slow": 0.5, "slow_dur": 2, "wall_dur": 3.5}},
	"tao_zongwang_e": {"name": "倒竖背甲", "cd": 0, "targeted": false, "radius": 0, "color": Color("6f6f4a"), "passive": true, "desc": "背甲倒竖卸去来势，体魄愈坚，增血 {v}、回血加速且常有硬甲弹开攻击。", "effect": {"kind": "passive", "hp_add": 120, "regen": 2, "evasion": 0.08}},
	"tao_zongwang_r": {"name": "战意如潮", "cd": 30, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "越战越勇杀意翻涌，出手骤疾且平攻大增，自身攻击力升至 {v} 倍。", "effect": {"kind": "atkspeed", "atkspeed": 1.7, "dur": 8, "self_atk": 1.5}},
	"song_qing_q": {"name": "命断飞符", "cd": 8, "targeted": true, "radius": 70, "color": Color("ffd24a"), "desc": "铁扇子掷出止行飞符，钉住敌将令其滞步，伤 {v} 并减速。", "effect": {"kind": "smite", "dmg": 36, "slow": 0.45, "slow_dur": 2.5}},
	"song_qing_w": {"name": "命数敕令", "cd": 10, "targeted": true, "radius": 80, "color": Color("e0b84a"), "desc": "一道天命敕令封住敌手招法，使其失声 {v} 息，且更易受创。", "effect": {"kind": "smite", "dmg": 18, "silence": 2, "def_down": 4, "def_down_dur": 3}},
	"song_qing_e": {"name": "净世炎息", "cd": 7, "targeted": false, "radius": 130, "color": Color("a0e8c0"), "desc": "焚去周遭义军伤痛，持续疗复气血，每息回 {v}、攻势略振。", "effect": {"kind": "rally", "heal": 26, "atk_mult": 1.1, "dur": 4}},
	"song_qing_r": {"name": "虚妄之诺", "cd": 38, "targeted": false, "radius": 150, "color": Color("fff0b0"), "desc": "许下虚妄之诺，为濒危义军罩上厚护，吸尽来袭重伤 {v}。", "effect": {"kind": "shield", "shield": 240, "dur": 5, "allies": true, "radius": 150}},
	"yue_he_q": {"name": "霰珠齐喷", "cd": 8, "targeted": true, "radius": 0, "color": Color("ff7a2a"), "desc": "铁叫子喷出一面火霰扇，正前敌军尽数中弹，近身者更被震退，伤 {v}。", "effect": {"kind": "sector_nuke", "dmg": 40, "range": 150, "arc": 60, "slow": 0.55, "slow_dur": 2}},
	"yue_he_w": {"name": "火爆酥饼", "cd": 11, "targeted": true, "radius": 70, "color": Color("ffb347"), "desc": "塞一枚火爆酥饼蹬地腾跃，落处轰开 {v} 伤并震得敌阵迟滞。", "effect": {"kind": "blink", "dist": 220, "dmg": 45, "slow": 0.5, "slow_dur": 1.8, "radius": 70}},
	"yue_he_e": {"name": "连珠铁哨", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "铁哨连吹催阵，出手如连珠般密，攻速提升并附加 {v} 灼伤。", "effect": {"kind": "passive", "atkspeed_add": 0.14, "on_hit_dmg": 7}},
	"yue_he_r": {"name": "天火长轰", "cd": 36, "targeted": true, "radius": 150, "color": Color("ff5a1a"), "desc": "唤来连绵火弹自天倾落指定战场，烈焰长燃灼烤群敌，每息 {v}。", "effect": {"kind": "black_rain", "follow": false, "dps_ranks": [22, 28, 34], "dur_ranks": [4, 4.5, 5], "dmg": 10, "dur": 4.5}},
	"gong_wang_q": {"name": "蜂群破阵", "cd": 8, "targeted": true, "radius": 0, "color": Color("6a4fb0"), "desc": "花项虎驱出虫蜂沿直线啮敌穿阵，贯穿一线敌军，伤 {v}。", "effect": {"kind": "line_nuke", "dmg": 42, "len": 200, "width": 70}},
	"gong_wang_w": {"name": "噤声咒", "cd": 11, "targeted": true, "radius": 130, "color": Color("5a3f8a"), "desc": "一道噤声咒压住敌阵，使范围内将士失声难施法，伤 {v}。", "effect": {"kind": "smite", "dmg": 30, "silence": 3}},
	"gong_wang_e": {"name": "灵魂虹吸", "cd": 9, "targeted": true, "radius": 90, "color": Color("a04fb0"), "desc": "牵起一道魂索抽敌补己，伤 {v}、减速，并令自身一时大幅吸血。", "effect": {"kind": "smite", "dmg": 28, "slow": 0.55, "slow_dur": 2.5, "self_lifesteal": 0.8, "self_lifesteal_dur": 4}},
	"gong_wang_r": {"name": "群妖出巡", "cd": 40, "targeted": false, "radius": 0, "color": Color("8a3ffb"), "desc": "放出成群索命妖灵随身扑敌撕咬，各击伤 {v}，存续片刻横扫战场。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 5, "summon_kind": "spirit", "hp": [90, 110, 130], "atk": [22, 28, 34], "dur": 10}},
	"ding_desun_q": {"name": "烈焰怒喝", "cd": 11, "targeted": false, "radius": 110, "color": Color("ff7a2a"), "desc": "丁得孙怒吼震退四周敌军，灼烧并将其撞开 {v}。", "effect": {"kind": "knockback", "dmg": 44, "push": 120, "radius": 110, "slow": 0.6, "slow_dur": 1.5}},
	"ding_desun_w": {"name": "燃魂飞标", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ff5522"), "passive": true, "desc": "暗器淬火，每记飞标命中皆附额外焚伤，越战越烈。", "effect": {"kind": "passive", "on_hit_dmg": 11, "atkspeed_add": 0.05}},
	"ding_desun_e": {"name": "搏命狂血", "cd": 14, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "desc": "丁得孙以血搏命，伤势愈重出手愈疾，攻速暴涨并大幅吸血。", "effect": {"kind": "atkspeed", "atkspeed": 1.7, "dur": 6, "self_atk": 1.3}},
	"ding_desun_r": {"name": "舍身突阵", "cd": 28, "cd_ranks": [28, 24, 20], "targeted": true, "radius": 80, "color": Color("ff3322"), "desc": "拼却性命纵身扑入敌阵，依目标气血造成重创 {v}。", "effect": {"kind": "charge", "dmg": 120, "windup": 0.3, "dist": 240, "width": 70, "slow": 0.55, "slow_dur": 2}},
	"mu_chun_q": {"name": "擒拿摔打", "cd": 11, "targeted": true, "radius": 60, "color": Color("ffd24a"), "desc": "穆春一把擒住敌将猛掼于身前，落地砸眩并震伤周围 {v}。", "effect": {"kind": "pull", "dmg": 50, "len": 220, "width": 60, "pull_dist": 200, "stun": 1}},
	"mu_chun_w": {"name": "踏壁腾跃", "cd": 13, "targeted": true, "radius": 80, "color": Color("a0e8c0"), "desc": "借势踏壁腾身扑向落点，将敌撞翻在地 {v}。", "effect": {"kind": "charge", "dmg": 46, "windup": 0.2, "dist": 260, "width": 80, "stun": 0.8}},
	"mu_chun_e": {"name": "并肩助拳", "cd": 16, "targeted": false, "radius": 100.0, "color": Color("a0e8c0"), "desc": "穆春鼓气助阵，自身一段时间内平攻加重并附吸血。", "effect": {"kind": "self_buff", "atk_add": 5, "lifesteal": 0.6, "dur": 7}},
	"mu_chun_r": {"name": "怒拳如雨", "cd": 30, "cd_ranks": [30, 26, 22], "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "desc": "小遮拦放开手脚，连珠快拳暴起，攻速骤增刀刀凶狠。", "effect": {"kind": "atkspeed", "atkspeed": 1.8, "dur": 6, "self_atk": 1.4}},
	"cao_zheng_q": {"name": "幽冥爆", "cd": 8, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "曹正掷出阴煞之力轰然炸裂，焚伤落点周遭敌军 {v}。", "effect": {"kind": "smite", "dmg": 50, "slow": 0.65, "slow_dur": 1.5}},
	"cao_zheng_w": {"name": "朽骨咒", "cd": 12, "targeted": true, "radius": 90, "color": Color("6a4fb0"), "desc": "邪咒缠身，目标筋骨朽软、护甲尽失且行动迟缓 {v}。", "effect": {"kind": "smite", "dmg": 28, "def_down": 6, "def_down_dur": 4, "slow": 0.55, "slow_dur": 3, "silence": 1.5}},
	"cao_zheng_e": {"name": "镇魂阵", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("6a4fb0"), "passive": true, "desc": "曹正立阵安魂，元气绵绵自复，气血缓缓回升。", "effect": {"kind": "passive", "regen": 3, "hp_add": 60}},
	"cao_zheng_r": {"name": "放血引魂", "cd": 26, "cd_ranks": [26, 22, 18], "targeted": false, "radius": 0, "color": Color("6a4fb0"), "desc": "操刀鬼自身起刃，一道血光在敌我之间往复弹跳——割敌 {v}、掠过弟兄则同量补血，屠户的手艺救人也杀人。", "effect": {"kind": "heal_wave", "dmg": 60, "heal": 60, "jumps": 5, "jump": 160}},
	"song_wan_q": {"name": "震地顿踏", "cd": 10, "targeted": false, "radius": 130, "color": Color("ffd24a"), "desc": "云里金刚一脚顿地，回声震荡四周敌军当场昏厥 {v}。", "effect": {"kind": "smite", "dmg": 36, "stun": 1.4}},
	"song_wan_w": {"name": "魂魄附身", "cd": 14, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "desc": "宋万放出元神助战，归位时威势倍增，平攻加重一时。", "effect": {"kind": "self_buff", "atk_add": 4, "lifesteal": 0.3, "dur": 8}},
	"song_wan_e": {"name": "天地法度", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "passive": true, "desc": "宋万立威慑场，凡近其身之敌护甲自损、抗性尽削。", "effect": {"kind": "passive", "hp_add": 100, "on_hit_dmg": 6}},
	"song_wan_r": {"name": "裂地天罡", "cd": 30, "cd_ranks": [30, 26, 22], "targeted": true, "radius": 60, "color": Color("ffd24a"), "desc": "金刚奋力劈地，一道地裂直贯而出洞穿当路敌阵 {v}。", "effect": {"kind": "line_nuke", "dmg": 90, "len": 320, "width": 90, "slow": 0.5, "slow_dur": 2.5}},
	"du_qian_q": {"name": "怒撞冲阵", "cd": 11, "targeted": true, "radius": 70, "color": Color("ff7a2a"), "desc": "摸着天挟万钧之势猛冲而出，把当路敌军尽数撞翻 {v}。", "effect": {"kind": "charge", "dmg": 48, "windup": 0.4, "dist": 260, "width": 70, "stun": 0.9}},
	"du_qian_w": {"name": "践踏碾压", "cd": 13, "targeted": false, "radius": 100, "color": Color("ff7a2a"), "desc": "杜迁原地腾跃猛踩，脚下方圆持续翻地碾压敌军 {v}。", "effect": {"kind": "orbit_axes", "dmg": 16, "slow": 0.6, "slow_dur": 1, "dur": 4, "tick": 0.5}},
	"du_qian_e": {"name": "暴怒之躯", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "passive": true, "desc": "受创愈深则怒火愈盛，皮糙肉厚硬挡刀枪。", "effect": {"kind": "passive", "hp_add": 120, "regen": 2, "evasion": 0.06}},
	"du_qian_r": {"name": "擂捶镇杀", "cd": 32, "cd_ranks": [32, 28, 24], "targeted": true, "radius": 60, "color": Color("ff3322"), "desc": "杜迁攥住敌将拳如擂鼓连砸，砸得对手长跪不起 {v}。", "effect": {"kind": "smite", "dmg": 110, "stun": 2.6}},
	"xue_yong_q": {"name": "折光护身", "cd": 12, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "desc": "薛永以幻影折光卸去来犯之力，护体之余出手更狠 {v}。", "effect": {"kind": "self_buff", "atk_add": 6, "lifesteal": 0.2, "dur": 8}},
	"xue_yong_w": {"name": "灵刃透甲", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "passive": true, "desc": "病大虫刀走偏锋，刃气穿透甲胄并溅及身后之敌。", "effect": {"kind": "passive", "on_hit_dmg": 10, "atk_add": 3}},
	"xue_yong_e": {"name": "潜形伏击", "cd": 13, "targeted": true, "radius": 50, "color": Color("6a4fb0"), "desc": "薛永隐身瞬掠至落点，一击破其护甲再骤然现身 {v}。", "effect": {"kind": "blink", "dist": 280, "dmg": 60, "radius": 50, "slow": 0.6, "slow_dur": 1.5}},
	"xue_yong_r": {"name": "灵纹陷阱", "cd": 28, "cd_ranks": [28, 24, 20], "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "病大虫预设灵纹机阵，落点炸裂重创并死死缚住敌军 {v}。", "effect": {"kind": "smite", "dmg": 80, "slow": 0.45, "slow_dur": 3.5, "def_down": 5, "def_down_dur": 3}},
	"shi_en_q": {"name": "淬毒连击", "cd": 10, "targeted": true, "radius": 100, "color": Color("6a4fb0"), "desc": "金眼彪喷出毒雾染指落点，敌军中毒迟滞、血脉久燃 {v}。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.6, "slow_dur": 3, "dot_total": 36, "dot_dur": 4}},
	"shi_en_w": {"name": "毒瘴桩", "cd": 14, "targeted": true, "radius": 0, "color": Color("6a4fb0"), "desc": "施恩在落点插下毒瘴桩：持续朝最近的官军喷吐毒射 {v} 并拖慢其行——守口扼道的毒哨。", "effect": {"kind": "ward", "ward_mode": "poison", "ward_style": "poison", "ward_radius": 220, "pulse": 0.5, "dmg_ranks": [12, 18, 24], "slow": 0.5, "slow_dur": 1.5, "dur_ranks": [8, 10, 12]}},
	"shi_en_e": {"name": "毒鳞护体", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("6a4fb0"), "passive": true, "desc": "金眼彪一身毒鳞，刀枪难入，触之者反受毒蚀而迟缓。", "effect": {"kind": "passive", "evasion": 0.1, "on_hit_slow": 0.7, "on_hit_slow_dur": 1.5, "regen": 2}},
	"shi_en_r": {"name": "毒蟒噬命", "cd": 26, "cd_ranks": [26, 22, 18], "targeted": true, "radius": 60, "color": Color("6a4fb0"), "desc": "施恩一口剧毒咬定单敌，剧痛锁身、毒发攻心绵绵不绝 {v}。", "effect": {"kind": "smite", "dmg": 70, "slow": 0.35, "slow_dur": 5, "dot_total": 80, "dot_dur": 5}},
	"li_zhong_q": {"name": "寒冰断墙", "cd": 11, "targeted": true, "radius": 0, "color": Color("9fd8ff"), "desc": "打虎将横推一道寒冰，封堵去路、伤敌减速 {v}。", "effect": {"kind": "ice_wall", "dmg": 36, "range": 120, "len": 180, "dur": 4}},
	"li_zhong_w": {"name": "滚雪冲撞", "cd": 13, "targeted": true, "radius": 70, "color": Color("9fd8ff"), "desc": "李忠裹身成团滚雪猛撞，把当头之敌撞个仰面朝天 {v}。", "effect": {"kind": "charge", "dmg": 46, "windup": 0.3, "dist": 260, "width": 70, "stun": 1.2}},
	"li_zhong_e": {"name": "并力同搏", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("9fd8ff"), "passive": true, "desc": "打虎将与同袍并肩搏杀，出拳带寒、刀刀更沉。", "effect": {"kind": "passive", "on_hit_dmg": 9, "on_hit_slow": 0.85, "on_hit_slow_dur": 1}},
	"li_zhong_r": {"name": "虎拳轰天", "cd": 30, "cd_ranks": [30, 26, 22], "targeted": true, "radius": 80, "color": Color("ff7a2a"), "desc": "李忠一记盖世重拳轰中敌将，连人带势轰飞老远 {v}。", "effect": {"kind": "knockback", "dmg": 100, "push": 160, "radius": 80, "stun": 1.6, "slow": 0.5, "slow_dur": 2}},
	"zhou_tong_q": {"name": "月华一击", "cd": 8, "targeted": true, "radius": 50, "color": Color("8fd3ff"), "desc": "小霸王一道皎月光华自天而落，砸中敌将令其昏厥 {v}。", "effect": {"kind": "smite", "dmg": 52, "stun": 1}},
	"zhou_tong_w": {"name": "回旋月刃", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "passive": true, "desc": "周通刀作弯月，去而复返，一刀可连斩数敌。", "effect": {"kind": "passive", "atk_add": 3, "crit_chance": 0.08, "crit_mult": 1.6}},
	"zhou_tong_e": {"name": "月色相助", "cd": 0, "targeted": false, "radius": 100.0, "color": Color("8fd3ff"), "passive": true, "desc": "夜战月明，周通借月色策马更疾、刀风更利。", "effect": {"kind": "passive", "atk_add": 2, "speed_mult": 1.08, "atkspeed_add": 0.06}},
	"zhou_tong_r": {"name": "月蚀乱箭", "cd": 28, "cd_ranks": [28, 24, 20], "targeted": false, "radius": 220, "color": Color("8fd3ff"), "desc": "小霸王召满天月华暴落，乱光弹射连击四周群敌 {v}。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 7, "jump": 180, "falloff": 0.92, "stun": 0.4}},
	"tang_long_q": {"name": "钩镰试锋", "cd": 10, "targeted": true, "radius": 24, "color": Color("b0b0c0"), "desc": "打造钩镰枪的巧匠亲自试锋：钩头贯线飞出，钩中第一个敌人 {v} 伤拖回身前——自家兵器自家最熟。", "effect": {"kind": "hook", "dmg": 45, "len": 300, "width": 26, "stun": 0.7, "proj_speed": 520}},
	"tang_long_w": {"name": "勾镰索", "cd": 10, "targeted": true, "radius": 0, "color": Color("b0b0c0"), "desc": "抛出铁索勾住远处，汤隆借力疾冲，撞伤沿途之敌。", "effect": {"kind": "blink", "dist": 200, "dmg": 30}},
	"tang_long_e": {"name": "反应重甲", "cd": 0, "targeted": false, "radius": 0, "color": Color("8a8f9a"), "passive": true, "desc": "近身受击越多甲越厚，持续回复气血、增厚体魄。", "effect": {"kind": "passive", "hp_add": 90, "regen": 3}},
	"tang_long_r": {"name": "飞轮锯", "cd": 30, "targeted": false, "radius": 150, "color": Color("ff7a2a"), "desc": "祭出大锯轮绕身狂转，持续切割并迟滞周围敌军。", "effect": {"kind": "orbit_axes", "dmg": 30, "slow": 0.6, "slow_dur": 1.5, "dur": 6, "tick": 0.5}},
	"du_xing_q": {"name": "残影摄魂", "cd": 9, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "留下虚空残影，触者被摄回原地并受 {v} 伤、步伐迟滞。", "effect": {"kind": "smite", "dmg": 45, "slow": 0.5, "slow_dur": 2}},
	"du_xing_w": {"name": "虚空步", "cd": 8, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "鬼脸儿身形一晃，瞬移至落点，神出鬼没。", "effect": {"kind": "blink", "dist": 200, "dmg": 30.0}},
	"du_xing_e": {"name": "回响震", "cd": 12, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "desc": "虚空之力凝成护体气罩，吸收一段伤害。", "effect": {"kind": "shield", "shield": 160, "dur": 6}},
	"du_xing_r": {"name": "星界突袭", "cd": 28, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "踏星界长距突进，落点炸开 {v} 重伤并迟滞群敌。", "effect": {"kind": "blink", "dist": 260, "dmg": 90, "radius": 120, "slow": 0.5, "slow_dur": 1.5}},
	"zou_yuan_q": {"name": "镜影摄魄", "cd": 8, "targeted": true, "radius": 200, "color": Color("6a4fb0"), "desc": "出林龙映出敌影，范围内敌军受 {v} 伤且步履凝滞。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.5, "slow_dur": 3}},
	"zou_yuan_w": {"name": "幻形分身", "cd": 11, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "幻化两道魔影助战，复刻本体一部分战力。", "effect": {"kind": "summon", "unit": "tiger_summon", "summon_kind": "image", "count": 2, "copy_caster": true, "copy_mult": [0.3, 0.35, 0.4], "dur": 20}},
	"zou_yuan_e": {"name": "恶魔之变", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff3322"), "passive": true, "desc": "显化恶魔之躯，攻力大增、攻速更疾、出手更远。", "effect": {"kind": "passive", "atk_add": 4, "range_add": 60, "atkspeed_add": 0.1}},
	"zou_yuan_r": {"name": "魔血逆转", "cd": 40, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "催动魔血贪噬，短时内平攻暴涨、吸敌之血还己。", "effect": {"kind": "self_buff", "atk_add": 8, "lifesteal": 1.2, "dur": 8}},
	"zou_run_q": {"name": "疾风连射", "cd": 10, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "独角龙凝神疾射，短时内出手如风、攻速暴增。", "effect": {"kind": "atkspeed", "atkspeed": 1.6, "dur": 5}},
	"zou_run_w": {"name": "灼魂箭", "cd": 0, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "passive": true, "desc": "箭簇淬以阴火，每记平攻附带焚魂之伤。", "effect": {"kind": "passive", "on_hit_dmg": 10}},
	"zou_run_e": {"name": "骷髅潜行", "cd": 9, "targeted": false, "radius": 0, "color": Color("a0e8c0"), "desc": "化作枯骨潜行，身形飘忽、移速大增以绕后突袭。", "effect": {"kind": "haste", "speed_mult": 1.4, "dur": 6}},
	"zou_run_r": {"name": "焚天骷髅军", "cd": 35, "targeted": false, "radius": 0, "color": Color("ff7a2a"), "desc": "召出数名焚火骷髅弓手，齐射助阵一段时辰。", "effect": {"kind": "summon", "unit": "tiger_summon", "summon_kind": "skeleton", "count": 4, "hp": [120, 150, 180], "atk": [18, 22, 26], "dur": 18}},
	"zhu_gui_q": {"name": "焦土烈火", "cd": 9, "targeted": true, "radius": 150, "color": Color("ff7a2a"), "desc": "旱地忽律点燃一片焦土，立其上者持续受 {v} 焚伤。", "effect": {"kind": "fire_dot", "dps": 14, "dur": 6, "dmg": 20}},
	"zhu_gui_w": {"name": "恶念深渊", "cd": 12, "targeted": true, "radius": 180, "color": Color("6a4fb0"), "desc": "凿开恶念之坑，范围敌军受伤、迟滞且被封口噤声。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.55, "slow_dur": 3, "silence": 2.5}},
	"zhu_gui_e": {"name": "枯萎光环", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "周身弥散枯萎之气，自身愈发壮硕、攻力日增。", "effect": {"kind": "passive", "atk_add": 3, "hp_add": 80}},
	"zhu_gui_r": {"name": "地狱之门", "cd": 40, "targeted": false, "radius": 260, "color": Color("ff3322"), "desc": "洞开地狱之门集结友军，范围回血并加成攻击。", "effect": {"kind": "rally", "heal": 120, "atk_mult": 1.3, "dur": 8}},
	"zhu_fu_q": {"name": "判命一笔", "cd": 8, "targeted": true, "radius": 0, "color": Color("6a4fb0"), "desc": "笑面虎挥墨成锋，直线笔走龙蛇，贯穿之敌受 {v} 伤并迟滞。", "effect": {"kind": "line_nuke", "dmg": 45, "len": 280, "width": 60, "slow": 0.5, "slow_dur": 1.5}},
	"zhu_fu_w": {"name": "鬼影缠身", "cd": 11, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "放出墨鬼缠住目标，受伤迟滞且开不得口。", "effect": {"kind": "smite", "dmg": 40, "silence": 3, "slow": 0.5, "slow_dur": 2}},
	"zhu_fu_e": {"name": "墨涌护体", "cd": 12, "targeted": false, "radius": 200, "color": Color("9fd8ff"), "desc": "墨气翻涌，为周围友军罩上吸伤护盾。", "effect": {"kind": "shield", "shield": 160, "dur": 6, "allies": true, "radius": 200}},
	"zhu_fu_r": {"name": "锁魂咒", "cd": 28, "targeted": true, "radius": 0, "color": Color("ff3322"), "desc": "墨链锁魂逐个连缚，弹跳数次造成 {v} 伤并定身。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 4, "jump": 240, "falloff": 0.85, "stun": 1}},
	"cai_fu_q": {"name": "裂地", "cd": 9, "targeted": true, "radius": 160, "color": Color("ff7a2a"), "desc": "铁臂膊一掌震地裂开，范围敌军受 {v} 伤并被掀翻定身。", "effect": {"kind": "smite", "dmg": 40, "stun": 1.4}},
	"cai_fu_w": {"name": "天谴敕令", "cd": 10, "targeted": false, "radius": 200, "color": Color("8fd3ff"), "desc": "诵动天谴敕令，周身炸开雷光重创近敌。", "effect": {"kind": "smite", "dmg": 36}},
	"cai_fu_e": {"name": "霹雳风暴", "cd": 8, "targeted": true, "radius": 0, "color": Color("8fd3ff"), "desc": "召来霹雳连环跳跃，逐个劈击并迟滞敌人。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 4, "jump": 220, "falloff": 0.9, "slow": 0.5, "slow_dur": 1}},
	"cai_fu_r": {"name": "脉冲新星", "cd": 26, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "周身雷光一波波脉冲外涌，持续灼伤并迟滞群敌。", "effect": {"kind": "orbit_axes", "dmg": 28, "slow": 0.6, "slow_dur": 1, "dur": 7, "tick": 0.6}},
	"cai_qing_q": {"name": "夺命弹", "cd": 9, "targeted": true, "radius": 0, "color": Color("ff3322"), "desc": "一枝花一枪贯出，直线撕裂沿途敌军 {v} 伤并迟滞。", "effect": {"kind": "line_nuke", "dmg": 45, "len": 260, "width": 50, "slow": 0.5, "slow_dur": 2}},
	"cai_qing_w": {"name": "亡魂追命弹", "cd": 11, "targeted": true, "target": "unit", "radius": 0, "color": Color("6a4fb0"), "desc": "一枝花放出一缕亡魂黑焰追缠一将（单体指向）：{v} 伤并慑其心神、久久迟滞。", "effect": {"kind": "bolt", "dmg": 45, "slow": 0.55, "slow_dur": 2.5, "proj_speed": 470, "bolt_art": "dark"}},
	"cai_qing_e": {"name": "快枪手", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffd24a"), "passive": true, "desc": "枪法如神，平攻常有二连击与致命爆射。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.5, "on_hit_dmg": 8}},
	"cai_qing_r": {"name": "破帷", "cd": 30, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "撕开生死之帷化作幽魂态，短时攻力暴涨、弹弹吸血。", "effect": {"kind": "self_buff", "atk_add": 7, "lifesteal": 0.6, "dur": 8}},
	"li_li_q": {"name": "夺命阴风", "cd": 8, "targeted": true, "radius": 120, "color": Color("6a4fb0"), "desc": "催命判官放出阴风夺其魂气，敌受 {v} 伤且步履凝滞。", "effect": {"kind": "smite", "dmg": 30, "slow": 0.5, "slow_dur": 3}},
	"li_li_w": {"name": "摄魂印", "cd": 11, "targeted": true, "radius": 140, "color": Color("6a4fb0"), "desc": "烙下摄魂之印，目标甲胄崩坏、易于伤损。", "effect": {"kind": "smite", "dmg": 35, "def_down": 3, "def_down_dur": 6}},
	"li_li_e": {"name": "墓守斗篷", "cd": 0, "targeted": false, "radius": 0, "color": Color("8a8f9a"), "passive": true, "desc": "裹一袭墓守斗篷，体魄渐厚、善避锋芒、缓缓自愈。", "effect": {"kind": "passive", "hp_add": 90, "evasion": 0.08, "regen": 2}},
	"li_li_r": {"name": "石像鬼", "cd": 40, "targeted": false, "radius": 0, "color": Color("ff3322"), "desc": "唤出两尊石像鬼俯冲助战，一段时辰内随判官索命。", "effect": {"kind": "summon", "unit": "dragon_summon", "summon_kind": "familiar", "count": 2, "hp": [160, 200, 240], "atk": [20, 24, 28], "dur": 25}},
	"li_yun_q": {"name": "暗噬", "cd": 9, "targeted": true, "target": "unit", "radius": 0, "color": Color("3a2f6a"), "desc": "青眼虎掷出暗影毒囊咬定一将（单体指向）：{v} 伤、大幅迟滞并短暂呆立。", "effect": {"kind": "bolt", "dmg": 50, "slow": 0.5, "slow_dur": 3, "stun": 0.6, "proj_speed": 480, "bolt_art": "dark"}},
	"li_yun_w": {"name": "夺魄威", "cd": 12, "targeted": false, "radius": 200, "color": Color("5a4a8a"), "desc": "身周敌军被青眼虎的杀气慑住，受 {v} 伤并被噤声无法施技。", "effect": {"kind": "smite", "dmg": 28, "silence": 3}},
	"li_yun_e": {"name": "夜行猎手", "cd": 0, "targeted": false, "radius": 0, "color": Color("2e2752"), "passive": true, "desc": "惯于夜里行猎，被动提升移速与攻速。", "effect": {"kind": "passive", "speed_mult": 1.06, "atkspeed_add": 0.12}},
	"li_yun_r": {"name": "黑天罩", "cd": 40, "targeted": false, "radius": 170, "color": Color("1b1638"), "desc": "青眼虎唤来无边黑夜随身而行：夜幕罩中之敌持续遭暗噬 {v}，猎手在自己的夜里从不落空。", "effect": {"kind": "black_rain", "follow": true, "dps_ranks": [16, 20, 24], "dur_ranks": [8, 10, 12], "dmg": 40, "dur": 10}},
	"jiao_ting_q": {"name": "撼山掌", "cd": 9, "targeted": true, "radius": 90, "color": Color("8a6a3a"), "desc": "没面目一掌拍裂大地，把落点敌军震飞推开，受 {v} 伤并眩晕。", "effect": {"kind": "knockback", "dmg": 42, "push": 120, "radius": 90, "stun": 0.8}},
	"jiao_ting_w": {"name": "滚石躯", "cd": 11, "targeted": true, "radius": 60, "color": Color("9c7a44"), "desc": "蜷身化作磐石滚撞而出，沿途撞击敌军 {v} 伤并迟滞。", "effect": {"kind": "charge", "dmg": 46, "windup": 0.4, "dist": 230, "width": 60, "slow": 0.55, "slow_dur": 2}},
	"jiao_ting_e": {"name": "磁牵手", "cd": 12, "targeted": true, "radius": 50, "color": Color("7a5a30"), "desc": "以巧力牵引前方敌军拖至身前，受 {v} 伤并被定住。", "effect": {"kind": "pull", "dmg": 34, "len": 230, "width": 55, "pull_dist": 200, "stun": 0.8}},
	"jiao_ting_r": {"name": "附岩煞", "cd": 38, "targeted": false, "radius": 240, "color": Color("6a4a28"), "desc": "给身周敌军烙上岩印，碎石如影随形持续灼磨，每秒造成伤害，共持续数秒。", "effect": {"kind": "black_rain", "follow": true, "dps_ranks": [22, 28, 34], "dur_ranks": [6, 7, 8], "dmg": 20, "dur": 7}},
	"shi_yong_q": {"name": "破晓旋", "cd": 10, "targeted": false, "radius": 110, "color": Color("ffc04a"), "desc": "石将军挥锤连旋猛劈，身周敌军受 {v} 伤、被晕，自身借势回血。", "effect": {"kind": "smite", "dmg": 44, "stun": 0.8, "self_lifesteal": 0.6, "self_lifesteal_dur": 3}},
	"shi_yong_w": {"name": "流光锤", "cd": 11, "targeted": true, "radius": 60, "color": Color("ffd87a"), "desc": "掷出流光巨锤贯穿一线，沿途敌军受 {v} 伤并迟滞。", "effect": {"kind": "line_nuke", "dmg": 48, "len": 240, "width": 70, "slow": 0.5, "slow_dur": 2}},
	"shi_yong_e": {"name": "辉耀身", "cd": 0, "targeted": false, "radius": 0, "color": Color("ffe6a0"), "passive": true, "desc": "周身辉光护体，平攻带暴击、攻击吸血回身。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.6, "lifesteal": 0.3}},
	"shi_yong_r": {"name": "曦光降", "cd": 44, "targeted": false, "radius": 260, "color": Color("ffe27a"), "desc": "曦光普照战阵，范围友军大量回血并攻击大增，持续 {v} 秒。", "effect": {"kind": "rally", "heal": 120, "atk_mult": 1.4, "dur": 8}},
	"sun_xin_q": {"name": "雾矢", "cd": 8, "targeted": true, "radius": 50, "color": Color("4a6a8a"), "desc": "小尉迟射出一缕阴煞雾矢，命中敌军 {v} 伤并迟滞。", "effect": {"kind": "smite", "dmg": 46, "slow": 0.5, "slow_dur": 2}},
	"sun_xin_w": {"name": "幽护甲", "cd": 11, "targeted": false, "radius": 200, "color": Color("5a7aa0"), "desc": "为身周友军罩上幽冥护甲，吸收伤害，持续 {v} 秒。", "effect": {"kind": "shield", "shield": 200, "dur": 6, "allies": true, "radius": 200}},
	"sun_xin_e": {"name": "霜咒", "cd": 0, "targeted": false, "radius": 0, "color": Color("7a9ac0"), "passive": true, "desc": "兵刃附霜咒，攻击使敌军减速，自身攻速渐增。", "effect": {"kind": "passive", "on_hit_slow": 0.6, "on_hit_slow_dur": 1.5, "atkspeed_add": 0.1}},
	"sun_xin_r": {"name": "借命时", "cd": 50, "targeted": false, "radius": 0, "color": Color("3a5a80"), "desc": "临危借命，自身罩上厚重亡魂之盾抵御重创，持续 {v} 秒。", "effect": {"kind": "shield", "shield": 260, "dur": 6}},
	"gu_dasao_q": {"name": "藤牢", "cd": 10, "targeted": true, "radius": 60, "color": Color("5aa050"), "desc": "母大虫令落点骤生荆藤围困，困住敌军并刮伤 {v}，阻隔去路。", "effect": {"kind": "ice_wall", "dmg": 30, "range": 60, "len": 120, "dur": 4}},
	"gu_dasao_w": {"name": "踏青遁", "cd": 14, "targeted": true, "radius": 0, "color": Color("a0e8c0"), "desc": "借林莽掩护远遁至指定处，神出鬼没。", "effect": {"kind": "blink", "dist": 360, "dmg": 30.0}},
	"gu_dasao_e": {"name": "唤庄客", "cd": 13, "targeted": false, "radius": 80, "color": Color("70b860"), "desc": "唤出庄客喽兵助阵厮杀，持续 {v} 秒。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 2, "summon_kind": "treant", "hp": [220, 300, 380], "atk": [18, 24, 30], "dur": 25}},
	"gu_dasao_r": {"name": "天罚降", "cd": 40, "targeted": false, "radius": 0, "color": Color("3a7a40"), "desc": "号令天罚，全图敌军皆受 {v} 自然之力惩戒。", "effect": {"kind": "global_nuke", "dmg": 30, "heroes_only": false}},
	"zhang_qing_cai_q": {"name": "毒刺", "cd": 0, "targeted": false, "radius": 0, "color": Color("6a4fb0"), "passive": true, "desc": "菜园子箭头淬毒，平攻附带毒伤并使敌减速。", "effect": {"kind": "passive", "on_hit_dmg": 10, "on_hit_slow": 0.7, "on_hit_slow_dur": 2}},
	"zhang_qing_cai_w": {"name": "瘴毒风", "cd": 11, "targeted": true, "radius": 60, "color": Color("7a5fc0"), "desc": "放出一道瘴毒恶风贯穿敌阵，沿线 {v} 伤并大幅迟滞。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 240, "width": 70, "slow": 0.5, "slow_dur": 3}},
	"zhang_qing_cai_e": {"name": "布毒桩", "cd": 16, "targeted": true, "radius": 220, "color": Color("5a3fa0"), "desc": "菜园子栽下一根毒桩傀儡，原地朝最近官军连放冷箭，中者淬毒迟滞——栽一处，蚕食一整片来敌。", "effect": {"kind": "ward", "ward_mode": "poison", "ward_style": "poison", "ward_radius": 220, "pulse": 0.5, "dmg_ranks": [14, 20, 26], "slow": 0.5, "slow_dur": 1.5, "dur_ranks": [14, 16, 18]}},
	"zhang_qing_cai_r": {"name": "万毒爆", "cd": 44, "targeted": false, "radius": 300, "color": Color("4a2f90"), "desc": "周身炸开漫天毒云，范围敌军受 {v} 即时伤，并长时间中毒灼磨。", "effect": {"kind": "smite", "dmg": 32, "dot_total": 120, "dot_dur": 8}},
	"sun_erniang_q": {"name": "寒锋灼", "cd": 0, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "passive": true, "desc": "母夜叉飞刀凝寒，射程更远、命中附带冰焰灼伤。", "effect": {"kind": "passive", "range_add": 30, "on_hit_dmg": 12}},
	"sun_erniang_w": {"name": "碎冰镖", "cd": 10, "targeted": true, "radius": 110, "color": Color("8fd3ff"), "desc": "掷出寒镖击中目标四散碎裂，范围敌军 {v} 伤并迟滞。", "effect": {"kind": "smite", "dmg": 42, "slow": 0.55, "slow_dur": 2.5}},
	"sun_erniang_e": {"name": "寒衾护", "cd": 12, "targeted": false, "radius": 180, "color": Color("bfeaff"), "desc": "以寒衾裹护身周友军，结冰为盾吸收伤害，持续 {v} 秒。", "effect": {"kind": "shield", "shield": 180, "dur": 6, "allies": true, "radius": 180}},
	"sun_erniang_r": {"name": "彻骨咒", "cd": 46, "targeted": true, "radius": 200, "color": Color("6fc0ff"), "desc": "下彻骨冰咒封住一片战场，范围敌军 {v} 伤并被冻在原地动弹不得数秒。", "effect": {"kind": "chrono", "dur": 4, "radius_ranks": [160, 180, 200]}},
	"wang_dingliu_q": {"name": "电缚", "cd": 9, "targeted": true, "radius": 50, "color": Color("8fd3ff"), "desc": "活闪婆缠上一道电流，目标受 {v} 伤并被牢牢迟滞。", "effect": {"kind": "smite", "dmg": 44, "slow": 0.5, "slow_dur": 3}},
	"wang_dingliu_w": {"name": "磁场障", "cd": 12, "targeted": false, "radius": 200, "color": Color("7ac0ff"), "desc": "张开磁电力场，场内友军攻速暴涨，持续 {v} 秒。", "effect": {"kind": "atkspeed", "atkspeed": 1.6, "dur": 6, "allies": true, "radius": 200}},
	"wang_dingliu_e": {"name": "电魅", "cd": 10, "targeted": true, "radius": 80, "color": Color("9fe0ff"), "desc": "布下一团游走电魅，迸发时击中范围敌军 {v} 雷伤。", "effect": {"kind": "smite", "dmg": 48}},
	"wang_dingliu_r": {"name": "分身闪", "cd": 44, "targeted": false, "radius": 0, "color": Color("6fb0ff"), "desc": "迅捷如电分出一具镜像化身同战，持续 {v} 秒。", "effect": {"kind": "summon", "unit": "tiger_summon", "count": 1, "summon_kind": "clone", "copy_caster": true, "copy_mult": [0.6, 0.7, 0.8], "atk": [18, 22, 26], "dur": 16}},
	"yu_baosi_q": {"name": "卷虚", "cd": 11, "targeted": true, "radius": 90, "color": Color("6a4fb0"), "desc": "险道神搅起一团吸力旋涡，把前方敌军尽数拖聚一处，受 {v} 伤并定住。", "effect": {"kind": "pull", "dmg": 36, "len": 220, "width": 90, "pull_dist": 200, "stun": 0.8}},
	"yu_baosi_w": {"name": "离子壳", "cd": 12, "targeted": false, "radius": 90, "color": Color("8a6fd0"), "desc": "在身上罩一层灼能护壳，绕身旋转不断灼烧近敌，持续数秒。", "effect": {"kind": "orbit_axes", "dmg": 18, "slow": 0.7, "slow_dur": 1, "dur": 6, "tick": 0.5}},
	"yu_baosi_e": {"name": "疾涌", "cd": 10, "targeted": false, "radius": 160, "color": Color("a0e8c0"), "desc": "脚下迸发疾涌之力，身周友军移速骤升，持续 {v} 秒。", "effect": {"kind": "haste", "speed_mult": 1.45, "dur": 5}},
	"yu_baosi_r": {"name": "镜兵墙", "cd": 44, "targeted": true, "radius": 60, "color": Color("5a3fa0"), "desc": "凭空立起一道镜兵之墙，阻隔并刮伤穿墙敌军 {v}，持续数秒。", "effect": {"kind": "ice_wall", "dmg": 34, "range": 80, "len": 200, "dur": 5}},
	"bai_sheng_q": {"name": "弹丸连珠", "cd": 8, "targeted": true, "radius": 60, "color": Color("a0e8c0"), "desc": "白胜抛出一颗弹珠，在敌阵间蹦跳弹射，每跳造成 {v} 伤并令其手脚发软减速。", "effect": {"kind": "chain_nuke", "dmg": 30, "jumps": 4, "jump": 110, "falloff": 0.8, "slow": 0.6, "slow_dur": 2}},
	"bai_sheng_w": {"name": "蒙汗网阵", "cd": 12, "targeted": true, "radius": 130, "color": Color("6a4fb0"), "desc": "白胜在落点暗设绊网，网住范围内众敌将其定住 {v}，并泼一把蒙汗药拖慢身形。", "effect": {"kind": "smite", "dmg": 38, "stun": 1.3, "slow": 0.5, "slow_dur": 2}},
	"bai_sheng_e": {"name": "白日窜走", "cd": 10.0, "targeted": false, "radius": 100.0, "color": Color("ffd24a"), "passive": true, "desc": "白日鼠身轻足快，穿林越垄如履平地，平添移速与闪避，难被锁住。", "effect": {"kind": "passive", "speed_mult": 0.06, "evasion": 0.07}},
	"bai_sheng_r": {"name": "穿云一弹", "cd": 36, "targeted": true, "radius": 90, "color": Color("8fd3ff"), "desc": "白胜屏息蓄力，弹出一记贯穿长射，沿线洞穿敌阵造成 {v} 重伤并震慑减速。", "effect": {"kind": "line_nuke", "dmg": 120, "len": 420, "width": 70, "slow": 0.5, "slow_dur": 2.5}},
	"shi_qian_q": {"name": "飞檐走刃", "cd": 9, "targeted": true, "radius": 0, "color": Color("6a4fb0"), "desc": "时迁掷出系绳短刃划出一道暗径，沿线敌人受 {v} 伤并被绊索缠住 1.2 秒动弹不得（仍可反击）。", "effect": {"kind": "line_nuke", "dmg": 40, "len": 360, "width": 56, "root": 1.2}},
	"shi_qian_w": {"name": "孤影绝杀", "cd": 10.0, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "passive": true, "desc": "鼓上蚤专挑落单之人下手，攻击附带额外凶伤并回吸气血，越是孤立越是致命。", "effect": {"kind": "passive", "on_hit_dmg": 12, "lifesteal": 0.4}},
	"shi_qian_e": {"name": "化形散身", "cd": 16, "targeted": false, "radius": 0, "color": Color("9fd8ff"), "desc": "时迁身形一散，化作虚影潜行——敌军无法锁定，直到他出手；破隐首击奇袭重创。", "effect": {"kind": "invis", "dur": 7, "strike_bonus": 60}},
	"shi_qian_r": {"name": "百鬼夜行", "cd": 40, "targeted": false, "radius": 0, "color": Color("8fd3ff"), "desc": "时迁遣无数鼓上分身潜入全场，扑向每一名敌将造成 {v} 重创并拖慢其行。", "effect": {"kind": "global_nuke", "dmg": 50, "heroes_only": true, "slow": 0.6, "slow_dur": 3}},
	"duan_jingzhu_q": {"name": "回风斩", "cd": 10, "targeted": true, "radius": 90, "color": Color("ff7a2a"), "desc": "段景住策马一冲挥刀掠阵，沿途劈砍 {v}，刀气回旋再补一记余波。", "effect": {"kind": "charge", "dmg": 55, "windup": 0.3, "dist": 280, "width": 80, "slow": 0.6, "slow_dur": 1.5}},
	"duan_jingzhu_w": {"name": "疾隼连击", "cd": 12, "targeted": false, "radius": 0, "color": Color("ffd24a"), "desc": "金毛犬刀势如隼扑食，暴起一阵连斩，攻速与平攻俱涨，越打越狠。", "effect": {"kind": "atkspeed", "atkspeed": 1.6, "dur": 5, "self_atk": 1.4}},
	"duan_jingzhu_e": {"name": "牧马刀骨", "cd": 10.0, "targeted": false, "radius": 100.0, "color": Color("ff3322"), "passive": true, "desc": "段景住惯走牧马放纵之间，刀法精狠多致命暴击，骑战之中威势更盛。", "effect": {"kind": "passive", "crit_chance": 0.1, "crit_mult": 1.6, "bonus_cav": 0.2}},
	"duan_jingzhu_r": {"name": "舞刀绝阵", "cd": 38, "targeted": false, "radius": 150, "color": Color("ff7a2a"), "desc": "段景住纵马旋身舞刀成阵，刀光绕身不息，持续绞杀近旁众敌 {v} 并拖滞其步。", "effect": {"kind": "orbit_axes", "dmg": 30, "slow": 0.6, "slow_dur": 1, "dur": 5, "tick": 0.5}},
	# __DOTA_GEN_ABIL_END__
}


# 科技升级（在建筑里研究，完成后给玩家全局加成；每项一次）
const TECHS := {
	"tech_weapon": {"name": "锻造·利刃", "cost_gold": 130, "cost_wood": 60, "time": 30.0,
		"desc": "常备军攻击 +20%（英雄除外）", "effect": {"atk_mult": 1.2}},
	"tech_armor": {"name": "甲胄·坚铠", "cost_gold": 100, "cost_wood": 110, "time": 30.0,
		"desc": "常备军生命 +25%（英雄除外）", "effect": {"hp_mult": 1.25}},
	"tech_gather": {"name": "精耕·钱粮", "cost_gold": 80, "cost_wood": 80, "time": 24.0,
		"desc": "采集效率 +30%", "effect": {"gather_mult": 1.3}},
	# 时代进阶（聚义厅研究，单向）：解锁后期单位/建筑并给全军加成
	"tech_age2": {"name": "聚义·壮大", "cost_gold": 200, "cost_wood": 120, "time": 40.0,
		"desc": "进「聚义」时代：解锁英雄/马军/箭楼/集市，全军生命 +10%（含英雄）", "effect": {"advance_age": 2, "hp_mult": 1.1}},
	"tech_age3": {"name": "替天行道·鼎盛", "cost_gold": 350, "cost_wood": 220, "time": 55.0, "min_age": 2,
		"desc": "进「替天行道」时代：解锁攻城作坊/撞车，全军攻击 +10%（含英雄）", "effect": {"advance_age": 3, "atk_mult": 1.1}},
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
		var dd = eff["def_down"]
		extra += ("　削甲 %d/%d/%d" % [int(dd[0]), int(dd[1]), int(dd[2])]) if (dd is Array and (dd as Array).size() >= 3) else ("　削甲 %d" % int(dd))
	if eff.has("blind"):
		extra += "　致盲 %ss(攻击必失)" % str(eff["blind"])
	if float(eff.get("silence", 0.0)) > 0.0:
		extra += "　噤声 %ss(禁敌施法)" % str(eff["silence"])
	if float(eff.get("amp", 0.0)) > 0.0:
		extra += "　易伤 +%d%%/%ss" % [int(float(eff["amp"]) * 100.0), int(float(eff.get("amp_dur", 6.0)))]
	if float(eff.get("root", 0.0)) > 0.0:
		extra += "　缠绕 %ss(定身可反击)" % str(eff["root"])
	if float(eff.get("disarm", 0.0)) > 0.0:
		extra += "　缴械 %ss(不能普攻)" % str(eff["disarm"])
	if float(eff.get("taunt", 0.0)) > 0.0:
		extra += "　嘲讽 %ss(强制攻击自己)" % str(eff["taunt"])
	if String(eff.get("dispel", "")) == "buffs":
		extra += "　驱散(清敌增益)"
	elif String(eff.get("dispel", "")) == "debuffs":
		extra += "　净化(解友减益)"
	if float(eff.get("hex", 0.0)) > 0.0:
		extra += "　变形 %ss(沉默+缴械+减速)" % str(eff["hex"])
	match kind:
		"bolt":
			var _bl := "直线弹(可躲)" if (eff.has("homing") and not bool(eff["homing"])) else "单体追踪弹"
			return "%s %s%s" % [_bl, _l3a(float(eff.get("dmg", 0.0))), extra]
		"channel":
			var _ct := int(float(eff.get("dur", 3.0)) / maxf(0.1, float(eff.get("tick", 0.5))))
			return "引导%ss·每%ss轰一轮 %s（约%d轮）%s" % [str(eff.get("dur", 3.0)), str(eff.get("tick", 0.5)), _l3a(float(eff.get("dmg", 0.0))), _ct, extra]
		"invis":
			var _ib := float(eff.get("strike_bonus", 0.0))
			var _isb := ("　破隐首击+%s" % _l3a(_ib)) if _ib > 0.0 else ""
			return "隐身%ss(不可被索敌/指向·出手即现形)%s%s" % [str(eff.get("dur", 8.0)), _isb, extra]
		"transform":
			var fm: Dictionary = eff.get("form", {})
			var fps := PackedStringArray()
			if fm.has("atk_mult"): fps.append("攻×%.2f" % float(fm["atk_mult"]))
			if fm.has("hp_mult"): fps.append("血×%.2f" % float(fm["hp_mult"]))
			if fm.has("atk_cd_mult"): fps.append("攻速×%.2f" % (1.0 / maxf(0.1, float(fm["atk_cd_mult"]))))
			if fm.has("speed_mult"): fps.append("移速×%.2f" % float(fm["speed_mult"]))
			return "变身%ss·%s（到期还原）%s" % [str(eff.get("dur", 15.0)), " ".join(fps), extra]
		"hook":
			return "钩中拖回·伤 %s　钩程 %d%s" % [_l3a(float(eff.get("dmg", 0.0))), int(float(eff.get("len", 300.0))), extra]
		"swap":
			var sw := "与目标瞬间换位(敌我皆可点)"
			if float(eff.get("dmg", 0.0)) > 0.0:
				sw += "　换敌伤 %s" % _l3a(float(eff["dmg"]))
			return sw + extra
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
			var apr2: Array = eff.get("aura_power_ranks", [])
			if apr2.size() == 3:
				ps += "攻击光环×%.2f/%.2f/%.2f　" % [float(apr2[0]), float(apr2[1]), float(apr2[2])]
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
		"ward":
			var _mode := String(eff.get("ward_mode", "attack"))
			var _durw := str(eff.get("ward_dur", 8.0))
			if eff.has("dur_ranks"):
				var _drw: Array = eff["dur_ranks"]
				_durw = "%d/%d/%d" % [int(_drw[0]), int(_drw[1]), int(_drw[2])]
			if _mode == "banner":
				var _hrr: Array = eff.get("hero_reduction_ranks", [0.2, 0.3, 0.4])
				var _trr: Array = eff.get("troop_reduction_ranks", [0.5, 0.7, 0.9])
				var _bhr: Array = eff.get("heal_ranks", [20.0, 25.0, 30.0])
				var _bar: Array = eff.get("atkspeed_ranks", [1.5, 1.7, 1.9])
				return "2点充能/10秒回1点·英雄减伤%d/%d/%d%%·兵/召减伤%d/%d/%d%%·忠回%d/%d/%d/s·义攻速+%d/%d/%d%%·存%ss" % [
					int(float(_hrr[0]) * 100.0), int(float(_hrr[1]) * 100.0), int(float(_hrr[2]) * 100.0),
					int(float(_trr[0]) * 100.0), int(float(_trr[1]) * 100.0), int(float(_trr[2]) * 100.0),
					int(_bhr[0]), int(_bhr[1]), int(_bhr[2]),
					roundi((float(_bar[0]) - 1.0) * 100.0), roundi((float(_bar[1]) - 1.0) * 100.0), roundi((float(_bar[2]) - 1.0) * 100.0), _durw]
			if _mode == "heal":
				var _hs := str(int(float(eff.get("heal", 0.0))))
				if eff.has("heal_ranks"):
					var _hr: Array = eff["heal_ranks"]
					_hs = "%d/%d/%d" % [int(_hr[0]), int(_hr[1]), int(_hr[2])]
				return "立桩·每%ss回血%s · 范围%d · 存%ss" % [str(eff.get("pulse", 1.0)), _hs, int(eff.get("ward_radius", 200)), _durw]
			var _ds := str(int(float(eff.get("dmg", 0.0))))
			if eff.has("dmg_ranks"):
				var _dr: Array = eff["dmg_ranks"]
				_ds = "%d/%d/%d" % [int(_dr[0]), int(_dr[1]), int(_dr[2])]
			return "立桩·每%ss射敌%s%s · 范围%d · 存%ss" % [str(eff.get("pulse", 1.0)), _ds, ("·减速" if float(eff.get("slow", 0.0)) > 0.0 else ""), int(eff.get("ward_radius", 200)), _durw]
		"fissure":
			return "贯穿 %s　震晕%ss · 裂墙阻路%ss%s" % [_l3a(float(eff.get("dmg", 0.0))), str(eff.get("stun", 0.0)), str(eff.get("wall_dur", 4.0)), extra]
		"echo":
			return "每目标 %s　每多一敌+%s · 震晕%ss" % [_l3a(float(eff.get("dmg", 0.0))), _l3a(float(eff.get("echo", 0.0))), str(eff.get("stun", 0.0))]
		"heal_wave":
			return "弹跳%d次·伤敌%s／愈友%s" % [int(eff.get("jumps", 5)), _l3a(float(eff.get("dmg", 0.0))), _l3a(float(eff.get("heal", 0.0)))]
		"fire_line", "fire_trail":
			var _dps := ""
			if eff.has("dps_ranks"):
				var _dr2: Array = eff["dps_ranks"]
				_dps = "%d/%d/%d" % [int(_dr2[0]), int(_dr2[1]), int(_dr2[2])]
			elif eff.has("dps"):
				_dps = str(int(float(eff["dps"])))
			var _durf := str(eff.get("dur", 6.0))
			if eff.has("dur_ranks"):
				var _du: Array = eff["dur_ranks"]
				_durf = "%d/%d/%d" % [int(_du[0]), int(_du[1]), int(_du[2])]
			return "地火每秒 %s · 持续 %ss" % [_dps, _durf]
		_:
			if eff.has("dmg"):
				return "伤害 %s%s" % [_l3a(float(eff["dmg"])), extra]
			return extra.strip_edges()
