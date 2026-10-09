extends "res://tools/art_character_direction4_qa.gd"
## Actual installed Gao map/scenery roundtrip; no world continuation claim.
var Maps: Script
var SceneryState: Script
var B: Script
var M: Script
var L: Script
var Factory: Script
var trusted: Dictionary
var context := {"mode":"campaign","level_id":"level5","waves":0}

func _roundtrip_map(b, label: String) -> void:
	var maps = Maps.new(trusted.content_version, context)
	var original: Dictionary = maps.capture(b.map)
	check(original.ok,label+" actual original map capture")
	if not original.ok: print(original); return
	check(b.map.decor.all(func(d: Array) -> bool: return d[0] != "boat"),label+" gameplay decor keeps original filtered boat state")
	var original_layout: Array=load("res://scripts/levels/skirmish.gd").liangshan_visual_decor()
	var boat_cells: Array=[]
	for d: Array in original_layout:
		if d[0]=="boat":boat_cells.append(b.map.cell_to_world(d[1]))
	var original_boats:=0
	for node: Node in b.map.sample_scenery._sprites:
		if boat_cells.has(node.position):original_boats+=1
	check(original_boats==4,label+" four original decorative boat visuals retained separately from gameplay decor")
	var display: Dictionary = maps.validate(original.value).value.display
	check(display.schema=="level5_native_scenery_state_v1" and display.kind=="campaign_level5",label+" native installed chapter envelope")
	check(not SceneryState.new(trusted.content_version).validate(display).ok,label+" default context rejects native chapter")
	check(not SceneryState.new(trusted.content_version,{"mode":"campaign","level_id":"level3","waves":0}).validate(display).ok,label+" other chapter rejects envelope")
	check(not SceneryState.new(trusted.content_version,{"mode":"campaign","level_id":"level5","waves":0.0}).validate(display).ok,label+" floating wave count rejected")
	var bad: Dictionary = display.duplicate(true)
	bad.ownership.sprites.erase(bad.ownership.sprites[0])
	check(not SceneryState.new(trusted.content_version,context).validate(bad).ok,label+" missing native sprite owner rejected")
	bad=display.duplicate(true); bad.ownership.entrance=0
	check(not SceneryState.new(trusted.content_version,context).validate(bad).ok,label+" root impersonating entrance rejected")
	bad=display.duplicate(true); bad.ownership.trees.append(bad.ownership.trees[0])
	check(not SceneryState.new(trusted.content_version,context).validate(bad).ok,label+" duplicate tree owner rejected")
	bad=display.duplicate(true); bad.ownership.sprites=null
	check(not SceneryState.new(trusted.content_version,context).validate(bad).ok,label+" null owner lane safely rejected")
	bad=display.duplicate(true); bad.ownership.trees.erase(bad.ownership.trees[0])
	check(not SceneryState.new(trusted.content_version,context).validate(bad).ok,label+" missing actual tree rejected")
	var owner=B.new(); owner.process_mode=Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true); owner._cursor_resources_released=true
	owner.world=Node2D.new(); owner.world.transform=M.ISO; owner.add_child(owner.world)
	owner.map=M.new(); owner.world.add_child(owner.map); owner.level=L.new()
	owner.fog=b.fog; owner._vision=b._vision.duplicate()
	var staged: Dictionary=maps.stage_map_values(owner.map,original.value)
	check(staged.ok and not staged.complete,label+" authoritative map staged with pending display")
	if not staged.ok:print(staged);owner.free();return
	var runtime: Dictionary=Factory.prepare_runtime(trusted)
	check(runtime.ok,label+" inert runtime from installed content")
	owner._defs=runtime.runtime.defs; owner._abilities=runtime.runtime.abilities; owner._items=runtime.runtime.items
	var rng: Dictionary=owner.configure_restored_gameplay_rng(trusted,b.capture_gameplay_rng().record)
	check(rng.ok,label+" original RNG staged")
	var guard: Dictionary=SceneryState.new(trusted.content_version,context)._campaign_gameplay_guard(owner.map)
	var finished: Dictionary=maps.finish_display(owner.map,original.value)
	check(finished.ok,label+" native visual rebuilt by original fixed factory")
	if not finished.ok:print(finished);owner.free();return
	check(not finished.complete and finished.display_requires_activation,label+" pending synchronous outer world activation explicit")
	var adapter=finished.display_adapter
	check(adapter._campaign_gameplay_guard(owner.map)==guard,label+" factory preserves all five nav grids, terrain, height, resources and RNG")
	var again: Dictionary=maps.capture(owner.map)
	check(again.ok,label+" reconstructed complete map recapture")
	if not again.ok:print(again)
	else:
		check(again.value==original.value,label+" exact full map/scenery envelope preserved")
		if again.value!=original.value:print("RECAPTURE_DIFF ",label)
	var source_guard: Dictionary=maps.capture(b.map)
	check(source_guard.ok and source_guard.value==original.value,label+" live source map unchanged")
	art_runtime.append({"case":label,"nodes":display.nodes.size(),"sprites":display.ownership.sprites.size(),"trees":display.ownership.trees.size(),"guard_posts":display.ownership.guard_posts.size(),"exact_map_recapture":again.ok and again.value==original.value,"snapshot_sha256":JSON.stringify(original.value).sha256_text(),"scope":"Original installed map including five nav grids and native scenery/height/material/reed/owner arrays rebuilt in disabled detached Battle/Level shell. No Unit/clock/Mission/full world activation or independent process continuation."})
	adapter.dispose_campaign(); owner.free()

