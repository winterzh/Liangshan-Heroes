extends RefCounted
## Installed Gao roles originate in the checked Level record. No actor injection.
var roles: Dictionary = {}
var actors: Dictionary = {}
var pools: Dictionary = {}
const NAMED := {"hall":"hall","song":"song_jiang","flagship":"gao_flagship","fireboat":"liu_tang_fireboat","embarked_liu":"liu_tang","liu_carrier":"ruan_xiaoer_boat","prisoner":"gao_qiu","carrier":"zhang_shun_boat"}

func bad(code: String) -> Dictionary:return {"ok":false,"code":"LEVEL5_"+code}
func _fields(v: Variant,names: Array) -> bool:return typeof(v)==TYPE_DICTIONARY and v.size()==names.size() and v.has_all(names)
func _add(id: Variant,role: String,key: String,lane := -1) -> bool:
	if id==null:return true
	if typeof(id)!=TYPE_STRING or not id.is_valid_int() or str(id.to_int())!=id or id.to_int()<=0:return false
	if actors.has(id):return false # Every named actor/wave slot is distinct in the installed Gao chapter.
	actors[id]={"roles":[role],"key":key,"lane":lane};return true

func configure(value: Dictionary) -> Dictionary:
	if not _fields(value,["values","references","external"]):return bad("ROLES")
	var refs: Variant=value.references;var values: Variant=value.values
	if not _fields(refs,["hall","song","flagship","fireboat","embarked_liu","liu_carrier","prisoner","carrier","workers","posts","support","water_groups","land_groups"]):return bad("REFERENCE_FIELDS")
	if typeof(values)!=TYPE_DICTIONARY or not values.has_all(["fire_prepared","fire_lit","recovered","landed","flagship_disabled","capture_lost","core_ready","produced","waves"]):return bad("STAGE_FIELDS")
	for field in ["fire_prepared","fire_lit","recovered","landed","flagship_disabled","capture_lost","core_ready"]:
		if typeof(values[field])!=TYPE_BOOL:return bad("STAGE_TYPE")
	if typeof(values.produced)!=TYPE_ARRAY or values.produced.size()!=2:return bad("PRODUCTION")
	for i in range(2):
		if typeof(values.produced[i])!=TYPE_INT or values.produced[i]<0 or values.produced[i]>[10,4][i]:return bad("PRODUCTION")
	actors.clear();pools.clear();roles=value.duplicate(true)
	for field in NAMED:
		if not _add(refs[field],field,NAMED[field]):return bad("NAMED_ROLE")
	for field in ["water_groups","land_groups"]:
		if typeof(refs[field])!=TYPE_ARRAY or refs[field].size()!=3:return bad("WAVE_GROUPS")
		for lane in range(3):
			var group: Variant=refs[field][lane]
			var count: int=([3,5,6] if field=="water_groups" else [4,6,8])[lane]
			if typeof(group)!=TYPE_ARRAY or group.size()!=count:return bad("WAVE_GROUP_SIZE")
			for i in range(count):
				var key: String=("official_vanguard" if lane==2 and i==0 else "imperial_warship") if field=="water_groups" else ("guan_qi" if lane==2 and i<3 else "guan_gong" if i%3==2 else "guan_dao")
				if not _add(group[i],field,key,lane):return bad("WAVE_ROLE")
	if typeof(refs.posts)!=TYPE_ARRAY or refs.posts.size()!=2:return bad("POSTS")
	for i in range(2):
		if not _add(refs.posts[i],"post","barracks" if i==0 else "shipyard"):return bad("POST_ROLE")
	for field in ["workers","support"]:
		if typeof(refs[field])!=TYPE_ARRAY:return bad("POOL_TYPE")
		var seen := {}
		for id in refs[field]:
			if id==null:continue
			if typeof(id)!=TYPE_STRING or not id.is_valid_int() or id.to_int()<=0 or seen.has(id) or actors.has(id):return bad("POOL_ROLE")
			seen[id]=true;pools[id]=field
	return {"ok":true}

