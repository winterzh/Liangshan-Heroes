"""Expand spatial rectangles until original alpha edges are empty; preserve virtual cells."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
Q = Path(__file__).resolve().parent
prior = json.loads((Q / 'selected_regions_v2.json').read_text(encoding='utf-8'))
path = Q / prior['source']
assert hashlib.sha256(path.read_bytes()).hexdigest() == prior['sha256']
with Image.open(path) as im:
    alpha = np.asarray(im.getchannel('A'))
rows = []
for old in prior['regions']:
    x, y, w, h = old['region']
    right, bottom = x+w, y+h
    cx, cy, cw, ch = old['source_cell']
    history = []
    for attempt in range(64):
        cut = alpha[y:bottom, x:right]
        hits = [int(np.count_nonzero(cut[:, 0])), int(np.count_nonzero(cut[0])),
                int(np.count_nonzero(cut[:, -1])), int(np.count_nonzero(cut[-1]))]
        history.append({'rectangle': [x, y, right-x, bottom-y], 'edge_hits_left_top_right_bottom': hits})
        if not any(hits):
            break
        x -= bool(hits[0]); y -= bool(hits[1])
        right += bool(hits[2]); bottom += bool(hits[3])
        assert cx < x < right < cx+cw and cy < y < bottom < cy+ch
    else:
        raise AssertionError('No transparent sampling edge within fixed budget')
    bx, by, br, bb = old['primary_component']['bbox']
    assert x <= bx and y <= by and right >= br and bottom >= bb
    rows.append({'direction': old['direction'], 'source_cell': old['source_cell'],
                 'region': [x, y, right-x, bottom-y],
                 'virtual_margin': [x-cx, y-cy, cw-(right-x), ch-(bottom-y)],
                 'primary_component': old['primary_component'], 'edge_alpha_nonzero_pixels': 0,
                 'edge_alpha_clear': True, 'expansion_history': history,
                 'no_source_scale_or_translation': True})
included = np.zeros(alpha.shape, dtype=bool)
for row in rows:
    x, y, w, h = row['region']
    included[y:y+h, x:x+w] = True
outside = alpha[~included]
result = {'source': prior['source'], 'sha256': prior['sha256'], 'regions': rows,
          'omitted_pixels_nonzero': int(np.count_nonzero(outside)),
          'omitted_max_alpha': int(outside.max()), 'nominal_627_cell_edges_accepted': False,
          'sampling_edges_accepted': True,
          'scope': 'Fixed spatial rectangles keep complete main figures and spears, including all original pixels inside each rectangle. Virtual padding preserves original 627px cell placement. No PNG writes, alpha threshold mask or per-frame normalization. Faint isolated pixels outside these rectangles are not sampled.',
          'native_accepted': False, 'production_adopted': False}
with (Q / 'selected_regions_v3.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'regions'}))
print(json.dumps([{'direction': r['direction'], 'region': r['region'], 'steps': len(r['expansion_history'])} for r in rows]))
