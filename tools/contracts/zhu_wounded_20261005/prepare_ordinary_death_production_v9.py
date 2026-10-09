"""Prepare a sibling production death verifier; never rewrite executed pilots."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'qa/zhu_wounded_20261005/harness'

def main():
    source=(HERE/'ordinary_skills_death_v8a.gd').read_text(encoding='utf-8')
    start=source.index('func _skill(');end=source.index('func _death(')
    text=source[:start]+source[end:]
    text=text.replace('var case_mode := ""','const Shadow := preload("res://scripts/world_shadow.gd")')
    needle='\tcheck(u not in b.units and u not in b.selection,"dead actor leaves live registry/selection")'
    assert text.count(needle)==1
    text=text.replace(needle,needle+'''
	var shadow=b.world.get_node_or_null(String(Shadow.BATCH_NODE_NAME))
	check(Shadow.enabled() and is_instance_valid(shadow) and u in shadow.retained_dying_units,"dying hero retained by normal render shadow batch")
	art_runtime.append({"case":"dying_shadow","actor":key,"direction":d,"summary":Shadow.batch_summary(b)})''')
    needle='\tawait process_frame\n\tcheck(not is_instance_valid(u),'
    assert text.count(needle)==1
    text=text.replace(needle,'''	await process_frame
	await process_frame
	check(is_instance_valid(shadow) and shadow.retained_dying_units.all(func(e):return is_instance_valid(e) and e.get_instance_id()!=actor_id),"released actor pruned from normal shadow retention")
	art_runtime.append({"case":"released_shadow","actor":key,"direction":d,"summary":Shadow.batch_summary(b)})
	check(not is_instance_valid(u),''')
    text=text[:text.index('func _run()')]+'''
func _queries() -> void:
	var art=root.get_node("Art")
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://ordinary_predeath_query_baselines.json"))
	for row in baseline:
		var frames: Array=art.unit_anim_frames(row.key,row.state,row.direction)
		var poses: Array=frames.map(func(frame):return _texture_pose(frame))
		if row.key=="wu_song" and row.state=="death":
			check(frames.size()==4 and art.unit_anim_uses_directional_source(row.key,row.state,row.direction),"production Wu native directional death "+row.direction)
			check(frames.all(func(frame):return frame is AtlasTexture and bool(frame.get_meta("authored_direction4",false)) and frame.has_meta("draw_offset_px") and frame.has_meta("draw_scale")),"production death native metadata "+row.direction)
		else:
			check(poses==row.candidate,"other qualified ordinary route unchanged "+row.key+" "+row.state+" "+row.direction)
		art_rows.append({"key":row.key,"state":row.state,"direction":row.direction,"before":row.candidate,"current":poses,"scope":"resource query, not observed action"})
	for pair in [["lin_chong","lin_chong_prisoner"],["lin_chong","lin_chong_escort"],["wu_song","wu_song_mengzhou"]]:
		for direction in ART_DIRS:
			for state in ["idle","walk","attack","hurt","death","down"]:
				var frames: Array=art.unit_anim_frames(pair[0],state,direction,pair[1])
				check(frames.all(func(frame):return not _texture_source(frame).contains("_traits_20261006/")),"story body excludes ordinary death/gait/combat "+pair[1]+" "+state+" "+direction)
				if state in ["idle","walk"]:check(not frames.is_empty(),"story body retained "+pair[1]+" "+state+" "+direction)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1";art_character="ordinary_death_production_v9"
	if not _art_profile_guard():quit(1);return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal engine clock")
	check(Shadow.enabled(),"normal production shadow renderer enabled")
	_queries()
	for key in ["lin_chong","wu_song"]:
		for direction in range(4):await _death(key,2 if key=="lin_chong" else 7,direction)
	_art_finish()
'''
    text=text.replace('## Original actors/orders; legal level-six restore fixture for skill pictures.\n## Death uses untouched original level-one stats and actual enemy attack damage.',
                      '## Current production scripts copied unchanged; original level-one lethal damage.\n## Adds actual shadow retention/pruning and unaffected ordinary/story route guards.')
    output=HERE/'ordinary_death_production_v9.gd'
    assert not output.exists();output.write_bytes(text.encode('utf-8'))
    print('Prepared sibling ordinary_death_production_v9.gd; not executed or qualified.')

if __name__=='__main__':main()
