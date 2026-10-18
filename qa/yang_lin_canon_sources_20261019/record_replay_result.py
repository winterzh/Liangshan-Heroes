"""Keep the strict replay failure, and record actual differences without reclassifying it."""
from pathlib import Path
import ast, hashlib, json, shutil
from PIL import Image, ImageChops
Q = Path(__file__).resolve().parent
E = Path('D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
rows = []
for label, subdir, png, svg, receipt_name, helper in [
        ('source_review', 'review_replay', 'review.png', 'review.svg', 'browser_receipt.json', 'render_review.py'),
        ('registered_review', 'registered_replay', 'registered.png', 'registered.svg', 'registration.json', 'render_registered.py')]:
    output = E / subdir
    receipt = json.loads((output/receipt_name).read_text(encoding='utf-8'))
    assert receipt['executed_helper_sha256'] == sha(Q/helper)
    assert sha(output/png) == receipt['png_sha256']
    assert sha(output/svg) == receipt['svg_sha256'] == sha(Q/svg)
    with Image.open(Q/png) as first, Image.open(output/png) as replay:
        a, b = first.convert('RGB'), replay.convert('RGB')
        difference = ImageChops.difference(a, b)
        bbox = difference.getbbox()
        pixels_equal = a.tobytes() == b.tobytes()
    copied_receipt = Q/(label+'_replay_receipt.json')
    assert not copied_receipt.exists()
    shutil.copyfile(output/receipt_name, copied_receipt)
    row = {'case': label, 'png_byte_identical': sha(Q/png) == sha(output/png),
           'rgb_pixels_identical': pixels_equal, 'svg_byte_identical': True,
           'pixel_difference_bbox': list(bbox) if bbox else None,
           'first_png_sha256': sha(Q/png), 'replay_png_sha256': sha(output/png),
           'receipt': copied_receipt.name, 'helper': helper, 'helper_sha256': sha(Q/helper)}
    if not pixels_equal:
        assert bbox == (1192, 682, 1224, 714), bbox
        assert not (Q/'review_replay.png').exists()
        shutil.copyfile(output/png, Q/'review_replay.png')
        row['assessment'] = 'Difference is confined to the new portrait 32px box. Cause unestablished; strict image replay equality is not accepted. 32px detail already unqualified.'
    rows.append(row)
assert rows[0]['png_byte_identical'] is False and rows[1]['png_byte_identical'] is True
syntax = []
for path in Q.rglob('*.py'):
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
    syntax.append({'file': path.relative_to(Q).as_posix(), 'sha256': sha(path)})
report = {'scope': 'Independent browser replay, not native/UI or game qualification.',
          'prior_strict_recorder': 'record_replay.py', 'prior_strict_recorder_exit_code': 1,
          'prior_failure': "AssertionError at sha(output/png) == sha(Q/png) == receipt['png_sha256']",
          'prior_failure_reclassified_as_pass': False, 'replays': rows,
          'first_executed_tools': [{'file': p.relative_to(Q).as_posix(), 'sha256': sha(p)}
                                   for p in (Q/'first_executed_tools').glob('*.py')],
          'python_ast_current': syntax, 'production_adopted': False, 'native_accepted': False}
with (Q/'replay_result.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({'strict_all_png_equal': False, 'registered_png_equal': True,
                  'source_review_difference_bbox': rows[0]['pixel_difference_bbox'], 'native_accepted': False}))
