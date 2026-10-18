"""Prepare original/actor/actor+fixed-cart comparison, without running Godot.

PIL is used only to measure source alpha bounds; PNGs are copied byte-for-byte.
"""
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image

R = Path(__file__).resolve().parents[2]
Q = Path(__file__).resolve().parent

def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()

def save(path, value):
    with path.open('x', encoding='utf-8') as handle:
        handle.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def bounds(path, region):
    with Image.open(path) as image:
        x, y, w, h = region
        # Analysis mask only; no source/image output is ever edited or saved.
        alpha = image.getchannel('A').crop((x, y, x+w, y+h))
        box = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
        assert box is not None
        return [box[0]+x, box[1]+y, box[2]+x, box[3]+y]

def transformed(box, pose):
    scale = 160.0 / float(pose['virtual_canvas_reference'])
    px, py = pose['pivot_native']
    return [(box[0]-px)*scale, (box[1]-py)*scale,
            (box[2]-px)*scale, (box[3]-py)*scale]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.absolute()
    assert output.is_absolute() and not output.exists()
    assert not output.is_relative_to(R), 'Comparison must stay outside the checkout'
    for item in [output] + list(output.parents):
        if item.exists():
            assert not item.is_symlink() and not getattr(item.lstat(), 'st_file_attributes', 0) & 0x400
    output.mkdir(parents=True)
    image_dir = output / 'images'; image_dir.mkdir()
    selection = json.loads((Q/'candidate_selection.json').read_text(encoding='utf-8'))
    manifest_path = R / selection['original_manifest']
    assert sha(manifest_path) == selection['original_manifest_sha256']
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    lineage = json.loads((Q/'prompt_set.json').read_text(encoding='utf-8'))
    for row in lineage['jobs']:
        assert sha(Q/row['file']) == row['sha256']
        assert sha(Q/row['prompt_file']) == row['prompt_sha256']
    data = {'scope':'resource comparison only, not game Unit',
            'phases':['idle','contact_a','passing_a','contact_b','passing_b'],
            'textures':{}, 'views':{}, 'cart_poses':{}, 'placement':{},
            'production_adopted':False, 'pixel_writes':False,
            'source_manifest_sha256':sha(manifest_path)}
    inputs = {}
    def register(key, source, expected=None):
        if key in data['textures']: return
        digest = sha(source)
        if expected is not None: assert digest == expected
        destination = image_dir / (key.replace(':','_') + '.png')
        shutil.copyfile(source, destination); assert sha(destination) == digest
        with Image.open(source) as image:
            assert image.size == (1254,1254) and image.mode == 'RGBA'
        data['textures'][key] = {'file':destination.relative_to(output).as_posix(), 'sha256':digest,
                                 'canonical_source':source.relative_to(R).as_posix()}
        inputs[destination.relative_to(output).as_posix()] = digest
    cart = manifest['sources']['cart_only']
    data['cart_texture'] = 'original:cart_only'
    data['cart_source'] = cart['path']
    register(data['cart_texture'], R/cart['path'], cart['sha256'])
    for di, direction in enumerate(['se','sw','ne','nw']):
        data['views'][direction] = {}
        cart_pose = manifest['poses']['cart_only_'+direction]
        data['cart_poses'][direction] = cart_pose
        extents = [transformed(bounds(R/cart['path'],cart_pose['region']),cart_pose)]
        actor_region = [(di % 2)*627, (di // 2)*627, 627, 627]
        for phase in data['phases']:
            pose = manifest['poses']['push_'+phase+'_'+direction]
            original = manifest['sources'][pose['source']]
            old_key = 'original:'+pose['source']
            register(old_key, R/original['path'], original['sha256'])
            actor = Q/'native_originals'/selection['states'][phase][direction]
            new_key = 'actor:'+actor.stem
            register(new_key, actor)
            old_box = bounds(R/original['path'], pose['region'])
            new_box = bounds(actor, actor_region)
            extents += [transformed(old_box,pose), transformed(new_box,pose)]
            data['views'][direction][phase] = {'original_texture':old_key,'actor_texture':new_key,
                'original_pose':pose,'actor_region':actor_region,'original_alpha16_bounds':old_box,
                'actor_alpha16_bounds':new_box}
        union = [min(x[0] for x in extents),min(x[1] for x in extents),
                 max(x[2] for x in extents),max(x[3] for x in extents)]
        common = min(1.0, 354.0/(union[2]-union[0]), 270.0/(union[3]-union[1]))
        data['placement'][direction] = {'common_scale':common,
            'origin':[15.0-union[0]*common,35.0-union[1]*common],
            'all_phase_union':union,'body_size':160,
            'same_scale_and_origin_all_phases_and_rows':True,'per_frame_auto_fit':False}
    save(output/'inputs.json',data)
    shutil.copyfile(Q/'preview.gd.txt',output/'preview.gd')
    (output/'project.godot').write_text('[application]\nconfig/name="ChaoLayerResourceCompare"\n[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=960\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf-8')
    frozen = [{'path':p.relative_to(output).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
              for p in sorted(output.rglob('*')) if p.is_file()]
    receipt = {'prepared':True,'native_executed':False,'project':str(output),'frozen':frozen,
               'preparer_sha256':sha(Path(__file__)),'new_actor_selected_views':20,
               'png_count':len(data['textures']),'pixel_writes':False,'actual_game_unit_tested':False}
    save(output.parent/'prepared_binding.json',receipt)
    print(json.dumps({'prepared':True,'files':len(frozen),'pngs':len(data['textures']),
                      'native_executed':False,'project':str(output)},ensure_ascii=False))

if __name__ == '__main__': main()
