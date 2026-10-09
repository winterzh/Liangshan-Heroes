extends RefCounted
## Daming captive/disguise and mining references are checked in the installed graph.
var roles: Dictionary = {}
var actors: Dictionary = {}
var pools: Dictionary = {}
const DamingLevel := preload("res://scripts/levels/level8_daming_rts.gd")
const MapScript := preload("res://scripts/game_map.gd")
const NAMED := {"hall":"hall","strategist":"wu_yong","scout":"shi_qian","chai":"chai_jin","yue":"yue_he","gate":"zhu_gate","lu":"lu_junyi","shi":"shi_xiu","enemy_hq":"hall"}
const SPY_ART := {"scout":"shi_qian_lantern","chai":"chai_jin_officer","yue":"yue_he_officer"}
func bad(code: String) -> Dictionary:return {"ok":false,"code":"LEVEL8_"+code}
func _fields(v: Variant,n: Array) -> bool:return typeof(v)==TYPE_DICTIONARY and v.size()==n.size() and v.has_all(n)
func configure(value: Dictionary) -> Dictionary:
	if not _fields(value,["values","references","external"]):return bad("ROLES")
	var refs: Variant=value.references
	if not _fields(refs,["hall","strategist","scout","chai","yue","gate","lu","shi","enemy_hq","posts","towers","spies","workers","enemy_workers","reserve","pursuit","escorts"]):return bad("REFERENCE_FIELDS")
	if typeof(value.values)!=TYPE_DICTIONARY or typeof(value.values.get("rescued"))!=TYPE_BOOL or not value.external.is_empty():return bad("STAGE_FIELDS")
	actors.clear();pools.clear();roles=value.duplicate(true)
	for field in NAMED:
		var id: Variant=refs[field]
		if id==null:continue
		if typeof(id)!=TYPE_STRING or not id.is_valid_int() or str(id.to_int())!=id or id.to_int()<=0 or actors.has(id):return bad("NAMED_ID")
		actors[id]={"role":field,"key":NAMED[field]}
	if typeof(refs.spies)!=TYPE_ARRAY or refs.spies!=[refs.scout,refs.chai,refs.yue]:return bad("SPY_MEMBERSHIP")
	if typeof(refs.posts)!=TYPE_ARRAY or refs.posts.size()!=2:return bad("POST_COUNT")
	for field in ["posts","towers","workers","enemy_workers","reserve","pursuit","escorts"]:
		if typeof(refs[field])!=TYPE_ARRAY:return bad("POOL_TYPE")
		for id in refs[field]:
			if id==null:continue
			if typeof(id)!=TYPE_STRING or not id.is_valid_int() or id.to_int()<=0 or pools.has(id) or actors.has(id):return bad("POOL_ID")
			pools[id]=field
	return {"ok":true}

func values(v: Dictionary) -> Dictionary:
	var role: Dictionary=actors.get(str(v.entity_id),{});var name: String=role.get("role","")
	if v._story_pose_t!=0.0 or v._pose_previous_variant!="" or v.defeat_outcome!="":return bad("UNSUPPORTED_STORY_POSE")
	if v.story_outcome!="":
		var retired_gate: bool=name=="gate" and v.story_outcome=="retreated" and roles.values.gate_open
		var safe_prisoner: bool=name in ["lu","shi"] and v.story_outcome=="retreated" and roles.values.rescued and roles.values.prison_open and roles.values.gate_open
		if not retired_gate and not safe_prisoner:return bad("UNSUPPORTED_STORY_OUTCOME")
		if safe_prisoner:
			var stopped: Dictionary=_safe_retreat_values(v)
			if not stopped.ok:return stopped
	if not role.is_empty() and v.key!=role.key:return bad("ROLE_KEY")
	if (v.hp<=0.0)!=v._dying:return bad("LIFETIME")
	if name in ["lu","shi"]:
		if v.is_building or not v.is_noncombat or v.atk!=0.0 or v.ability!="" or not v.ability_slots.is_empty():return bad("PRISONER_IDENTITY")
		if roles.values.rescued:
			if v.is_captive or v.is_hero or v.faction!=0 or v.base_speed!=68.0 or v.art_variant!="daming_rescued_"+v.key:return bad("RESCUED_IDENTITY")
		elif not v.is_captive or not v.is_hero or v.faction!=2 or v.base_speed!=0.0 or v.art_variant!="daming_bound_"+v.key:return bad("BOUND_IDENTITY")
	else:
		if v.is_captive or v.faction not in [0,1]:return bad("UNREGISTERED_CAPTIVE_OR_FACTION")
		if name in ["hall","strategist","scout","chai","yue"] and v.faction!=0:return bad("FRIENDLY_ROLE")
		if name in ["gate","enemy_hq"] and v.faction!=1:return bad("ENEMY_ROLE")
	if SPY_ART.has(name) and (v.art_variant!=SPY_ART[name] or not v.is_hero or v.is_building or v.is_summon):return bad("DISGUISE_IDENTITY")
	if name=="gate" and (not v.is_building or v.art_variant!="daming_south_gate"):return bad("GATE_IDENTITY")
	var pool: String=pools.get(str(v.entity_id),"")
	if pool in ["workers","enemy_workers"] and (v.key!="lou_luo" or not v.is_worker or v.faction!=(0 if pool=="workers" else 1)):return bad("WORKER_IDENTITY")
	if pool=="posts" and (v.key!="barracks" or v.faction!=1 or not v.is_building):return bad("POST_IDENTITY")
	if pool=="towers" and (v.key!="arrow_tower" or v.faction!=1 or not v.is_building):return bad("TOWER_IDENTITY")
	if pool in ["reserve","pursuit","escorts"] and (v.faction!=1 or v.is_building or v.is_worker or v.is_noncombat):return bad("GUARD_IDENTITY")
	return {"ok":true}

