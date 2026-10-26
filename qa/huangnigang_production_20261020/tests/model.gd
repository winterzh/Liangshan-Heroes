extends "base.gd"
const Model=preload("res://scripts/huangnigang_transport.gd")
var phrase_alias_summary: Dictionary = {}

func translation_snapshot(localize: Variant, catalog_keys: Array = []) -> Array:
	var result: Array = []
	for table: Translation in localize._translations:
		var row: Dictionary = {}
		var keys: Variant = table.get_message_list() if catalog_keys.is_empty() else catalog_keys
		for source: String in keys: row[source] = String(table.get_message(source))
		result.append(row)
	return result

func plain_phrase(localize: Variant, source: String, args: Array) -> String:
	# Deliberately avoid format_text while producing the historical string.
	# Alias checks must work without creating a format-history descriptor.
	var localized: Array = []
	for value: Variant in args: localized.append(localize.text(value) if value is String else value)
	return localize.text(source) % localized

func fixed_phrase_aliases() -> void:
	var localize: Variant = root.get_node("Localize")
	var initial_locale: String = localize.locale
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var ordinary_before: Array = translation_snapshot(localize, catalog.keys())
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.get("ok", false), "actual prepare_runtime registers fixed transport aliases")
	if not runtime.get("ok", false): print("ALIAS_RUNTIME ", runtime); return
	check(translation_snapshot(localize, catalog.keys()) == ordinary_before, "initial alias registration preserves every ordinary catalog key and translation")
	var samples: Array = [
		{"kind": "take", "source": "%s · 第%d车（%d担）%s", "args": ["幸存七星", 7, 1, "接手"]},
		{"kind": "load", "source": "%s · 推第%d车装入%d担", "args": ["晁盖", 7, 1]},
		{"kind": "deliver", "source": "%s · 推第%d车（%d担）出冈", "args": ["吴用", 2, 2]},
		{"kind": "selector", "source": "选中 · %s", "args": ["晁盖"]},
		{"kind": "selector", "source": "选中 · %s", "args": ["刘唐"]},
		{"kind": "selector", "source": "选中 · %s", "args": ["吴用"]},
		{"kind": "selector", "source": "选中 · %s", "args": ["白胜"]}]
	var old_strings: Dictionary = {}
	for locale: String in localize.LOCALES:
		localize.set_language(locale, false)
		old_strings[locale] = []
		for sample: Dictionary in samples: old_strings[locale].append(plain_phrase(localize, sample.source, sample.args))
	var mismatches: Array = []
	var pairs := 0
	var nested_template := "已定位：%s。选中%s后右键旗标，停留%s秒。"
	for target: String in localize.LOCALES:
		localize.set_language(target, false)
		for origin: String in localize.LOCALES:
			for i in range(samples.size()):
				var sample: Dictionary = samples[i]
				var previous: String = old_strings[origin][i]
				var expected: String = plain_phrase(localize, sample.source, sample.args)
				var actual: String = localize.text(previous)
				var nested: String = localize.format_text(nested_template, [previous, "晁盖", "0.6"])
				var nested_expected: String = localize.text(nested_template) % [expected, localize.text("晁盖"), "0.6"]
				pairs += 1
				if actual != expected or nested != nested_expected:
					mismatches.append({"kind": sample.kind, "origin": origin, "target": target, "historical_phrase": previous,
						"expected": expected, "actual": actual, "nested_expected": nested_expected, "nested_actual": nested})
	check(pairs == 112 and mismatches.is_empty(), "transport and all four actor selectors translate historical text and nested notices across every language pair without format history")
	var all_registered_before: Array = translation_snapshot(localize)
	var reverse_before: Dictionary = localize._display_sources.duplicate(true)
	var repeated: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(repeated.get("ok", false), "second actual prepare_runtime succeeds")
	check(translation_snapshot(localize) == all_registered_before and localize._display_sources == reverse_before, "repeated runtime preparation leaves all registered messages and reverse aliases unchanged")
	check(translation_snapshot(localize, catalog.keys()) == ordinary_before, "repeated alias registration still preserves every ordinary catalog translation")
	phrase_alias_summary = {"families": 4, "samples": 7, "language_pairs_checked": pairs, "mismatches": mismatches,
		"ordinary_catalog_keys_checked": catalog.size(), "old_strings_generated_without_format_history": true,
		"registration_entry": "run_level1_world_factory.prepare_runtime", "normal_and_cold_runtime_share_registration": true}
	localize.set_language(initial_locale, false)

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	fixed_phrase_aliases()
	if not failures.is_empty(): report({"phrase_aliases": phrase_alias_summary}); return
	var unique: Dictionary={}
	for cart in range(7):
		for load_index in Model.loads(cart):
			if unique.has(load_index):failures.append("duplicate declared load")
			unique[load_index]=true
	check(unique.size()==11 and range(11).all(func(i):return unique.has(i)),"all eleven distinct load identities are assigned exactly once")
	check(Model.OWNERS.size()==7 and not Model.OWNERS.has("bai_sheng"),"seven named merchants handle carts; wine seller is not substituted")
	var state_failures: Array=[];var complete_states:=0
	for encoded in range(78125):
		var digits: Array=[];var value:=encoded
		var loaded: Dictionary={};var carried: Dictionary={};var delivered: Array=[];var empty: Array=[];var empty_carried: Dictionary={}
		var expected_delivered:=0;var expected_loaded_weight:=0
		for cart in range(7):
			var state: int=value%5;value=value/5;digits.append(state)
			var independent_weight:=2 if cart<4 else 1
			if state<2:empty.append(cart)
			else:loaded[cart]=true;expected_loaded_weight+=independent_weight
			if state==1:empty_carried[cart]=["chao_gai","wu_yong","gongsun_sheng","liu_tang","ruan_xiaoer","ruan_xiaowu","ruan_xiaoqi"][cart]
			if state==3:carried[cart]=["chao_gai","wu_yong","gongsun_sheng","liu_tang","ruan_xiaoer","ruan_xiaowu","ruan_xiaoqi"][cart]
			if state==4:delivered.append(cart);expected_delivered+=independent_weight
		var active: Array=[]
		# Independent membership oracle, not calls to Model.loads/cart_for_load.
		for load_index in range(11):
			var parent: int=load_index if load_index<7 else load_index-7
			if digits[parent]<2 or (load_index<7 and digits[parent] in [2,4]):active.append(load_index)
		var result:=Model.validate_membership(loaded,carried,delivered,active,empty,false,empty_carried)
		if not result.ok:state_failures.append(encoded);continue
		if result.raw_loads.size()+expected_loaded_weight!=11 \
			or result.empty_carts.size()+result.world_carts.size()+result.carried_carts.size()!=7 \
			or result.stowed_loads.size()+active.size()!=11 \
			or result.delivered_loads!=expected_delivered:state_failures.append(encoded)
		if result.complete:complete_states+=1
	check(state_failures.is_empty(),"all5^7 empty-ground/empty-moving/loaded-ground/carried/delivered states conserve seven carts and eleven IDs")
	check(complete_states==1,"only all seven delivered carts complete the eleven-load objective")
	check(not Model.ledger({0:true},{0:"wu_yong"},[]).ok,"canonical carrier cannot borrow another cart owner")
	check(Model.ledger({0:true},{0:"wu_yong"},[],true).ok,"explicit noncanonical survivor relay can retain the same cargo identities")
	check(not Model.ledger({0:true,1:true},{0:"liu_tang",1:"liu_tang"},[],true).ok,"one actor cannot carry two carts simultaneously")
	check(not Model.ledger({0:true},{0:"bai_sheng"},[],true).ok,"wine seller cannot become an eighth cart operator")
	check(not Model.ledger({0:true},{7:"chao_gai"},[]).ok,"secondary load cannot masquerade as another cart")
	check(not Model.ledger({0:true},{0:"chao_gai"},[0]).ok,"same cart cannot be both carried and delivered")
	check(not Model.ledger({}, {},[0]).ok,"unloaded cart cannot be credited as delivered")
	check(not Model.ledger({0:true},{},[0,0]).ok,"duplicate delivery cannot double-count two loads")
	check(not Model.ledger({0:false},{},[]).ok,"false loaded flag is rejected rather than silently treated as packing")
	check(not Model.ledger({7:true},{},[]).ok,"eighth cart is rejected")
	check(not Model.ledger({0.0:true},{},[]).ok,"floating cart key is rejected")
	check(not Model.validate_membership({}, {},[],range(10),range(7)).ok,"missing eleventh raw load is rejected")
	check(not Model.validate_membership({}, {},[],range(11)+[0],range(7)).ok,"duplicate active load cannot stand in for another load")
	check(not Model.validate_membership({0:true},{0:"chao_gai"},[],range(11),range(1,7)).ok,"packed secondary identities cannot remain visible as extra cargo")
	check(Model.cart_for_load(-1)==-1 and Model.cart_for_load(11)==-1,"outside load identity cannot enter the layout")
	check(Model.ledger({}, {}, [], false, {6:"ruan_xiaoqi"}).ok,"original seventh empty cart can retain its actual owner before loading")
	check(not Model.ledger({6:true}, {6:"ruan_xiaoqi"}, [], false, {6:"ruan_xiaoqi"}).ok,"same cart cannot be empty-moving and loaded-carried simultaneously")
	check(not Model.ledger({0:true}, {0:"chao_gai"}, [], true, {6:"chao_gai"}).ok,"one Star cannot push an empty cart while carrying a loaded cart")
	check(not Model.ledger({}, {}, [], true, {6:"bai_sheng"}).ok,"wine seller cannot operate an empty cart")
	report({"phrase_aliases": phrase_alias_summary,"states_tested":78125,"state_failure_examples":state_failures.slice(0,12),"actual_level_or_save_acceptance":false,"scope":"Pure production GDScript transport contract; physical path and actual save evidence are separate drivers."})
