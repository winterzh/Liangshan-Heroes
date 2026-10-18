from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent
p=R/'tools/ruan_xiaoqi_layered_20261018.gd';b=p.read_bytes();nl=b'\r\n' if b'\r\n' in b else b'\n'
def replace(old,new,count=1):
    global b
    old=old.replace('\n',nl.decode()).encode();new=new.replace('\n',nl.decode()).encode()
    assert b.count(old)==count,(old[:100],b.count(old));b=b.replace(old,new)
replace('\tawait take(b,u,1);await ground_range_matrix(b,u);','\tawait take(b,u,1);await wheel_render_matrix(b,u);await ground_range_matrix(b,u);')
replace('\t\tvar own:=_range_pixels(off,on,b,u,[body,cart]);','\t\tvar own:=_range_pixels(off,on,b,u,[body]+wheel_cart_mask_frames(u));')
replace('var hit:=_range_pixels(off,wrong,b,u,[body,cart]);','var hit:=_range_pixels(off,wrong,b,u,[body]+wheel_cart_mask_frames(u));')
replace('\t\tu.set_physics_process(true);u.order_move(origin+row.delta*82.0)','\t\tvar wheel_phase_start: float=u._anim_t\n\t\tu.set_physics_process(true);u.order_move(origin+row.delta*82.0)')
replace('\t\tstage_camera(b,u);await snap("actual_push_walk_"+String(row.d));','\t\tcheck(u._anim_t>wheel_phase_start,"actual displacement advances wheel/gait phase "+String(row.d))\n\t\tobservations.append({"wheel_actual_movement":row.d,"phase_delta":u._anim_t-wheel_phase_start,"distance":u.position.distance_to(origin)})\n\t\tstage_camera(b,u);await snap("actual_push_walk_"+String(row.d));')
replace('\t\t# Actual Unit damage/attack mechanics; a separate cart remains grounded.','''		# Keep residual walk blend while stopped: elapsed time and camera motion
		# must not advance the wheel even before the body blend decays to zero.
		u.order_stop();var stopped_phase: float=u._anim_t;var stopped_position: Vector2=u.position
		var before_zoom: Vector2=b.camera.zoom;b.camera.zoom=before_zoom*1.1;b.camera.position+=Vector2(9,-7);b.camera.force_update_scroll()
		u.set_physics_process(true)
		for tick in range(36):await get_tree().physics_frame
		u.set_physics_process(false);b.camera.zoom=before_zoom;stage_camera(b,u)
		check(u.position.is_equal_approx(stopped_position) and is_equal_approx(u._anim_t,stopped_phase),"actual stop and camera motion do not spin wheel "+String(row.d))
		await snap("wheel_actual_stopped_"+String(row.d))
		# Actual Unit damage/attack mechanics; a separate cart remains grounded.''')
replace('\t\tvar before_hp: float=u.hp;u.take_damage(7,b.level.yang,false,true)','\t\tvar before_hurt_phase: float=u._anim_t\n\t\tvar before_hp: float=u.hp;u.take_damage(7,b.level.yang,false,true)')
replace('\t\tu.set_physics_process(false);check(not u._campaign_tribute_push_state().is_empty(),','\t\tu.set_physics_process(false);check(is_equal_approx(u._anim_t,before_hurt_phase),"actual parked recoil keeps wheel phase "+String(row.d))\n\t\tcheck(not u._campaign_tribute_push_state().is_empty(),')
replace('\tcheck(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"unloaded Ruan Xiaoqi keeps adopted merchant body")','\tcheck(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"unloaded Ruan Xiaoqi keeps adopted merchant body")\n\tcheck(not load("res://scripts/tribute_cart_wheel_visual.gd").enabled(u),"unloaded actor does not draw rolling cart")')
replace('\tcheck(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"delivery restores original empty-handed body")','\tcheck(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"delivery restores original empty-handed body")\n\tcheck(not load("res://scripts/tribute_cart_wheel_visual.gd").enabled(u),"actual delivery disables rolling cart renderer")')
b+=nl+(E/'wheel_game_qa_additions.gd.txt').read_text().replace('\n',nl.decode()).encode();p.write_bytes(b)
print('Extended existing QA, retained all old check labels; source masks now use actual new body/rim.')
