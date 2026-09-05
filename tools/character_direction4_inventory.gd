extends "res://tools/skirmish_direction4_contract_test.gd"
## Complete production registry inventory. Exact files only: a borrowed source,
## single facing animation or directional idle fallback is not a new action.
func _run() -> void:
	var art=root.get_node("Art")
	var definitions: Dictionary=load("res://scripts/defs.gd").UNITS
	var enemies: Dictionary=_derive_enemy_roster(load("res://scripts/levels/skirmish.gd"))
	var rows: Array=[]
	var totals := {"mobile_definitions":0,"idle_four":0,"walk_four":0,"attack_four":0,"death_four":0,"has_reference":0,"defense_enemy_keys":enemies.weights.size(),"defense_enemy_idle_instances":0,"defense_enemy_instances":0}
	for key in definitions:
		var d: Dictionary=definitions[key]
		if d.get("building",false) or d.get("resource",false): continue
		var entry: Dictionary={"key":key,"name":d.name,"hero":d.get("hero",false),"defense_enemy_instances":enemies.weights.get(key,0),"directions":{},"source_paths":{}}
		var texture=art.unit_texture(key)
		entry["has_reference"]=texture!=null
		if texture!=null:
			totals.has_reference+=1
			entry["reference_source"]=_frame_source(texture)
			if texture is AtlasTexture: entry["reference_region"]=str(texture.region)
		for state in ["idle","walk","attack","death"]:
			var dirs: Array=[]
			var paths: Array=[]
			for direction in CA.DIRECTIONS:
				var path: String="res://assets/anim/%s_%s_%s.png" % [key,state,direction]
				if ResourceLoader.exists(path): dirs.append(direction); paths.append(path)
			entry.directions[state]=dirs
			entry.source_paths[state]=paths
			if dirs.size()==4: totals[state+"_four"]+=1
		if entry.directions.idle.size()==4: totals.defense_enemy_idle_instances+=int(entry.defense_enemy_instances)
		totals.defense_enemy_instances+=int(entry.defense_enemy_instances)
		totals.mobile_definitions+=1
		rows.append(entry)
	rows.sort_custom(func(a,z):
		if a.defense_enemy_instances!=z.defense_enemy_instances: return a.defense_enemy_instances>z.defense_enemy_instances
		return a.key<z.key)
	var folder: String="res://qa/character_direction4_inventory_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"totals":totals,"units":rows,"scope":"All mobile definitions including transport, siege and summons; campaign costume variants are separate and not counted as generic combat art."},"\t")+"\n")
	var f=FileAccess.open(folder+"/inventory.csv",FileAccess.WRITE)
	f.store_csv_line(["key","name","defense_enemy_instances","has_reference","idle_directions","walk_directions","attack_directions","death_directions"])
	for row in rows:
		f.store_csv_line([row.key,row.name,str(row.defense_enemy_instances),str(row.has_reference),str(row.directions.idle.size()),str(row.directions.walk.size()),str(row.directions.attack.size()),str(row.directions.death.size())])
	print("[character-direction4] ",JSON.stringify(totals))
	quit()
