"""Exact original-byte/alpha boundaries, with no threshold masking or pixel writes."""
from pathlib import Path
import hashlib, json
from PIL import Image
Q = Path(__file__).resolve().parent
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
source = json.loads((Q / 'source_idle_v2.json').read_text(encoding='utf-8'))
path = Q / source['file']
assert sha(path) == source['sha256'] == sha(Path(source['generated_original']))
rows = []
with Image.open(path) as im:
    assert im.mode == 'RGBA' and im.size == (1254, 1254)
    alpha = im.getchannel('A')
    assert alpha.getextrema() == (0, 255)
    for label, x, y in [('se', 0, 0), ('sw', 627, 0), ('ne', 0, 627), ('nw', 627, 627)]:
        cell = alpha.crop((x, y, x + 627, y + 627))
        bbox = cell.getbbox()
        row = {'direction': label, 'region': [x, y, 627, 627], 'alpha1_bbox_local': list(bbox),
               'clear_edges_alpha1': bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 627 and bbox[3] < 627,
               'minimum_margin_alpha1': min(bbox[0], bbox[1], 627-bbox[2], 627-bbox[3])}
        rows.append(row)
    row = {'sha256': sha(path), 'mode': im.mode, 'size': list(im.size),
           'alpha_zero_pixels': alpha.histogram()[0], 'alpha_nonzero_bbox': list(alpha.getbbox()),
           'central_vertical_alpha_pixels': sum(v > 0 for v in alpha.crop((626, 0, 628, 1254)).tobytes()),
           'central_horizontal_alpha_pixels': sum(v > 0 for v in alpha.crop((0, 626, 1254, 628)).tobytes()),
           'regions': rows, 'local_pixel_writes': False, 'production_adopted': False,
           'native_accepted': False, 'scope': 'Source alpha/regions only, not anatomy or native import.'}
with (Q / 'source_inspection_v2.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(row, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(row))