func _classic_regression() -> void:
	var b=await _start("skirmish",0)
	for frame in range(4):await physics_frame
	await process_frame;paused=true
	var maps=Maps.new(trusted.content_version)
	var original: Dictionary=maps.capture(b.map)
	check(original.ok,"classic original standard scenery captured after pure layout extraction")
	if not original.ok:print(original);paused=false;await _dispose(b);return
	var owner=B.new();owner.process_mode=Node.PROCESS_MODE_DISABLED;owner._cursor_resources_released=true
	owner.world=Node2D.new();owner.world.transform=M.ISO;owner.add_child(owner.world)
	owner.map=M.new();owner.world.add_child(owner.map)
	owner.level=load("res://scripts/levels/skirmish.gd").new();owner.fog=b.fog;owner._vision=b._vision.duplicate()
	var staged: Dictionary=maps.stage_map_values(owner.map,original.value)
	check(staged.ok and not staged.complete,"classic standard authoritative map staged")
	if not staged.ok:print(staged);owner.free();paused=false;await _dispose(b);return
	var finished: Dictionary=maps.finish_display(owner.map,original.value)
	check(finished.ok and finished.complete,"classic standard display factory completion unchanged")
	var again: Dictionary=maps.capture(owner.map) if finished.ok else {"ok":false}
	check(again.ok and again.value==original.value,"classic exact original complete map/scenery recapture")
	var unchanged: Dictionary=maps.capture(b.map)
	check(unchanged.ok and unchanged.value==original.value,"classic source map stays unchanged")
	art_runtime.append({"case":"classic30 standard map","exact_map_recapture":again.ok and again.value==original.value,"scope":"Original normal classic map/scenery factory regression only, not a complete save/continue or full playthrough."})
	owner.free();paused=false;await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	Maps=load("res://scripts/run_map_state.gd"); SceneryState=load("res://scripts/run_scenery_state.gd")
	B=load("res://scripts/battle.gd"); M=load("res://scripts/game_map.gd"); L=load("res://scripts/levels/level5_gao_rts.gd")
	Factory=load("res://scripts/run_level5_world_factory.gd")
	art_output=OS.get_environment("ART_QA_OUT"); art_character="gao_scenery_v20g"; art_visual=false
	trusted=_art_identity(); check(trusted.get("save_eligible",false),"installed content identity")
	if not trusted.get("save_eligible",false):_art_finish();return
	var b=await _start("",4)
	for frame in range(4):await physics_frame
	await process_frame; paused=true
	await _roundtrip_map(b,"level5 initial")
	b.level._send_wave(b,0); await process_frame
	await _roundtrip_map(b,"level5 wave sent")
	paused=false; await _dispose(b); await _classic_regression(); _art_finish()
