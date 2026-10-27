extends RefCounted
## Chapter16 inventory: eleven distinct loads are packed into the same seven carts.
## Which load goes into which cart/which named hero handles it is a game allocation,
## not a per-cart distribution specified by the novel. No mutable progress lives here.
const CART_COUNT := 7
const LOAD_COUNT := 11
const OWNERS := ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]
const GROUPS := [[0,7],[1,8],[2,9],[3,10],[4],[5],[6]]

static func is_cart(index: Variant) -> bool:
	return typeof(index)==TYPE_INT and index>=0 and index<CART_COUNT

static func loads(index: int) -> Array:
	return GROUPS[index].duplicate() if is_cart(index) else []

static func weight(index: int) -> int:
	return GROUPS[index].size() if is_cart(index) else 0

static func owner(index: int) -> String:
	return OWNERS[index] if is_cart(index) else ""

static func cart_for_load(index: int) -> int:
	if index<0 or index>=LOAD_COUNT:return -1
	for cart in range(CART_COUNT):
		if index in GROUPS[cart]:return cart
	return -1

static func valid_loaded(value: Variant) -> bool:
	if typeof(value)!=TYPE_DICTIONARY or value.size()>CART_COUNT:return false
	for key in value:
		if not is_cart(key) or typeof(value[key])!=TYPE_BOOL or value[key]!=true:return false
	return true

static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}

static func ledger(loaded: Variant, carried: Variant, delivered: Variant, allow_relay: bool=false,
		empty_carried: Variant={}) -> Dictionary:
	# loaded is the existing cargo_ready dictionary. carried maps primary cart
	# index to an actor key; delivered is the exact set of delivery event indices.
	# Secondary load identities stay scene-owned, hidden and disabled after packing.
	if not valid_loaded(loaded):return _bad("LOADED_CART_SET")
	if typeof(carried)!=TYPE_DICTIONARY or carried.size()>CART_COUNT:return _bad("CARRIED_CART_SET")
	if typeof(empty_carried)!=TYPE_DICTIONARY or empty_carried.size()>CART_COUNT:return _bad("EMPTY_CARRIED_CART_SET")
	if typeof(delivered)!=TYPE_ARRAY or delivered.size()>CART_COUNT:return _bad("DELIVERED_CART_SET")
	var delivered_set: Dictionary={};var actor_set: Dictionary={};var delivered_loads:=0
	for index in delivered:
		if not is_cart(index) or delivered_set.has(index) or not loaded.has(index):return _bad("DELIVERED_CART_REFERENCE")
		delivered_set[index]=true;delivered_loads+=weight(index)
	for index in carried:
		if not is_cart(index) or not loaded.has(index) or delivered_set.has(index):return _bad("CARRIED_CART_REFERENCE")
		var actor: Variant=carried[index]
		if typeof(actor)!=TYPE_STRING or actor not in OWNERS or actor_set.has(actor):return _bad("CART_CARRIER")
		if not allow_relay and actor!=owner(index):return _bad("CART_OWNER")
		actor_set[actor]=true
	for index in empty_carried:
		if not is_cart(index) or loaded.has(index) or carried.has(index) or delivered_set.has(index):
			return _bad("EMPTY_CARRIED_CART_REFERENCE")
		var actor: Variant=empty_carried[index]
		if typeof(actor)!=TYPE_STRING or actor not in OWNERS or actor_set.has(actor):return _bad("CART_CARRIER")
		if not allow_relay and actor!=owner(index):return _bad("CART_OWNER")
		actor_set[actor]=true
	var raw_loads: Array=[];var stowed_loads: Array=[];var empty_carts: Array=[];var world_carts: Array=[]
	for index in range(CART_COUNT):
		if not loaded.has(index):
			empty_carts.append(index);raw_loads.append_array(loads(index));continue
		for load_index in loads(index):
			if load_index!=index or carried.has(index):stowed_loads.append(load_index)
		if not carried.has(index):world_carts.append(index)
	return {"ok":true,"raw_loads":raw_loads,"stowed_loads":stowed_loads,
		"empty_carts":empty_carts,"world_carts":world_carts,"carried_carts":carried.keys(),
		"empty_carried_carts":empty_carried.keys(),
		"delivered_carts":delivered_set.keys(),"delivered_loads":delivered_loads,
		"complete":delivered_set.size()==CART_COUNT and delivered_loads==LOAD_COUNT}

static func validate_membership(loaded: Variant, carried: Variant, delivered: Variant,
		active_loads: Variant, empty_cart_indices: Variant, allow_relay: bool=false,
		empty_carried: Variant={}) -> Dictionary:
	var expected:=ledger(loaded,carried,delivered,allow_relay,empty_carried)
	if not expected.ok:return expected
	if typeof(active_loads)!=TYPE_ARRAY or typeof(empty_cart_indices)!=TYPE_ARRAY:return _bad("WORLD_MEMBERSHIP_TYPE")
	var wanted: Array=expected.raw_loads.duplicate();wanted.append_array(expected.world_carts)
	for pair in [[active_loads,wanted],[empty_cart_indices,expected.empty_carts]]:
		var seen: Dictionary={}
		for value in pair[0]:
			if typeof(value)!=TYPE_INT or seen.has(value) or value not in pair[1]:return _bad("WORLD_MEMBERSHIP")
			seen[value]=true
		if seen.size()!=pair[1].size():return _bad("WORLD_MEMBERSHIP")
	return expected