func values(v: Dictionary) -> Dictionary:
	var role: Dictionary=actors.get(str(v.entity_id),{});var names: Array=role.get("roles",[])
	if v.faction not in [0,1] or v.is_captive or v._story_pose_t!=0.0 or v._pose_previous_variant!="":return bad("UNSUPPORTED_POSE_OR_FACTION")
	if not role.is_empty() and v.key!=role.key:return bad("ROLE_KEY")
	if (v.hp<=0.0)!=v._dying:return bad("LIFETIME")
	var outcome: String="subdued" if names.has("flagship") else ""
	if v.defeat_outcome!=outcome:return bad("DEFEAT_OUTCOME")
	var permitted: Array=[""]
	if names.has("flagship"):permitted.append("subdued")
	if names.has("fireboat"):permitted.append("retreated")
	if names.has("embarked_liu"):permitted.append("embarked")
	if not permitted.has(v.story_outcome):return bad("STORY_OUTCOME")
	if names.any(func(n):return n in ["hall","song","fireboat","embarked_liu","liu_carrier","prisoner","carrier"]) and v.faction!=0:return bad("FRIENDLY_ROLE")
	if names.any(func(n):return n in ["flagship","water_groups","land_groups","post"]) and v.faction!=1:return bad("ENEMY_ROLE")
	if names.any(func(n):return n in ["flagship","fireboat","liu_carrier","carrier","water_groups"]) and v.movement_profile!="water":return bad("NAVAL_PROFILE")
	if names.has("song") or names.has("embarked_liu"):
		if not v.is_hero or v.is_building or v.is_summon:return bad("HERO_IDENTITY")
	if names.has("prisoner"):
		if not roles.values.landed or v.is_hero or v.is_building or not v.is_noncombat or v.is_cavalry or v.atk!=0.0 or v.base_speed!=42.0 or v.max_hp!=180.0 or v.ability!="" or not v.ability_slots.is_empty() or v.aura!="" or v.art_variant!="gao_qiu_captured":return bad("PRISONER_IDENTITY")
	if v.story_outcome!="":
		if not v.passive or v.stance!=3 or v.selected or v.hp<1.0 or v._dying:return bad("RESOLVED_LIFETIME")
		if v._state!=0 or not v._path.is_empty() or v.mission_order_active:return bad("RESOLVED_ORDER")
	var pool: String=pools.get(str(v.entity_id),"")
	if pool=="workers" and (v.key!="lou_luo" or v.faction!=0 or not v.is_worker):return bad("WORKER_IDENTITY")
	if pool=="support" and (v.key not in ["guan_dao","guan_gong","imperial_warship"] or v.faction!=1):return bad("SUPPORT_IDENTITY")
	return {"ok":true}

func parts(v: Dictionary,refs: Dictionary,meta: Dictionary,_node: Dictionary) -> Dictionary:
	var role: Dictionary=actors.get(str(v.entity_id),{});var names: Array=role.get("roles",[])
	if refs.story_assist_owner.state!="none" or refs.story_assist_partner.state!="none" or meta.has("story_pose"):return bad("ASSISTANCE_OR_POSE")
	if names.has("water_groups"):
		if typeof(meta.get("gao_wave"))!=TYPE_INT or meta.gao_wave!=role.lane:return bad("WAVE_METADATA")
	elif meta.has("gao_wave"):return bad("UNREGISTERED_WAVE")
	if meta.has("gao_source"):
		if pools.get(str(v.entity_id))!="support" or typeof(meta.gao_source)!=TYPE_INT or meta.gao_source not in [0,1] or (v.movement_profile=="water")!=(meta.gao_source==1):return bad("SOURCE_LANE")
	var flag: String="chapter80_gao_flagship" if names.has("flagship") else ("chapter80_vanguard_headship" if role.get("key")=="official_vanguard" else "")
	if flag!="" and meta.get("campaign_flag_context")!=flag:return bad("FLAG_CONTEXT")
	if meta.has("ship_state") and (not names.any(func(n):return n in ["flagship","fireboat"]) or meta.ship_state not in ["damaged","disabled"]):return bad("SHIP_STATE")
	if meta.has("story_commander") and (not names.has("fireboat") or not roles.values.fire_prepared or meta.story_commander!="liu_tang"):return bad("FIRE_COMMANDER")
	if meta.has("carried_story_person"):
		if not ((names.has("liu_carrier") and meta.carried_story_person=="刘唐") or (names.has("carrier") and meta.carried_story_person=="高俅")):return bad("CARRIED_PERSON")
	if names.has("embarked_liu") and v.story_outcome!="embarked":return bad("EMBARKED_OUTCOME")
	return {"ok":true}

func membership(states: Dictionary,active: Array) -> Dictionary:
	for id in actors.keys()+pools.keys():
		if not states.has(id):return bad("ROLE_NOT_IN_GRAPH")
		var v: Dictionary=states[id].values
		if active.has(id)!=(v.hp>0.0 and not v._dying):return bad("ACTIVE_MEMBERSHIP")
	return {"ok":true,"complete_world":false}
