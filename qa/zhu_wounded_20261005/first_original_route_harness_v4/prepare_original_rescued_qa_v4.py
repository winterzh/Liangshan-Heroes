"""Create a distinct original-Battle harness; retain earlier baseline evidence."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'tools/rescued_seven_art_qa.gd'
assert not p.exists()
s=(ROOT/'tools/current_campaign_art_qa.gd').read_text(encoding='utf-8')
s=s.replace('art_character="current_campaign_art"','art_character="rescued_seven_current"')
s=s.replace('art.unit_texture(u.key,u.art_variant,u.animation_direction)','art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction)')
s=s.replace('art.unit_anim_frames(u.key,state,d,u.art_variant)','art.unit_anim_frames(u.key,state,d,u.visual_art_variant())')
s=s.replace('art.unit_anim_uses_directional_source(u.key,state,d,u.art_variant)','art.unit_anim_uses_directional_source(u.key,state,d,u.visual_art_variant())')
s=s.replace('var before: Dictionary = {"hp":shi.hp,"portrait":_texture_pose(shi.ui_portrait_texture())}',
'''var before: Dictionary = {"hp":shi.hp,"portrait":_texture_pose(shi.ui_portrait_texture())}
	var prior_portraits := {}
	for u in l.prisoners: prior_portraits[u.key] = _texture_pose(u.ui_portrait_texture())''')
s=s.replace('for d in ART_DIRS:\n\t\tshi.animation_direction=d;shi.face_left=d in ["sw","nw"];shi._move_blend=1.0;shi._anim_t=0.0',
'''await _rescued_routes(b,prior_portraits)
	for d in ART_DIRS:
		shi.animation_direction=d;shi.face_left=d in ["sw","nw"];shi._move_blend=1.0;shi._anim_t=0.0''')
s=s.replace('shi._anim_frame_for_state(art.unit_texture(shi.key,"",d))','shi._anim_frame_for_state(art.unit_texture(shi.key,shi.visual_art_variant(),d))')
s=s.replace('Shi Xiu rescued original HP portrait and generic body ', 'Shi Xiu rescued original HP portrait and scoped unarmed body ')
s=s.replace('"variant":u.art_variant,"noncombat":u.is_noncombat','"variant":u.art_variant,"visual_variant":u.visual_art_variant(),"noncombat":u.is_noncombat')
s+='''
func _rescued_routes(b, prior_portraits: Dictionary) -> void:
	var art = root.get_node("Art")
	var l = b.level
	var registry = load("res://scripts/campaign_art.gd")
	for u in l.prisoners:
		var v: String = "zhu_wounded_" + u.key
		check(u.visual_art_variant()==v and u.art_variant.is_empty(),"derived original rescued role with legacy empty save field "+u.key)
		check(u.hp==110 and u.max_hp==110 and u.base_speed==82 and u.atk==0 and not u.is_hero and u.is_noncombat and u.ability_slots.is_empty(),"rescue preserves original noncombat stats "+u.key)
		for d in ART_DIRS:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			var idle: Array = art.unit_anim_frames(u.key,"idle",d,v)
			var walk: Array = art.unit_anim_frames(u.key,"walk",d,v)
			check(idle.size()==1 and walk.size()==4,"original resolver has one idle and four authored walk phases "+u.key+" "+d)
			if idle.is_empty() or walk.size()!=4: continue
			var expected: String = registry.native_body_path(v,"idle",d)
			check(expected.contains(registry.NATIVE_WOUNDED_FAMILIES[u.key]) and art.campaign_variant_has_direction(v,d) and art.campaign_variant_has_animation(v,"walk",d),"matching family and exact authored direction "+u.key+" "+d)
			u._move_blend=0.0
			var f = u._anim_frame_for_state(art.unit_texture(u.key,v,d))
			check(_texture_pose(f)==_texture_pose(idle[0]) and u._frame_directional,"original idle draw has native frame and no mirror "+u.key+" "+d)
			for i in range(4):
				u._move_blend=1.0;u._anim_t=(i+0.1)*TAU/4.0
				f=u._anim_frame_for_state(art.unit_texture(u.key,v,d))
				check(_texture_pose(f)==_texture_pose(walk[i]) and u._frame_directional,"original walk draw authored phase "+u.key+" "+d+" "+str(i))
			check(_texture_pose(art.unit_anim_frames(u.key,"hurt",d,v)[0])==_texture_pose(idle[0]) and not art.campaign_variant_has_animation(v,"hurt",d),"hurt uses same standing body without separate animation claim "+u.key+" "+d)
			for state in ["attack","gather","assisted","death","down"]:
				check(art.unit_anim_frames(u.key,state,d,v).is_empty(),"unarmed missing state rejects armed fallback "+u.key+" "+d+" "+state)
			var rest = u._rest_frame(art.unit_texture(u.key,v,d))
			check(_texture_pose(rest)==_texture_pose(walk[1]) and u._frame_directional,"procedural terminal rest retains unarmed authored direction "+u.key+" "+d)
			var same: bool = _texture_pose(u.ui_portrait_texture())==prior_portraits[u.key]
			check(same,"rescued selection UI retains standard owner portrait "+u.key+" "+d)
			check(art.unit_anim_frames("lin_chong","walk",d,v).is_empty() and art.unit_texture("lin_chong",v,d)==null and art.ui_portrait_texture("lin_chong",v)==null,"cross-owner resource and UI rejected "+u.key+" "+d)
			art_runtime.append({"case":"rescued_native_route","key":u.key,"direction":d,"variant":v,"idle":_frame_record(idle[0]),"walk":walk.map(func(x):return _frame_record(x)),"same_portrait":same,"directional":u._frame_directional,"sampled_phases_fixture":true})
		check(art.unit_anim_frames(u.key,"walk","east",v).is_empty() and art.unit_texture(u.key,v,"east")==null,"invalid direction does not borrow another view "+u.key)
		# Role exclusions are reversible query fixtures on the original actor.
		u.is_noncombat=false;check(u.visual_art_variant().is_empty(),"combat role excluded "+u.key);u.is_noncombat=true
		var index: int = l.prisoners.find(u)
		l.prisoners.remove_at(index);check(u.visual_art_variant().is_empty(),"same-key nonmember excluded "+u.key);l.prisoners.insert(index,u)
		u.art_variant="bound_"+u.key;check(u.visual_art_variant()==u.art_variant,"explicit story variant retains priority "+u.key);u.art_variant=""
		u._move_blend=0.0;u._anim_t=0.0
	for d in ART_DIRS:
		for u in l.prisoners: u.animation_direction=d;u.face_left=d in ["sw","nw"];u.queue_redraw()
		await _art_screenshot(b,"seven_rescued_native_"+d,l.prisoners[0])
	var positions: Array = l.prisoners.map(func(u):return u.position)
	l.activate_mission_button(b,"zhu_select_shi_qian")
	check(b.selection.size()==1 and b.selection[0]==l.prisoners[0],"actual mission button selects original Shi Qian")
	l.activate_mission_button(b,"zhu_select_rescued")
	check(b.selection.size()==7 and l.prisoners.all(func(u):return u in b.selection),"actual mission button selects seven original evacuees")
	check(positions==l.prisoners.map(func(u):return u.position),"selection buttons do not teleport evacuees")
'''
p.write_bytes(s.encode('utf-8'))
print('Created distinct original-Battle rescued harness')
