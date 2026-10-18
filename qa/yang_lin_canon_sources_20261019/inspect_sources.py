"""Read-only pixel/boundary checks, not anatomy, native import or gameplay acceptance."""
from pathlib import Path
import hashlib, json
from PIL import Image
Q = Path(__file__).resolve().parent
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
rows = []
for key in ['portrait_v1', 'idle_v1']:
    source = json.loads((Q / ('source_' + key + '.json')).read_text(encoding='utf-8'))
    path = Q / source['file']
    assert sha(path) == source['sha256'] == sha(Path(source['generated_original']))
    with Image.open(path) as im:
        assert im.size == (1254, 1254)
        row = {'key': key, 'sha256': sha(path), 'mode': im.mode, 'size': list(im.size)}
        if key.startswith('idle'):
            assert im.mode == 'RGBA'
            alpha = im.getchannel('A')
            row['alpha_extrema'] = list(alpha.getextrema())
            row['alpha_zero_pixels'] = alpha.histogram()[0]
            row['alpha_nonzero_bbox'] = list(alpha.getbbox())
            row['fixed_regions'] = []
            for label, x, y in [('se', 0, 0), ('sw', 627, 0), ('ne', 0, 627), ('nw', 627, 627)]:
                a = alpha.crop((x, y, x + 627, y + 627))
                bbox = a.getbbox()
                meaningful = a.point(lambda v: 255 if v >= 64 else 0).getbbox()
                row['fixed_regions'].append({'direction': label, 'region': [x, y, 627, 627],
                    'alpha_bbox_local': list(bbox), 'alpha64_bbox_local': list(meaningful),
                    'clear_all_edges_alpha1': bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 627 and bbox[3] < 627})
            row['central_vertical_alpha_pixels'] = sum(v > 0 for v in alpha.crop((626, 0, 628, 1254)).getdata())
            row['central_horizontal_alpha_pixels'] = sum(v > 0 for v in alpha.crop((0, 626, 1254, 628)).getdata())
        rows.append(row)
with (Q / 'source_inspection_v1.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps({'scope': 'Read-only source pixels and nominal atlas boundaries only.',
                             'sources': rows, 'local_pixel_writes': False,
                             'native_accepted': False, 'production_adopted': False}, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(rows))
