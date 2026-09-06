"""Read-only native PNG / prompt lineage audit. Requires Pillow."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=ROOT / '.godot/wall_gate_native/sources.json')
    args = parser.parse_args()
    data = json.loads((ROOT / 'tools/contracts/zhu_gate_native_20260906/generation.json').read_text(encoding='utf-8'))
    checks = []

    def check(name, passed):
        checks.append({'name': name, 'passed': bool(passed)})

    def valid(record):
        path = (ROOT / record['path']).resolve()
        return path.is_relative_to(ROOT) and path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']

    check('existing reference retained', valid(data['original_reference']))
    for job in data['jobs']:
        check(job['key'] + ' native bytes retained', valid(job['output']))
        check(job['key'] + ' exact prompt retained', valid(job['prompt']))
        check(job['key'] + ' references portable and retained', all(valid(ref) for ref in job['references']))
    check('production equals selected native output', data['production'] == data['jobs'][-1]['output'] and valid(data['production']))
    im = Image.open(ROOT / data['production']['path'])
    check('native RGBA', im.mode == 'RGBA')
    check('native resolution retained', list(im.size) == data['jobs'][-1]['size'])
    alpha = im.getchannel('A')
    transparent_fraction = alpha.histogram()[0] / (im.width * im.height)
    check('transparent background coverage', transparent_fraction > 0.5)
    visible = alpha.point(lambda x: 255 if x > 15 else 0).getbbox()
    check('visible silhouette has padding', visible[0] > 16 and visible[1] > 16 and visible[2] < im.width - 16 and visible[3] < im.height - 16)
    for name, point in data['feet_native_pixels'].items():
        check(name + ' foot lies on visible art', alpha.getpixel(tuple(point)) > 127)
    settings = (ROOT / (data['production']['path'] + '.import')).read_text(encoding='utf-8')
    check('import limited to 512', 'process/size_limit=512' in settings)
    check('standard mipmaps enabled', 'mipmaps/generate=true' in settings)
    report = {'checks': len(checks), 'passed': all(c['passed'] for c in checks), 'results': checks,
              'native_size': im.size, 'visible_bbox_alpha_over_15': visible, 'transparent_fraction': transparent_fraction}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'checks': len(checks), 'passed': report['passed'], 'failures': [c['name'] for c in checks if not c['passed']]}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
