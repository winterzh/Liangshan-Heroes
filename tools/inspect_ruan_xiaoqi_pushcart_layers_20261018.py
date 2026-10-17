"""Read-only source/geometry audit. This does not qualify gait or game runtime."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/ruan_xiaoqi_pushcart_layer_sources_20261018'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify():
    manifest = json.loads((SOURCE / 'prompt_set.json').read_text(encoding='utf-8'))
    assert (SOURCE / '.gdignore').is_file()
    assert manifest['source_count'] == len(manifest['outputs']) == 12
    views = 0
    for row in manifest['outputs']:
        path = ROOT / row['path']
        assert sha(path) == row['sha256'] and path.stat().st_size == row['bytes'], row['key']
        for ref in row['reference_hashes']:
            assert sha(ROOT / ref['workspace_binding']) == ref['sha256'], ref['workspace_binding']
        with Image.open(path) as picture:
            assert picture.mode == 'RGBA' and list(picture.size) == row['geometry']['size']
            alpha = np.asarray(picture)[:, :, 3]
        height, width = alpha.shape
        corners = [int(alpha[y, x]) for x, y in [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]]
        assert corners == row['geometry']['whole_corner_alpha']
        assert int(np.count_nonzero((alpha > 0) & (alpha < 16))) == row['geometry']['low_alpha_pixels']
        for direction, cell in row['geometry']['cells'].items():
            x, y, w, h = cell['region']
            yy, xx = np.nonzero(alpha[y:y+h, x:x+w] >= 16)
            assert len(xx) == cell['strong_pixels']
            bbox = [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)]
            assert bbox == cell['strong_alpha_local_bbox']
            touches = bbox[0] == 0 or bbox[1] == 0 or bbox[2] == w or bbox[3] == h
            assert touches == cell['strong_touches_region_edge']
            if direction in row['preview_selected_directions']:
                assert not touches, (row['key'], direction, 'Selected preview view clips strong content')
            views += 1
        assert not row['production_qualified'] and not row['native_game_adopted']
    assert views == manifest['direct_seen_views'] == 39
    assert sha(ROOT / manifest['cart_reference']['path']) == manifest['cart_reference']['sha256']
    assert not manifest['complete_gait_accepted'] and not manifest['runtime_adopted']
    return {'source_inventory_verified': True, 'images': 12, 'views': views,
            'runtime_adopted': False, 'complete_gait_accepted': False,
            'scope': 'Original PNG SHA, repo-bound references, dimensions/alpha/region geometry only.'}


if __name__ == '__main__':
    print(json.dumps(verify()))
