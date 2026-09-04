extends RefCounted
## 战役各自的环境配置。地形先于bake，装饰随后；不改兵力/任务/波次。
const T := GameMap.T
const LEVELS := ["level1","level2","level3","level4","level6","level7","level8"]
## New Web ChatGPT environment art is carried by explicit level-scoped markers.
## These marker names are not ArtDB aliases and therefore cannot leak a level7
## tavern or level3 hall into another map.
const SCOPED_OBJECT_MARKER := "campaign_environment_object"
const SCOPED_OVERLAY_MARKER := "campaign_environment_overlay"


static func scoped_object(cell: Vector2i, size: float, route_key: String,
		fallback_key := "", foot := 0.82, tree := false, casts_shadow := true) -> Array:
	return [SCOPED_OBJECT_MARKER, cell, size, route_key, fallback_key, foot, tree, casts_shadow]


static func scoped_overlay(cell: Vector2i, size: float, route_key: String) -> Array:
	return [SCOPED_OVERLAY_MARKER, cell, size, route_key]


static func overlay_layout(id: String) -> Array:
	# Purely visual, deterministic anchors. The resolver still rejects every
	# route outside its frozen level_scope. No source texture means no node.
	match id:
		"level1": return [
			scoped_overlay(Vector2i(34,20),88.0,"shallow_cart_ruts"),
			scoped_overlay(Vector2i(27,21),68.0,"scattered_footprints"),
			scoped_overlay(Vector2i(12,20),54.0,"pole_wheel_marks"),
			scoped_overlay(Vector2i(38,18),48.0,"rounded_stones"),
			scoped_overlay(Vector2i(31,17),52.0,"gravel_clods"),
			scoped_overlay(Vector2i(24,16),66.0,"pine_needles_leaves"),
			scoped_overlay(Vector2i(16,22),58.0,"dry_grass_leaves"),
		]
		"level2": return [
			scoped_overlay(Vector2i(29,22),70.0,"trampled_mud"),
			scoped_overlay(Vector2i(14,42),58.0,"pole_wheel_marks"),
			scoped_overlay(Vector2i(34,18),50.0,"weathered_slabs"),
			scoped_overlay(Vector2i(25,20),48.0,"old_brick_fragments"),
			scoped_overlay(Vector2i(17,45),64.0,"flattened_reeds"),
			scoped_overlay(Vector2i(20,46),62.0,"sparse_wet_grass"),
			scoped_overlay(Vector2i(10,48),60.0,"low_aquatic_plants"),
			scoped_overlay(Vector2i(22,45),52.0,"mud_spots_wet_marks"),
		]
		"level3": return [
			scoped_overlay(Vector2i(16,18),54.0,"twigs_bark"),
			scoped_overlay(Vector2i(15,34),54.0,"roots_moss"),
			scoped_overlay(Vector2i(27,28),58.0,"field_edge_bank"),
			scoped_overlay(Vector2i(13,18),58.0,"field_edge_stubble"),
			scoped_overlay(Vector2i(16,30),64.0,"field_edge_ditch"),
			scoped_overlay(Vector2i(13,40),58.0,"field_edge_willow"),
		]
		"level4": return [
			scoped_overlay(Vector2i(20,26),72.0,"trampled_mud"),
			scoped_overlay(Vector2i(18,37),66.0,"flattened_reeds"),
		]
		"level6": return [
			scoped_overlay(Vector2i(25,19),62.0,"pine_needles_leaves"),
			scoped_overlay(Vector2i(31,23),52.0,"twigs_bark"),
		]
		"level7": return [
			scoped_overlay(Vector2i(31,19),78.0,"shallow_cart_ruts"),
			scoped_overlay(Vector2i(46,19),50.0,"weathered_slabs"),
		]
		"level8": return [
			scoped_overlay(Vector2i(31,34),64.0,"scattered_footprints"),
			scoped_overlay(Vector2i(29,17),54.0,"old_brick_fragments"),
		]
	return []

static func enabled(id: String) -> bool:
	return id in LEVELS and OS.get_environment("CAMPAIGN_ENV_BASELINE")!="1"

static func dry_woods(id: String) -> bool:
	# 黄泥冈的松阴只在冈顶；野猪林才是整片猛恶林子。
	return id == "level6"

