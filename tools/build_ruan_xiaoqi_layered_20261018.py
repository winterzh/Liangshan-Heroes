"""Prepare/verify unrouted actor-layer resources; no PNG pixel edits or game routing.

Body height is calibrated to adopted empty idle at each direction, by construction.
Manual ground x and sole extent are provisional registration, not gait acceptance.
Cart stays one unchanged source at one fixed per-direction transform for all phases.
"""
import argparse
import copy
import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
import build_directional_spriteframes as renderer
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json'
FAMILY = 'ruan_xiaoqi_layered_20261018'
RUNTIME = ROOT / ('assets/characters/' + FAMILY)
MANIFEST = ROOT / ('assets/direction4/level1_' + FAMILY + '.json')
STATES = {'push_idle': ['push_idle'], 'push_walk': ['push_contact_a', 'push_passing_a', 'push_contact_b', 'push_passing_b'], 'parked_cart': ['cart_only']}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def canvas_pose(region, pivot, reference, visible_min_y):
    x, y, w, h = region
    dx, dy = pivot[0]-x, pivot[1]-y
    canvas = math.ceil(max(reference, 2*dx, 2*(w-dx), dy/.82, (h-dy)/.18))
    scale = canvas / reference
    assert .25 <= scale <= 4, (region, pivot, reference, scale)
    margin = [canvas*.5-dx, canvas*.82-dy, canvas-w, canvas-h]
    return {'region': region, 'margin': margin, 'pivot_native': pivot,
            'virtual_canvas_reference': reference, 'draw_scale': scale,
            'draw_offset_px': [0, 0], 'visible_top': (margin[1]+visible_min_y-y)/canvas}


def intended():
    selection = load(RAW)
    old = load(ROOT / 'assets/direction4/level1_ruan_xiaoqi_pushcart_20261018.json')
    empty = load(ROOT / 'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json')
    sources = {'cart_only': copy.deepcopy(old['sources']['cart_only'])}
    poses = {}
    offsets = selection['cart_offsets_per_body_size']
    wheel_offsets = {}
    for d in renderer.DIRECTIONS:
        ep = empty['poses']['idle_'+d]
        erow = empty['sources'][ep['source']]
        x, y, w, h = ep['region']
        with Image.open(ROOT/erow['path']) as picture:
            alpha = np.asarray(picture)[y:y+h, x:x+w, 3]
        yy, _ = np.nonzero(alpha >= 64)
        ratio = (ep['pivot_native'][1] - y - int(yy.min())) / ep['virtual_canvas_reference']
        for state, bindings in selection['view_bindings'].items():
            binding = bindings[d]
            origin = ROOT / binding['path']
            assert sha(origin) == binding['sha256'], binding['path']
            key = origin.stem + '_' + binding['sha256'][:8]
            with Image.open(origin) as picture:
                size = list(picture.size)
                x, y, w, h = binding['region']
                alpha = np.asarray(picture)[y:y+h, x:x+w, 3]
            yy, xx = np.nonzero(alpha >= 64)
            assert len(xx) > 1000
            assert int(yy.min()) > 0 and int(yy.max()) < h-1
            sources.setdefault(key, {'path': (RUNTIME/(key+'.png')).relative_to(ROOT).as_posix(),
                                    'candidate_origin': binding['path'], 'sha256': binding['sha256'],
                                    'native_size': size, 'imported_size': size, 'selected_directions': []})
            sources[key]['selected_directions'].append(d)
            root_y = y + int(yy.max()) + 1
            reference = (root_y-y-int(yy.min())) / ratio
            pose = canvas_pose(binding['region'], [binding['root_x'], root_y], reference, y+int(yy.min()))
            registration = selection.get('hand_registration', {}).get(state+'_'+d)
            if registration:
                pose['draw_offset_px'] = [float(v)*reference for v in registration['translation_per_body_size']]
                pose['hand_registration'] = registration
            pose.update(source=key, independent_cart=True, body_height_target=ratio,
                        operations='Untouched independent body PNG; native region/virtual margins/uniform scale. Crown-to-lowest-sole height matched to empty idle by construction; optional translation-only manual grip registration moves actor layer, never cart or physics. Foot/root/head variation remains visual QA; no source pixel edits or final gait/grip acceptance.')
            poses[state+'_'+d] = pose
        cp = old['poses']['cart_only_'+d]
        reference = cp['virtual_canvas_reference']
        pivot = [cp['pivot_native'][i] - offsets[d][i]*reference for i in range(2)]
        cart_top = old['canonical_cart_geometry'][d]['cart_top']
        pose = canvas_pose(cp['region'], pivot, reference, cart_top)
        pose.update(source='cart_only', independent_cart=False, cart_depth_pixels=cp['cart_depth_pixels'],
                    operations='Same unchanged cart PNG/region/uniform scale at a fixed per-direction offset, shared by idle/walk/interruption. No per-frame cart motion or bitmap edits.')
        poses['cart_only_'+d] = pose
        wheel_offsets[d] = [old['wheel_offsets_per_body_size'][d][i]+offsets[d][i] for i in range(2)]
    return {'schema': 'native_direction4_spriteframes_v1', 'character': FAMILY, 'body_owner': 'ruan_xiaoqi',
            'sources': sources, 'poses': poses, 'states': STATES,
            'resources': [f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in renderer.DIRECTIONS],
            'wheel_offsets_per_body_size': wheel_offsets, 'cart_offsets_per_body_size': offsets,
            'canonical_cart_geometry': old['canonical_cart_geometry'],
            'production_qualified': False, 'native_dimensions_verified': False,
            'runtime_adopted': False, 'complete_gait_accepted': False,
            'registration_revision': selection.get('registration_revision', 1),
            'canon': selection['canon'], 'scope': selection['scope']}


