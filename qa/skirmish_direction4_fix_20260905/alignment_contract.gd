extends SceneTree
const Alignment := preload("res://scripts/skirmish_frame_alignment.gd")
var checks := 0
var failures: Array = []
var death_measurements: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/skirmish_direction4_actions_20260905/staging/candidate_manifest.json"))
	var art = root.get_node("Art")
	for p in old.normalized_poses:
		var di := ["se", "sw", "ne", "nw"].find(p.direction)
		var shift := Vector2(p.fit_shift_xy_px[0], p.fit_shift_xy_px[1])
		if p.unit == "guan_gong" and p.direction == "sw" and p.pose == "walk_step" and FileAccess.file_exists("res://assets/direction4/skirmish_archer_sw_revision_20260905.json"):
			shift = Vector2.ZERO # Replacement is built at fixed semantic anchor, no fit shift.
		check(Alignment.FIT_SHIFTS[p.unit][p.pose][di] == shift, "source shift " + p.unit + "/" + p.pose + "/" + p.direction)
	for row in old.strips:
		var frames: Array = art.unit_anim_frames(row.unit, row.state, row.direction)
		check(frames.size() == row.frame_count, "frame count " + row.target_file)
		for i in frames.size():
			var pose: String = row.recipe[i]
			var expected := Vector2.ZERO
			if Alignment.FIT_SHIFTS[row.unit].has(pose): expected = -Alignment.FIT_SHIFTS[row.unit][pose][["se","sw","ne","nw"].find(row.direction)]
			if Alignment.DEATH_DRAW_OFFSETS[row.unit].has(pose):
				expected = Alignment.DEATH_DRAW_OFFSETS[row.unit][pose][["se","sw","ne","nw"].find(row.direction)]
			check(frames[i].has_meta("draw_offset_px") and frames[i].get_meta("draw_offset_px") == expected, "loaded offset " + row.target_file + "/" + str(i))
			if pose in ["death_fall", "death_down"] and i < 3:
				# Independent pixel measurement, not a comparison of two constants.
				var img: Image = frames[i].get_image()
				var total := 0.0
				var weighted_x := 0.0
				var contact_y := -1
				for y in img.get_height():
					for x in img.get_width():
						var a := img.get_pixel(x,y).a
						if a > 15.0/255.0:
							total += a
							weighted_x += x*a
							contact_y = y
				var corrected_x := weighted_x/maxf(total,0.00001)+expected.x
				check(absf(corrected_x-128.0) <= 0.51, "death centre " + row.target_file + "/" + pose)
				check(contact_y+expected.y == 210.0, "death ground " + row.target_file + "/" + pose)
				death_measurements.append({"unit":row.unit,"direction":row.direction,"pose":pose,"corrected_centre_x":corrected_x,"corrected_contact_y":contact_y+expected.y})
	var variants: Array = art.unit_anim_frames("lu_zhishen", "idle", "se", "")
	for f in variants: check(not f.has_meta("draw_offset_px"), "unrelated key isolated")
	var bad: Array = art.unit_anim_frames("guan_gong", "attack", "invalid")
	check(bad.is_empty(), "invalid direction remains rejected")
	var idle_fallback: Array = art.unit_anim_frames("guan_gong", "qa_missing_state", "sw")
	check(idle_fallback.size() == 1 and idle_fallback[0].get_meta("draw_offset_px", Vector2.ZERO) == Vector2(0,-25), "new idle fallback keeps placement")
	art._anim_cache.erase("unit|guan_gong|qa_missing_state|sw")
	var cached_idle_fallback: Array = art.unit_anim_frames("guan_gong", "qa_missing_state", "sw")
	check(cached_idle_fallback.size() == 1 and cached_idle_fallback[0].get_meta("draw_offset_px", Vector2.ZERO) == Vector2(0,-25), "negative legacy cache idle fallback keeps placement")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "death_measurements":death_measurements,"scope": "metadata and actual Art texture alpha measurements; visual direction requires screenshot review"}
	var file := FileAccess.open("res://qa/skirmish_direction4_fix_20260905/alignment_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
