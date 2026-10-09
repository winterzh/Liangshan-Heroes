"""Read-only native 2x2 idle source audit. Facing/posture require separate visual review."""
from pathlib import Path
import hashlib, json, sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
key, state = sys.argv[1:3]
version=sys.argv[3] if len(sys.argv)>3 else 'v3'
assert version in ('v3','v4')
job_path = HERE/'jobs'/f'{key}_{state}_{version}.json'
job = json.loads(job_path.read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
path = ROOT/job['output']
assert sha(path) == job['output_sha256']
assert sha(ROOT/job['request']) == job['request_sha256']
for ref in job['references']:
    assert sha(ROOT/ref['path']) == ref['sha256']
with Image.open(path) as im:
    assert im.mode == 'RGBA' and list(im.size) == job['native_size'] and max(im.size) <= 1536
    assert im.width % 2 == 0 and im.height % 2 == 0
    alpha = im.getchannel('A')
    assert alpha.getextrema()[0] == 0
    mask = alpha.point(lambda value: 255 if value > 16 else 0)
    width, height = im.width//2, im.height//2
    checks = []
    for direction, (x, y) in zip(('se', 'sw', 'ne', 'nw'), ((0,0),(width,0),(0,height),(width,height))):
        bbox = mask.crop((x,y,x+width,y+height)).getbbox()
        clearance = min(bbox[0],bbox[1],width-bbox[2],height-bbox[3]) if bbox else -1
        checks.append({'direction_label_pending_visual_review': direction,
                       'region': [x,y,width,height], 'bbox_relative': list(bbox) if bbox else None,
                       'clearance_px': clearance, 'passed': clearance >= 4})
    zero_fraction = alpha.histogram()[0]/(im.width*im.height)
receipt = {'scope': 'Native read-only source/request/immediate-parent/RGBA/dimensions/region-clearance only; no direction/anatomy/engine/gameplay acceptance',
           'path': job['output'], 'sha256': job['output_sha256'], 'native_size': job['native_size'],
           'alpha_zero_fraction': zero_fraction, 'checks': checks,
           'passed': all(check['passed'] for check in checks), 'production_qualified': False}
out = ROOT/'qa/zhu_wounded_20261005'/f'{key}_{state}_bounds_{version}.json'
out.write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'character': key, 'state': state, 'passed': receipt['passed'],
                  'clearances': [c['clearance_px'] for c in checks]}))
sys.exit(0 if receipt['passed'] else 1)
