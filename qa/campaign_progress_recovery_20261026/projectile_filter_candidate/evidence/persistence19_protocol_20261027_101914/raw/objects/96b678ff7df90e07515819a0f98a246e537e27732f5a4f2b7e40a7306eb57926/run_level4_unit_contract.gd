extends RefCounted
## Chapter-specific checks applied after the common Unit decoder. Role data is
## supplied only by the installed LevelState validator, never by a slot caller.
var roles: Dictionary = {}
var actors: Dictionary = {}

func bad(code: String) -> Dictionary:
	return {"ok": false, "code": "LEVEL4_" + code}

func configure(value: Dictionary) -> Dictionary:
	var expected := ["hall", "song", "xu", "hu", "han", "enemy_base", "dummy", "drill_lure", "riders", "posts", "workers", "enemy_workers", "enemy_nodes", "escorts", "broken_count", "lhm_killed", "waves", "drill_complete"]
	if value.size() != expected.size() or not value.has_all(expected): return bad("ROLES")
	if typeof(value.riders) != TYPE_ARRAY or value.riders.size() != 12: return bad("RIDERS")
	if typeof(value.posts) != TYPE_ARRAY or value.posts.size() != 2: return bad("POSTS")
	if typeof(value.waves) != TYPE_ARRAY or value.waves.size() != 2: return bad("WAVES")
	for field in ["broken_count", "lhm_killed"]:
		if typeof(value[field]) != TYPE_INT or value[field] < 0 or value[field] > 12: return bad("COUNTER")
	var named := {"hall": "hall", "song": "song_jiang", "xu": "xu_ning", "hu": "hu_yanzhuo", "han": "han_tao", "enemy_base": "hall", "dummy": "hook_training_dummy"}
	var pending := {}
	for field in named:
		var id: Variant = value[field]
		if id == null: continue
		if typeof(id) != TYPE_STRING or not id.is_valid_int() or id.to_int() <= 0 or pending.has(id): return bad("ROLE_ID")
		pending[id] = {"role": field, "key": named[field]}
	for index in range(12):
		var id: Variant = value.riders[index]
		if id == null: continue
		if typeof(id) != TYPE_STRING or not id.is_valid_int() or id.to_int() <= 0 or pending.has(id): return bad("RIDER_ID")
		pending[id] = {"role": "rider", "key": "lian_huan_ma", "lane": index / 6}
	roles = value.duplicate(true)
	actors = pending
	return {"ok": true}

func values(v: Dictionary) -> Dictionary:
	var role: Dictionary = actors.get(str(v.entity_id), {})
	if v._story_pose_t != 0.0 or v._pose_previous_variant != "" or v.is_captive: return bad("UNSUPPORTED_POSE_OR_CAPTIVE")
	if v.faction not in [0, 1]: return bad("FACTION")
	if not role.is_empty() and v.key != role.key: return bad("ROLE_KEY")
	var outcome := ""
	if role.get("role") == "hu": outcome = "retreated"
	if role.get("role") == "han": outcome = "captured"
	if role.get("role") == "dummy": outcome = "subdued"
	if v.defeat_outcome != outcome or v.story_outcome not in ["", outcome]: return bad("OUTCOME")
	if role.get("role") in ["hu", "han", "dummy", "rider", "enemy_base"] and v.faction != 1: return bad("ENEMY_ROLE_FACTION")
	if role.get("role") in ["hall", "song", "xu"] and v.faction != 0: return bad("FRIENDLY_ROLE_FACTION")
	if role.get("role") in ["hu", "han", "song", "xu"] and (not v.is_hero or v.is_summon or v.is_building): return bad("HERO_IDENTITY")
	if role.get("role") in ["dummy", "rider"] and (v.is_hero or v.is_summon or v.is_building or not v.is_cavalry): return bad("RIDER_IDENTITY")
	if (v.hp <= 0.0) != v._dying: return bad("LIFETIME")
	if v.story_outcome != "":
		if not v.passive or v.stance != 3 or v.selected or v.hp < 1.0 or v._dying or v.garrisoned: return bad("RESOLVED_LIFETIME")
		if v._state != 0 or not v._path.is_empty() or v._patrolling or v.mission_order_active or v.mission_order_token != 0: return bad("RESOLVED_ORDER")
	return {"ok": true}

func parts(v: Dictionary, refs: Dictionary, meta: Dictionary, _node: Dictionary) -> Dictionary:
	var role: Dictionary = actors.get(str(v.entity_id), {})
	if meta.has("story_pose"): return bad("STORY_POSE")
	for field in ["story_assist_owner", "story_assist_partner"]:
		if refs[field].state != "none": return bad("ASSISTANCE")
	if role.get("role") == "rider":
		if typeof(meta.get("wave_group")) != TYPE_INT or meta.wave_group != role.lane: return bad("WAVE_GROUP")
		if typeof(meta.get("formation_broken")) != TYPE_BOOL or typeof(meta.get("wave_state")) != TYPE_STRING: return bad("FORMATION_TYPES")
		if meta.wave_state not in ["waiting", "charging", "broken"] or (meta.wave_state == "broken" and not meta.formation_broken): return bad("FORMATION_STATE")
		if meta.wave_state == "charging" and not roles.waves[role.lane].sent: return bad("UNSENT_CHARGE")
	elif meta.has("wave_group") or meta.has("formation_broken") or meta.has("wave_state"):
		return bad("UNREGISTERED_RIDER")
	if meta.has("source_lane") and (typeof(meta.source_lane) != TYPE_INT or meta.source_lane not in [0, 1] or v.key not in ["guan_dao", "guan_gong"] or v.faction != 1): return bad("ESCORT_LANE")
	if v.story_outcome != "" and (refs._pending_target.state != "none" or refs._target.state != "none" or not refs._queue.is_empty()): return bad("RESOLVED_TARGET")
	return {"ok": true}

func membership(states: Dictionary, active_ids: Array) -> Dictionary:
	for id in actors:
		if not states.has(id): return bad("ROLE_NOT_IN_GRAPH")
		var v: Dictionary = states[id].values
		if active_ids.has(id) != (v.hp > 0.0 and not v._dying): return bad("ACTIVE_MEMBERSHIP")
	var dead := 0
	var broken := 0
	var absent := 0
	for id in roles.riders:
		if id == null:
			dead += 1; absent += 1
		else:
			var state: Dictionary = states[id]
			if state.values.hp <= 0.0: dead += 1
			if state.metadata.formation_broken: broken += 1
			for entry in state.pools._damage_reduction_sources:
				if entry.source == {"kind": "scalar", "value": "4705"} and state.metadata.formation_broken: return bad("BROKEN_LINK_BUFF")
	if dead != roles.lhm_killed or roles.broken_count < broken or roles.broken_count > broken + absent: return bad("FORMATION_COUNTER")
	return {"ok": true, "complete_world": false}
