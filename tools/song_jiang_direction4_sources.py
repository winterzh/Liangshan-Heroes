"""Read-only native-image lineage/import audit. Run with Python + Pillow."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=ROOT / '.godot/song_jiang_direction4/sources.json')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'assets/direction4/song_jiang_20260906.json').read_text(encoding='utf-8'))
    lineage = json.loads((ROOT / 'tools/contracts/song_jiang_direction4_20260906/generation.json').read_text(encoding='utf-8'))
    jobs = {j['key']: j for j in lineage['jobs']}
    checks = []

    def check(name, ok):
        checks.append({'name': name, 'passed': bool(ok)})

    def verify_file(record):
        p = (ROOT / record['path']).resolve()
        return p.is_relative_to(ROOT) and p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest() == record['sha256']

    check('existing identity reference retained', verify_file(lineage['original_reference']))
    for job in jobs.values():
        if not job['repository_path']:
            continue  # Rejected, unconsumed candidates are catalogued, not production inputs.
        check(job['key'] + ' native bytes', verify_file({'path': job['repository_path'], 'sha256': job['sha256']}))
        for reference in job['references']:
            check(job['key'] + ' portable reference ' + reference,
                  reference == 'original' or reference in jobs and jobs[reference]['repository_path'] is not None)
    imported_bytes = 0
    for key, source in manifest['sources'].items():
        p = ROOT / source['path']
        with Image.open(p) as im:
            check(key + ' native RGBA and dimensions', im.mode == 'RGBA' and list(im.size) == source['native_size'])
            check(key + ' substantial real transparency', im.mode == 'RGBA' and im.getchannel('A').histogram()[0] / (im.width * im.height) > .35)
        meta = Path(str(p) + '.import').read_text(encoding='utf-8')
        check(key + ' bounded import', f"process/size_limit={source['import_limit']}" in meta and max(source['imported_size']) <= source['import_limit'])
        check(key + ' native selected output', source['sha256'] == jobs[source['job']]['sha256'])
        imported_bytes += source['imported_size'][0] * source['imported_size'][1] * 4
    for key, pose in manifest['poses'].items():
        source = manifest['sources'][pose['source']]
        x, y, w, h = pose['region_raw']
        check(key + ' fixed source region within native image', min(x, y) >= 0 and min(w, h) > 0 and x + w <= source['native_size'][0] and y + h <= source['native_size'][1])
        check(key + ' square padded frame', pose['region'][2] + pose['margin'][2] == pose['virtual_size_imported'] and pose['region'][3] + pose['margin'][3] == pose['virtual_size_imported'])
    check('wrong-handed SW atlas cell never selected', manifest['poses']['walk_sw']['source'] == 'walk_sw' and manifest['poses']['walk_se']['source'] == 'walk_atlas')
    for resource in manifest['resources']:
        text = (ROOT / resource).read_text(encoding='utf-8')
        paths = re.findall(r'path="res://([^\"]+)"', text)
        check(resource + ' dependencies present', all((ROOT / p).is_file() for p in paths))
    result = {'checks': checks, 'passed': all(c['passed'] for c in checks), 'production_pngs': len(manifest['sources']), 'direction_state_resources': len(manifest['resources']), 'authored_poses': len(manifest['poses']), 'rgba_base_level_bytes': imported_bytes, 'scope': 'Native bytes, source lineage, transparency, import configuration and atlas bounds. Visual identity/direction requires the actual Unit review.'}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'checks': len(checks), 'passed': result['passed'], 'failed': [c['name'] for c in checks if not c['passed']], 'rgba_base_level_bytes': imported_bytes}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
