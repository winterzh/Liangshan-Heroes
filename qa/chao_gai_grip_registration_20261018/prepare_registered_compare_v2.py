"""Fixed-per-direction actor registration; copy PNGs without editing pixels."""
from pathlib import Path
import copy, hashlib, json, shutil
import numpy as np
from PIL import Image

R = Path(__file__).resolve().parents[2]
Q = Path(__file__).resolve().parent
OLD = Path('D:/CodexEvidence/shuihu/chao_gai_layered_recheck_20261018/prepared')
E = Path('D:/CodexEvidence/shuihu/chao_gai_registered_body_scale_v2_20261018')

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def save(p, value):
    with p.open('x', encoding='utf-8') as f:
        f.write(json.dumps(value, ensure_ascii=False, indent=2)+'\n')

def transform(box, pose):
    p = pose['pivot_native']; k = 160 / pose['virtual_canvas_reference']
    return [(box[i]-p[i%2])*k for i in range(4)]

def main():
    assert not E.exists(), 'Never overwrite an immutable prepared comparison'
    old_binding = json.loads((OLD.parent/'prepared_binding.json').read_text())
    assert all(sha(OLD/x['path']) == x['sha256'] for x in old_binding['frozen'])
    data = json.loads((OLD/'inputs.json').read_text())
    empty_path=R/'assets/direction4/level1_chao_gai_merchant_20261017.json'
    empty=json.loads(empty_path.read_text())
    empty_source=R/empty['sources']['idle']['path']
    assert sha(empty_source)==empty['sources']['idle']['sha256']
    empty_pixels=np.asarray(Image.open(empty_source))
    data['empty_reference']={'manifest':str(empty_path.relative_to(R)), 'manifest_sha256':sha(empty_path), 'source':str(empty_source.relative_to(R)), 'source_sha256':sha(empty_source), 'poses':{}, 'height_ratios':{}}
    data['textures']['reference:empty_idle']={'file':'images/reference_empty_idle.png','sha256':sha(empty_source),'canonical_source':str(empty_source.relative_to(R))}
    source_hashes = {v['canonical_source']: v['sha256'] for v in data['textures'].values()}
    assert all(sha(R/n) == h for n,h in source_hashes.items())
    # Approximate visible grip centres, recorded as manual annotations, not exact anatomy.
    grips = {'se': [[150,321],[315,282]], 'sw': [[925,285],[1097,325]],
             'ne': [[355,940]], 'nw': [[910,943]]}
    targets = {'se': [[52,194],[171,141]], 'sw': [[1086,155],[1200,198]],
               'ne': [[194,1069]], 'nw': [[1047,1088]]}
    registrations = {}
    for d, views in data['views'].items():
        idle = copy.deepcopy(views['idle']['original_pose']); cart = data['cart_poses'][d]
        ep=empty['poses']['idle_'+d]; x,y,w,h=ep['region']
        yy,xx=np.nonzero(empty_pixels[y:y+h,x:x+w,3]>=64)
        empty_box=[int(xx.min()+x),int(yy.min()+y),int(xx.max()+x+1),int(yy.max()+y+1)]
        ratio=(ep['pivot_native'][1]-y-int(yy.min()))/ep['virtual_canvas_reference']
        data['empty_reference']['poses'][d]=ep;data['empty_reference']['height_ratios'][d]=ratio
        raw=R/data['textures'][views['idle']['actor_texture']]['canonical_source']
        pixels=np.asarray(Image.open(raw));x,y,w,h=views['idle']['actor_region'];ay,ax=np.nonzero(pixels[y:y+h,x:x+w,3]>=64)
        idle['virtual_canvas_reference']=(int(ay.max())-int(ay.min())+1)/ratio
        ref = idle['virtual_canvas_reference']; pivot = idle['pivot_native']
        desired = [[pivot[j]+(pt[j]-cart['pivot_native'][j])*ref/cart['virtual_canvas_reference']
                    for j in range(2)] for pt in targets[d]]
        shift = [sum(w[j]-a[j] for w,a in zip(desired,grips[d]))/len(desired) for j in range(2)]
        pose = copy.deepcopy(idle)
        pose['pivot_native'] = [pivot[j]-shift[j] for j in range(2)]
        pose['draw_offset_px'] = [0,0]
        registrations[d] = {'manual_idle_source_grips':grips[d], 'manual_cart_targets':targets[d],
            'desired_grips_in_idle_source_coordinates':desired, 'constant_actor_shift_native':shift,
            'constant_reference_all_phases':ref, 'constant_pivot_all_phases':pose['pivot_native'],
            'source_residuals_after_translation':[[a[j]+shift[j]-w[j] for j in range(2)]
                                                for a,w in zip(grips[d],desired)],
            'rear_far_hand_occluded': d in ['ne','nw'], 'contact_accepted':False,
            'note':'Approximate idle-only landmarks. Translation-only midpoint/front or visible-near-grip/rear. Zero residual for one point is arithmetic, not proof of physical contact. Same transform for all five phases; no frame fit or per-phase hand anchoring.'}
        extents = [transform(empty_box,ep)]
        for v in views.values():
            v['actor_pose'] = copy.deepcopy(pose)
            extents += [transform(v['original_alpha16_bounds'],v['original_pose']),
                        transform(v['actor_alpha16_bounds'],v['original_pose']),
                        transform(v['actor_alpha16_bounds'],v['actor_pose'])]
        # Retain the old union including the unchanged cart, as well as new actor bounds.
        extents.append(data['placement'][d]['all_phase_union'])
        union = [min(b[0] for b in extents),min(b[1] for b in extents),
                 max(b[2] for b in extents),max(b[3] for b in extents)]
        common = min(1.0,354/(union[2]-union[0]),270/(union[3]-union[1]))
        data['placement'][d] = {'common_scale':common,'origin':[15-union[0]*common,35-union[1]*common],
            'all_phase_union':union,'body_size':160,'same_scale_and_origin_all_phases_and_rows':True,
            'per_frame_auto_fit':False,'one_actor_transform_for_all_five_phases':True}
    data['registration'] = registrations
    data['scope'] = 'Five-row resource comparison: empty-idle body reference, original composite, previous independent placement, fixed-registration actor, registered actor + unchanged fixed cart. One actor reference from independent idle body height, shared across all five phases. Not actual Unit or gait acceptance.'
    E.mkdir(parents=True); P = E/'prepared'; P.mkdir()
    for row in old_binding['frozen']:
        src=OLD/row['path']; dst=P/row['path']; dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,dst); assert sha(dst)==row['sha256']
    shutil.copyfile(empty_source,P/'images/reference_empty_idle.png'); assert sha(P/'images/reference_empty_idle.png')==sha(empty_source)
    (P/'inputs.json').unlink(); save(P/'inputs.json',data)
    source = (R/'qa/chao_gai_layered_sources_20261018/preview.gd.txt').read_text()
    source = source.replace('1920, 960','1920, 1600').replace('range(3)','range(5)')
    source = source.replace('["ORIGINAL COMPOSITE", "ISOLATED ACTOR", "ACTOR + FIXED CART"]',
        '["EMPTY IDLE HEIGHT REFERENCE", "ORIGINAL COMPOSITE", "PREVIOUS ACTOR + CART", "REGISTERED ACTOR", "REGISTERED ACTOR + CART"]')
    source = source.replace('if row == 0:\n', 'if row == 0:\n\t\t\t\t\tpaint_pose("reference:empty_idle", data.empty_reference.poses[direction], data.empty_reference.poses[direction].region)\n\t\t\t\telif row == 1:\n')
    source = source.replace('if row == 2 and direction', 'if row in [2, 4] and direction')
    source = source.replace('paint_pose(item.actor_texture, item.original_pose, item.actor_region)',
        'paint_pose(item.actor_texture, item.original_pose if row == 2 else item.actor_pose, item.actor_region)')
    source = source.replace('"placement": data.placement}', '"placement": data.placement, "registration": data.registration, "empty_reference": data.empty_reference}')
    (P/'preview.gd').write_text(source,encoding='utf-8')
    cfg=(P/'project.godot').read_text().replace('viewport_height=960','viewport_height=1600').replace('ChaoLayerResourceCompare','ChaoRegisteredCompare')
    (P/'project.godot').write_text(cfg,encoding='utf-8')
    frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
            for p in sorted(P.rglob('*')) if p.is_file()]
    save(E/'prepared_binding.json',{'prepared':True,'native_executed':False,'project':str(P),
        'frozen':frozen,'preparer_sha256':sha(Path(__file__)),'original_binding_sha256':sha(OLD.parent/'prepared_binding.json'),
        'png_count':len(data['textures']),'pixel_writes':False,'registration':registrations,
        'source_hashes':source_hashes,'native_old_corner_failures_not_relaxed':True,'production_adopted':False})
    shutil.copyfile(P/'inputs.json',Q/'prepared_inputs.json')
    shutil.copyfile(P/'preview.gd',Q/'prepared_preview.gd.txt')
    shutil.copyfile(E/'prepared_binding.json',Q/'prepared_binding.json')
    print(json.dumps({'prepared':len(frozen),'pngs':len(data['textures']),'native_executed':False}))

if __name__ == '__main__':
    main()
