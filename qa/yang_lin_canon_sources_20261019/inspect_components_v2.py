"""Diagnose all alpha>0 components without modifying or masking the source."""
from pathlib import Path
import hashlib, json
import numpy as np
from scipy import ndimage
from PIL import Image
Q = Path(__file__).resolve().parent
path = Q / 'native_originals/idle_v2.png'
with Image.open(path) as im:
    alpha = np.asarray(im.getchannel('A'))
labels, count = ndimage.label(alpha > 0, structure=np.ones((3, 3), dtype=np.uint8))
objects = ndimage.find_objects(labels)
areas = np.bincount(labels.ravel())
rows = []
for i, slices in enumerate(objects, 1):
    ys, xs = slices
    mask = labels[slices] == i
    values = alpha[slices][mask]
    rows.append({'id': i, 'pixels': int(areas[i]), 'bbox': [xs.start, ys.start, xs.stop, ys.stop],
                 'max_alpha': int(values.max()), 'alpha_sum': int(values.astype(np.uint64).sum())})
rows.sort(key=lambda row: row['pixels'], reverse=True)
result = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
          'method': '8-connected components using exact alpha>0; no source writes or threshold mask.',
          'components': rows, 'main_four': rows[:4],
          'other_pixels': sum(r['pixels'] for r in rows[4:]),
          'other_max_alpha': max((r['max_alpha'] for r in rows[4:]), default=0),
          'scope': 'Diagnostic only; does not qualify crop boundaries, anatomy or native rendering.',
          'production_adopted': False}
with (Q / 'components_v2.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'components'}))
