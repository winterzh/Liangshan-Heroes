extends "res://tools/zhujiazhuang_rts_test.gd"
## Geometry, source reuse, gate seams, actual blocking and wall occlusion.
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _start()
	var Renderer=load("res://scripts/liangshan_stockade.gd")
	var Environment=load("res://scripts/campaign_environment_art.gd")
	var Map=load("res://scripts/game_map.gd")
	var texture=Environment.object("level5","stockade_segment")
	check(FileAccess.get_sha256("res://assets/campaign/environment/level5/stockade_segment.png")=="e1f807ef74b32a7bd16bc14705a1436938b6942da34018f96294d11a834a0c44","accepted original stockade bitmap remains byte-identical")
	for end in [Vector2(96,48),Vector2(-96,48),Vector2(-96,-48),Vector2(96,-48),Vector2(96,62),Vector2(-96,31)]:
		var wall=Renderer.new()
		wall.campaign_texture=texture
		wall.end_local=end
		wall.height_scale=78
		var tr: Transform2D=wall.source_transform()
		check((tr*Renderer.CAMPAIGN_LEFT_FOOT).length()<0.001,"left actual post foot lies on wall origin: "+str(end))
		check((tr*Renderer.CAMPAIGN_RIGHT_FOOT).distance_to(end)<0.001,"right actual post foot lies on map endpoint: "+str(end))
		var post: Vector2=tr*(Renderer.CAMPAIGN_LEFT_FOOT-Vector2(0,98))-tr*Renderer.CAMPAIGN_LEFT_FOOT
		check(absf(post.x)<0.001 and absf(post.y+78)<0.001,"upright post preserves height on this axis and slope: "+str(end))
		wall.free()
	for id in ["level3","level5"]:
		check(Environment.object(id,"stockade_segment")==texture,"explicit generic timber reuse in "+id)
	for id in ["level1","level4","level7","level8","arena"]:
		check(Environment.object(id,"stockade_segment")==null,"wooden wall reuse does not leak into "+id)
	await _dispose(b)
	for scene in [["",2],["",4],["skirmish",4]]:
		b=await _start(scene[0],scene[1])
		b.phase=b.Phase.DEPLOY
		b.fog=false
		for u in b.units: u.set_physics_process(false)
		var walls: Array=b.map.sample_scenery._walls if scene[1] in [2,6] else b.map.sample_scenery._entrance._wall_parts
		var label: String=b.level.id()
		check(not walls.is_empty() and walls.all(func(w): return w.get_script()==Renderer and w.campaign_texture==texture),label+" uses one consistent accepted timber source on both wall axes")
		check(walls.all(func(w):
			var tr: Transform2D=w.source_transform()
			return (tr*Renderer.CAMPAIGN_LEFT_FOOT).length()<0.001 and (tr*Renderer.CAMPAIGN_RIGHT_FOOT).distance_to(w.end_local)<0.001),label+" real wall parts match both projected map endpoints")
		check(walls.all(func(w):
			return w.body_overlaps(w.end_local*0.5-Vector2(0,w.height_scale*0.6)) and not w.body_overlaps(w.end_local*0.5-Vector2(0,w.height_scale*2+50))),label+" occlusion covers upright wall height and excludes empty sky")
		if scene[1]==2:
			var endpoints: Array=[]
			for w in walls: endpoints.append(b.map.project(w.position)); endpoints.append(b.map.project(w.position)+w.end_local)
			for gate in [b.level.gate,b.level.side_gate]:
				var center: Vector2=b.map.project(gate.position)
				var half: Vector2=Map.ISO*gate.get_meta("campaign_gate_wall_span")*0.5
				check(endpoints.any(func(p): return p.distance_to(center-half)<0.01),gate.display_name+" north wall foot meets gate foot")
				check(endpoints.any(func(p): return p.distance_to(center+half)<0.01),gate.display_name+" south wall foot meets gate foot")
			for cell in [Vector2i(20,12),b.level.MAIN_GATE,b.level.SIDE_GATE]:
				check(not b.map.is_open_cell(cell),"visual correction preserves blocked wall/gate cell "+str(cell))
			var wall=walls[0]
			var p: Vector2=wall.position+Map.ISO_INV*wall.end_local*0.5-Vector2(24,24)
			var probe=b.spawn_unit("liang_dao",0,p)
			probe.set_physics_process(false)
			b._grid_build()
			b.select_single(probe,false)
			await _wait(0.35)
			check(wall.modulate.a<0.7,"real soldier behind upright wall makes occluding wall translucent")
			check(b._friendly_at(b.to_screen(probe.position))==probe,"soldier behind wall remains selectable through player hit test")
			b.units.erase(probe)
			probe.queue_free()
			await _wait(0.35)
			check(wall.modulate.a==1,"wall opacity restores after soldier leaves")
		await _dispose(b)
	b=await _start("",7)
	check(b.map.sample_scenery._walls.any(func(w): return w.get_script()==load("res://scripts/campaign_city_wall.gd")),"Daming keeps its brick wall renderer")
	await _dispose(b)
	print("[wall-alignment] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() and checks==46 else 1)
