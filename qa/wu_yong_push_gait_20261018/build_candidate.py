"""Verify the authored fixed-scale Wu Yong family; never rewrite existing PNGs."""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
import build_directional_spriteframes as renderer
from build_ruan_xiaoqi_layered_20261018 import canvas_pose
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor

FAMILY = 'wu_yong_layered_20261018'
RUNTIME = ROOT / 'assets/characters' / FAMILY
MANIFEST = ROOT / 'assets/direction4' / ('level1_' + FAMILY + '.json')
STATES = {'push_idle': ['push_idle'],
          'push_walk': ['push_contact_a', 'push_passing_a', 'push_contact_b', 'push_passing_b'],
          'parked_cart': ['cart_only']}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def intended():
    data = json.loads((QA / 'registration_inputs.json').read_text(encoding='utf-8'))
    sources = {}
    poses = {}
    for direction, phases in data['views'].items():
        for phase, row in phases.items():
            raw = data['textures'][row['actor_texture']]
            origin = ROOT / raw['canonical_source']
            assert sha(origin) == raw['sha256']
            key = origin.stem + '_' + raw['sha256'][:8]
            sources.setdefault(key, {'path': (RUNTIME / (key + '.png')).relative_to(ROOT).as_posix(),
                                     'candidate_origin': raw['canonical_source'],
                                     'sha256': raw['sha256'], 'native_size': [1254, 1254],
                                     'imported_size': [1254, 1254]})
            x, y, w, h = row['actor_region']
            with Image.open(origin) as image:
                alpha = np.asarray(image)[y:y+h, x:x+w, 3]
            yy, _ = np.nonzero(alpha >= 64)
            assert len(yy) > 1000
            authored = row['actor_pose']
            pose = canvas_pose(row['actor_region'], authored['pivot_native'],
                               authored['virtual_canvas_reference'], y + int(yy.min()))
            pose.update(source=key, independent_cart=True,
                        semantic_hand_registration=row['hand_annotation'],
                        operations='Untouched PNG; fixed directional body scale; translation-only per-phase palm registration. No cart or physics movement, per-frame body scaling or final gait acceptance.')
            poses['push_' + phase + '_' + direction] = pose
        raw = data['textures'][data['cart_texture']]
        sources['cart_only'] = {'path': raw['canonical_source'], 'sha256': raw['sha256'],
                                'native_size': [1254, 1254], 'imported_size': [1254, 1254]}
        pose = copy.deepcopy(data['cart_poses'][direction])
        pose.update(independent_cart=False)
        poses['cart_only_' + direction] = pose
    return {'schema': 'native_direction4_spriteframes_v1', 'character': FAMILY,
            'body_owner': 'wu_yong', 'sources': sources, 'poses': poses, 'states': STATES,
            'resources': ['assets/anim/' + FAMILY + '_' + state + '_' + direction + '.tres'
                          for direction in renderer.DIRECTIONS for state in STATES],
            'registration_inputs_sha256': sha(QA / 'registration_inputs.json'),
            'canon': 'Chapter16 merchants carry pu-dao; weapon is stowed for pushing as an art interpretation. Keep existing merchant identity and weapon for interruptions. No new injury or story outcome.',
            'scope': 'Unrouted five actor PNGs plus unchanged shared cart, fixed body scale and cart transform; requires actual Unit interruption/movement and package validation.',
            'runtime_adopted': False, 'production_qualified': False,
            'complete_gait_accepted': False, 'native_dimensions_verified': False}


def rendered(manifest):
    result = renderer.render(manifest)
    for name, content in result.items():
        for key, pose in manifest['poses'].items():
            marker = '[sub_resource type="AtlasTexture" id="' + key + '"]\n'
            if marker in content:
                content = content.replace(marker, marker +
                    'metadata/visible_top = ' + str(round(pose['visible_top'], 9)) + '\n' +
                    'metadata/independent_cart = ' + str(pose['independent_cart']).lower() + '\n')
        result[name] = content
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    args = parser.parse_args()
    manifest = intended()
    if args.prepare:
        assert not RUNTIME.exists() and not MANIFEST.exists(), 'Never overwrite a prepared/adopted family'
        RUNTIME.mkdir()
        for key, row in manifest['sources'].items():
            if key == 'cart_only':
                continue
            target = ROOT / row['path']
            shutil.copyfile(ROOT / row['candidate_origin'], target)
            import_descriptor(target)
    outputs = rendered(manifest)
    if args.prepare:
        for name, content in outputs.items():
            target = ROOT / name
            assert not target.exists()
            target.write_bytes(content.encode('utf-8'))
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    assert json.loads(MANIFEST.read_text(encoding='utf-8')) == manifest
    for row in manifest['sources'].values():
        assert sha(ROOT / row['path']) == row['sha256']
    for name, content in outputs.items():
        assert (ROOT / name).read_bytes() == content.encode('utf-8')
    routed = ('res://assets/anim/' + FAMILY + '_%s_%s.tres') in (
        ROOT / 'scripts/campaign_art.gd').read_text(encoding='utf-8')
    print(json.dumps({'actor_pngs': len(manifest['sources'])-1, 'shared_cart_pngs': 1,
                      'resources': len(outputs), 'poses': len(manifest['poses']),
                      'runtime_route_enabled': routed,
                      'authoring_manifest_runtime_adopted': manifest['runtime_adopted'],
                      'complete_gait_accepted': False}))


if __name__ == '__main__':
    main()