static func buildings(id: String) -> Dictionary:
	match id:
		"level2": return {"scaffold":"scaffold"}
		"level3": return {"zhu_gate":"zhu_gate"}
		"level4": return {"jiangtai":"banner"}
		"level7": return {"tavern":"town_house","signboard":"banner"}
		"level8": return {}
	return {}

static func houses(id: String) -> Array:
	match id:
		"level2": return [[Vector2i(6,9),"town_house"],[Vector2i(12,8),"town_house"],
			[Vector2i(45,8),"town_house"],[Vector2i(51,13),"town_house"],
			[Vector2i(51,34),"town_house"],[Vector2i(36,8),"zhu_hall"],
			[Vector2i(20,16),"town_house"],[Vector2i(40,19),"town_house"],
			[Vector2i(23,33),"town_house"],[Vector2i(34,35),"town_house"],
			[Vector2i(33,41),"town_house"],[Vector2i(44,40),"town_house"]]
		"level3": return [[Vector2i(8,15),"town_house"],[Vector2i(13,15),"town_house"],
			[Vector2i(8,21),"town_house"],[Vector2i(8,36),"town_house"],
			[Vector2i(8,44),"town_house"],[Vector2i(13,44),"town_house"],[Vector2i(5,26),"zhu_hall"]]
		"level4": return [[Vector2i(54,15),"tent"],[Vector2i(56,18),"tent"],
			[Vector2i(52,50),"tent"],[Vector2i(57,51),"tent"]]
		"level7": return [[Vector2i(48,13),"town_house"],[Vector2i(56,26),"town_house"],
			[Vector2i(47,28),"town_house"]]
		"level8": return [[Vector2i(11,10),"town_house"],[Vector2i(23,10),"town_house"],
			[Vector2i(45,11),"town_house"],[Vector2i(45,23),"town_house"],
			[Vector2i(13,27),"town_house"],[Vector2i(23,31),"town_house"],[Vector2i(38,30),"town_house"]]
	return []

static func paint(map: GameMap,id: String) -> void:
	if not enabled(id): return
	map.environment_style = id
	for y in range(map.h):
		for x in range(map.w):
			var old := map.t_at(x,y)
			if old not in [T.GRASS,T.DRYHILL,T.PLAIN]: continue
			var boundary := sin(x*0.31)*1.7+sin(x*0.71)*0.65
			match id:
				"level1":
					# 黄泥冈是热、黄沙、茅草和碎石间的冈路，不能改成林海。
					if y>10 and y<31: map.set_cell_t(x,y,T.DRYHILL)
				"level6":
					if y<15.0+boundary or y>25.0+boundary: map.set_cell_t(x,y,T.FOREST)
				"level3":
					if x<17 and y>10 and y<45: map.set_cell_t(x,y,T.FIELD)
				"level4":
					if x<7+boundary and (y<18 or y>46): map.set_cell_t(x,y,T.FOREST)
					elif x>43 and (y<13 or y>51): map.set_cell_t(x,y,T.FIELD)
				"level7":
					# 原文是“孟州东门→十数酒肆→快活林丁字口”，不能把十四五里全压成一块城内广场。
					if x<9 and y>12 and y<27: map.set_cell_t(x,y,T.TOWN) # 东门口的铺砌地
					elif x>45 and y>10 and y<30: map.set_cell_t(x,y,T.TOWN) # 快活林市口
				"level8":
					if x>46 and y>23 or y>44 and x<29: map.set_cell_t(x,y,T.FIELD)
					elif x>46 and y<10 or x<16 and y<14: map.set_cell_t(x,y,T.FOREST)
	for house in houses(id):
		var c: Vector2i = house[0]
		# 静态屋舍真实占地；主道、刑台和任务触发点不写入这一名单。
		map.fill_rect(c.x-1,c.y-1,3,3,T.HALL)
	if id=="level4":
		# 原文写的是芦苇、荆棘、荒草、林子与窄路里的十队伏兵；把规则圆形泥淖打散为多块相接的伏地。
		for patch in [[Vector2(18,24),7,5],[Vector2(16,36),8,5],[Vector2(26,42),8,4]]:
			map.fill_ellipse(patch[0],patch[1],patch[2],T.REEDS,[T.MARSH,T.GRASS,T.PLAIN])
		for copse in [[Vector2(10,19),4,3],[Vector2(11,45),4,3]]:
			map.fill_ellipse(copse[0],copse[1],copse[2],T.FOREST,[T.GRASS,T.PLAIN])
		# 湿草间留出曲折泥水缝，视觉与机动都不再像一块规则圆形陷阱。
		map.paint_path([Vector2(12,24),Vector2(18,25),Vector2(23,27),Vector2(27,26)],0,T.MARSH)
		map.paint_path([Vector2(12,37),Vector2(17,36),Vector2(22,38),Vector2(27,39)],0,T.MARSH)
	if id=="level7":
		# 酒家门前支路，建筑本体保持原酒望单位占地和触发半径。
		for c in [Vector2i(16,15),Vector2i(25,22),Vector2i(34,14),Vector2i(43,21)]:
			map.paint_path([Vector2(c.x,c.y),Vector2(c.x,19)],0,T.ROAD)
	if id=="level1":
		# 原文是崎岖山路上冈，保持两端和冈顶任务点，取消横穿全图的直道。
		map.paint_path([Vector2(47,20),Vector2(40,18),Vector2(32,19),Vector2(24,20),Vector2(16,21),Vector2(8,20),Vector2(1,20)],1,T.ROAD)
	if id=="level2":
		for y in range(44,map.h):
			for x in range(map.w):
				if x>=6 and x<=18: continue # 码头和接应船、撤退通道保护带
				if map.t_at(x,y) not in [T.WATER,T.SHORE,T.TOWN]: continue
				var bank := 47+int(round(sin(x*0.24)*1.2+sin(x*0.51)*0.5))
				if y>=bank: map.set_cell_t(x,y,T.WATER)
				elif y>=bank-2: map.set_cell_t(x,y,T.SHORE)

