"""Fixed source rectangles + virtual padding; no PNG writes or alpha threshold mask."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
Q = Path(__file__).resolve().parent
path = Q / 'native_originals/idle_v2.png'
components = json.loads((Q / 'components_v2.json').read_text(encoding='utf-8'))
assert hashlib.sha256(path.read_bytes()).hexdigest() == components['sha256']
# Chosen around the full authored figure/spear, in original canvas coordinates.
# Virtual padding keeps the original 627px cell size and source placement unchanged.
regions = [('se', [0, 0, 627, 627], [225, 99, 244, 498]),
           ('sw', [627, 0, 627, 627], [785, 99, 249, 499]),
           ('ne', [0, 627, 627, 627], [237, 668, 235, 493]),
           ('nw', [627, 627, 627, 627], [781, 667, 240, 494])]
rows = []
with Image.open(path) as im:
    alpha = np.asarray(im.getchannel('A'))
    for direction, cell, region in regions:
        x, y, w, h = region
        cut = alpha[y:y+h, x:x+w]
        edges = int(np.count_nonzero(cut[0])) + int(np.count_nonzero(cut[-1]))
        edges += int(np.count_nonzero(cut[:, 0])) + int(np.count_nonzero(cut[:, -1]))
        primary = [c for c in components['main_four']
                   if x <= c['bbox'][0] and y <= c['bbox'][1]
                   and x+w >= c['bbox'][2] and y+h >= c['bbox'][3]]
        assert len(primary) == 1
        rows.append({'direction': direction, 'source_cell': cell, 'region': region,
                     'virtual_margin': [x-cell[0], y-cell[1], 627-w, 627-h],
                     'primary_component': primary[0], 'edge_alpha_nonzero_pixels': edges,
                     'edge_alpha_clear': edges == 0,
                     'no_source_scale_or_translation': True})
    included = np.zeros(alpha.shape, dtype=bool)
    for _, _, (x, y, w, h) in regions:
        included[y:y+h, x:x+w] = True
    outside = alpha[~included]
    result = {'source': 'native_originals/idle_v2.png', 'sha256': components['sha256'],
              'regions': rows, 'omitted_pixels_nonzero': int(np.count_nonzero(outside)),
              'omitted_max_alpha': int(outside.max()),
              'nominal_627_cell_edges_accepted': False,
              'scope': 'Spatial sampling candidate only. Faint isolated alpha outside full figures is omitted by region; original PNG unchanged. Not native/render/anatomy acceptance.',
              'native_accepted': False, 'production_adopted': False}
with (Q / 'selected_regions_v2.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result))