func parts(v: Dictionary,refs: Dictionary,meta: Dictionary,_node: Dictionary) -> Dictionary:
	var role: String=actors.get(str(v.entity_id),{}).get("role","")
	if refs.story_assist_owner.state!="none" or refs.story_assist_partner.state!="none" or meta.has("story_pose"):return bad("ASSISTANCE_OR_POSE")
	if role in ["lu","shi"] and v.story_outcome=="retreated":
		if _node.visible:return bad("SAFE_RETREAT_VISIBLE")
		if not refs._queue.is_empty():return bad("SAFE_RETREAT_QUEUE")
		for field: String in ["_target","_pending_target","_hua_lock_target"]:
			if refs[field].state!="none":return bad("SAFE_RETREAT_TARGET")
	if SPY_ART.has(role):
		if typeof(meta.get("daming_covered"))!=TYPE_BOOL:return bad("COVER_TYPE")
		for field in ["daming_suspicion","daming_recover"]:
			if typeof(meta.get(field))!=TYPE_FLOAT or not is_finite(meta[field]) or meta[field]<0.0 or meta[field]>(2.5 if field=="daming_suspicion" else 3.0):return bad("DISGUISE_TIMER")
	elif meta.has("daming_covered") or meta.has("daming_suspicion") or meta.has("daming_recover"):return bad("FOREIGN_DISGUISE_METADATA")
	if pools.get(str(v.entity_id))=="enemy_workers":
		if typeof(meta.get("daming_mine"))!=TYPE_DICTIONARY or not meta.daming_mine.has("state"):return bad("MINE_REFERENCE")
	elif meta.has("daming_mine"):return bad("FOREIGN_MINE_REFERENCE")
	if meta.has("source_lane"):
		if typeof(meta.source_lane)!=TYPE_INT or meta.source_lane not in [0,1]:return bad("SUPPORT_LANE")
		# The authored support dispatcher filters dead escorts, while dying Unit children remain.
		if pools.get(str(v.entity_id))!="escorts" and not (v._dying and v.faction==1 and v.key in ["guan_dao","guan_gong"]):return bad("UNREGISTERED_SUPPORT_LANE")
	return {"ok":true}

# Structural Unit component only. Complete Core additionally pairs these fixed
# roles with the validated Mission safe events before accepting a whole world.
func _safe_retreat_values(v: Dictionary) -> Dictionary:
	if v.hp<1.0 or v._dying or not v.passive or v.stance!=3 or v.selected:return bad("SAFE_RETREAT_LIFETIME")
	if v._state!=0 or not v._path.is_empty() or v._patrolling or v._resume_amove or v._hold_order_active:return bad("SAFE_RETREAT_ORDER")
	if v._chase_intent!=0 or v._group_cap!=0.0 or not v._has_home or v._home!=v.position or v._hua_lock_shots!=0:return bad("SAFE_RETREAT_STOP_ANCHOR")
	if v.mission_order_active or v.mission_order_token!=0 or v.mission_order_arrival_t!=0.0 or v.mission_order_target!=Vector2.INF:return bad("SAFE_RETREAT_MISSION_ORDER")
	if not v._pending_done or v._lunge!=0.0 or v._cast_t!=0.0 or v._stepped or v._move_blend!=0.0:return bad("SAFE_RETREAT_PENDING")
	# Exact installed Level condition; no map instance, deployment, or tick is made.
	var exit_position:=Vector2(DamingLevel.EXIT_CELL.x*MapScript.CELL+MapScript.CELL*0.5,DamingLevel.EXIT_CELL.y*MapScript.CELL+MapScript.CELL*0.5)
	if v.position.distance_to(exit_position)>130.0 or floor(v.position.y/MapScript.CELL)<45.0:return bad("SAFE_RETREAT_EXIT")
	return {"ok":true}

func membership(states: Dictionary,active: Array) -> Dictionary:
	for id in actors.keys()+pools.keys():
		if not states.has(id):return bad("ROLE_NOT_IN_GRAPH")
		var state: Dictionary=states[id];var v: Dictionary=state.values
		if active.has(id)!=(v.hp>0.0 and not v._dying):return bad("ACTIVE_MEMBERSHIP")
		if pools.get(id)=="enemy_workers":
			var tag: Dictionary=state.metadata.daming_mine
			if tag.state=="entity" and (not states.has(tag.id) or states[tag.id].values.key!="gold_mine" or not states[tag.id].values.is_resource):return bad("MINE_IDENTITY")
	return {"ok":true,"complete_world":false}