static func decorate(map: GameMap,id: String) -> void:
	var result: Array = []
	for item in map.decor:
		var d: Array = item.duplicate()
		if d[0]=="rocks": continue # 不继续放置可穿过的假岩石
		if id in ["level2","level3","level4"] and d[0]=="tent": continue
		if id=="level2":
			if d[0]=="hall" and d[1]==Vector2i(30,18): continue # 真实刑台单位已绘制
			if d[0]=="tower" and d[1]==Vector2i(30,8): continue
			if d[0]=="hall": d[0]="town_house"; d[2]=146.0
			if d[0]=="bridge": d[0]="dock"; d[2]=146.0
			if d[0]=="boat": d[1]=Vector2i(14,53)
		if id=="level3":
			if d[0]=="hall": continue # 庄门单位与独立祠堂，不再叠厅堂占位图
			if d[0]=="forest": d[0]="white_poplar"; d[2]=142.0
		if id=="level6" and d[0]=="pine":
			# 使用松针树冠而非 terrain2 里泛白的老松，以便野猪林读成幽深林地。
			d[0]="tree"
			if d[1]==Vector2i(27,17): d[0]="tree1"; d[1]=Vector2i(27,20); d[2]=180.0
			else: d[2]=125.0
		if id=="level7" and d[0] in ["tent","town_house"]: continue
		if id=="level8" and d[0]=="town_house": continue
		if id=="level8" and d[0]=="boat": d[1]=Vector2i(14,32)
		if id=="level8" and d[0]=="cuiyun_tower":
			# The stateful tower keeps its legacy texture until both accepted source
			# states exist, but the new source can only resolve inside level8.
			result.append(scoped_object(d[1],d[2],"cuiyun_tower","cuiyun_tower",0.82,false,true))
			continue
		result.append(d)
	if id=="level2":
		result.append(["town_house",Vector2i(17,19),146.0])
		result.append(["town_house",Vector2i(7,37),146.0])
		# 市曹行刑的围观人群只做视觉层，刑台、刽子手与撤退路径仍由关卡逻辑控制。
		for c in [Vector2i(24,17),Vector2i(25,21),Vector2i(26,14),Vector2i(33,14),
			Vector2i(36,18),Vector2i(35,23),Vector2i(24,24),Vector2i(38,22)]:
			result.append(["crowd",c,0.0,c.x+c.y])
	if id=="level3":
		# 独龙冈三村以小庄落和门牌可读化；不写进石秀安全路与任何伏兵/守军出生格。
		result.append(["story_sign",Vector2i(10,12),70.0,"李家庄"])
		result.append(["story_sign",Vector2i(10,46),70.0,"扈家庄"])
		result.append(["story_sign",Vector2i(21,24),76.0,"祝家庄"])
	if id=="level8":
		result.append(["story_sign",Vector2i(30,40),78.0,"大名府"])
		for cell in [Vector2i(27,12),Vector2i(33,20),Vector2i(27,27),Vector2i(34,33)]:
			result.append(["market_stall",cell,64.0,"lantern"])
			result.append(["crowd",cell+Vector2i(1,1),0.0,cell.y])
	if id=="level1":
		# 冈顶松阴和白胜卖酒的位置只做视觉提示，伏兵和生辰纲逻辑仍在关卡脚本。
		result.append(scoped_object(Vector2i(20,17),112.0,"huangnigang_pine_old","tree",0.82,true,true))
		result.append(scoped_object(Vector2i(25,18),112.0,"huangnigang_pine_double","tree",0.82,true,true))
		result.append(scoped_object(Vector2i(30,19),112.0,"huangnigang_pine_young_lean","tree",0.82,true,true))
		# The weapon group shares the SHADE anchor with the old pine by design.
		# Missing art draws nothing; it is never replaced by a generic weapon icon.
		result.append(scoped_object(Vector2i(20,17),94.0,"huangnigang_seven_pudao","",0.82,false,true))
		result.append(scoped_object(Vector2i(34,22),86.0,"huangnigang_dry_verge","",0.82,false,false))
		result.append(["market_stall",Vector2i(22,21),62.0,"wine"])
	if id=="level2": result.append(["zhu_gate",Vector2i(30,4),128.0])
	if id=="level7":
		# 东门外的市井有酒肆、客店、赌坊和兑坊；名称由摊面招牌承担，不改酒望交互。
		for stall in [[Vector2i(12,16),"inn"],[Vector2i(19,20),"wine"],[Vector2i(29,18),"goods"],
			[Vector2i(38,19),"dice"],[Vector2i(48,18),"money"],[Vector2i(52,22),"inn"]]:
			result.append(["market_stall",stall[0],64.0,stall[1]])
		# 左端是孟州东门；酒肆与快活林在城外官道尽头。
		result.append(["zhu_gate",Vector2i(2,19),170.0])
		# 丁字口主酒楼是 level7 独占物件；源图未到时继续用现有民居。
		result.append(scoped_object(Vector2i(49,17),154.0,"kuaihuolin_main_tavern","town_house",0.82,false,true))
	if id=="level4":
		result.append(["tree1",Vector2i(10,19),122.0])
		result.append(["tree1",Vector2i(11,45),122.0])
	for house in houses(id):
		if id=="level3" and house[1]=="zhu_hall":
			result.append(scoped_object(house[0],154.0,"zhujiazhuang_hall","zhu_hall",0.82,false,true))
		elif id=="level8" and house[1]=="town_house":
			result.append(scoped_object(house[0],154.0,"daming_shop_house","town_house",0.82,false,true))
		else:
			result.append([house[1],house[0],154.0])
	for overlay in overlay_layout(id): result.append(overlay)
	map.decor = result

static func height_profile(id: String,p: Vector2,w: int,h: int) -> float:
	var edge := smoothstep(0,5,p.x)*(1-smoothstep(w-5,w,p.x))*smoothstep(0,4,p.y)*(1-smoothstep(h-4,h,p.y))
	match id:
		"level1":
			var top := 28.0*smoothstep(5,14,p.x)*(1-smoothstep(34,43,p.x))
			var ridges := 34.0*(1-smoothstep(7,16,p.y))+27.0*smoothstep(25,34,p.y)
			return (top+ridges)*edge
		"level6": return (36.0*(1-smoothstep(7,17,p.y))+30.0*smoothstep(24,33,p.y))*edge
		"level3": return 18.0*(1-smoothstep(4,13,p.y))*edge
		"level4": return 22.0*(1-smoothstep(4,15,p.x))*(1-smoothstep(15,23,p.y))*edge
	return 0.0 # 城镇、酒家、法场保持平地，高低由建筑自己的台基体现