def render(manifest):
    outputs = renderer.render(manifest)
    for name, content in outputs.items():
        for key, pose in manifest['poses'].items():
            marker = '[sub_resource type="AtlasTexture" id="'+key+'"]\n'
            if marker in content:
                content = content.replace(marker, marker+f'metadata/visible_top = {pose["visible_top"]:.9f}\nmetadata/independent_cart = {str(pose["independent_cart"]).lower()}\n')
        outputs[name] = content
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--rebuild-unrouted', action='store_true')
    args = parser.parse_args()
    manifest = intended()
    if args.rebuild_unrouted:
        assert MANIFEST.is_file() and not load(MANIFEST)['runtime_adopted']
        assert 'res://assets/anim/'+FAMILY+'_' not in (ROOT/'scripts/campaign_art.gd').read_text(encoding='utf-8'), 'Never rebuild enabled family'
        assert 'func _campaign_tribute_layered_frame' not in (ROOT/'scripts/unit.gd').read_text(encoding='utf-8'), 'Never rebuild after integration'
    if args.prepare or args.rebuild_unrouted:
        if args.prepare:
            assert not RUNTIME.exists() and not MANIFEST.exists()
            RUNTIME.mkdir()
        for key, row in manifest['sources'].items():
            if key == 'cart_only':
                continue
            dest = ROOT / row['path']
            if dest.exists():
                assert args.rebuild_unrouted and sha(dest) == row['sha256']
            else:
                shutil.copyfile(ROOT/row['candidate_origin'], dest)
                import_descriptor(dest)
        for name, content in render(manifest).items():
            assert args.rebuild_unrouted or not (ROOT/name).exists()
            (ROOT/name).write_bytes(content.encode())
        MANIFEST.write_bytes((json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode())
    assert load(MANIFEST) == manifest
    for row in manifest['sources'].values():
        assert sha(ROOT/row['path']) == sha(ROOT/row['candidate_origin']) == row['sha256']
    for name, content in render(manifest).items():
        assert (ROOT/name).read_bytes() == content.encode()
    print(json.dumps({'body_pngs': 12, 'shared_cart_pngs': 1, 'poses': 24, 'resources': 12,
                      'runtime_adopted': False, 'gait_accepted': False}))


if __name__ == '__main__':
    main()
