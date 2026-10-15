"""Read-only provenance and native layout audit of unadopted Liu Tang PNGs.

Reads PNG pixels only; does not crop, mirror, scale, reencode or bind assets.
Source integrity is separate from animation, native runtime and canon adoption.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/liu_tang_canon_sources_20261016'
QA = ROOT / 'qa/liu_tang_candidates_20261016'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gaps(counts):
    n = len(counts)
    runs, start = [], None
    for i in range(int(n * .4), int(n * .6) + 1):
        if counts[i] == 0 and start is None:
            start = i
        if start is not None and (counts[i] != 0 or i == int(n * .6)):
            end = i if counts[i] != 0 else i + 1
            runs.append([start, end])
            start = None
    return runs


def audit():
    prompts = json.loads((SOURCE / 'prompt_set.json').read_text(encoding='utf-8'))
    assert prompts['mode'] == 'builtin' and prompts['candidate_only']
    assert not prompts['production_qualified'] and not prompts['png_pixel_writes']
    assert len(prompts['jobs']) == 19
    rows = []
    for job in prompts['jobs']:
        path = ROOT / job['path']
        assert path.parent == SOURCE and path.name == job['key'] + '_native.png'
        assert sha(path) == job['sha256'] and path.stat().st_size == job['bytes']
        references = []
        for ref in job['references']:
            target = (ROOT / ref['path']).resolve()
            assert target.is_relative_to(ROOT.resolve())
            assert sha(target) == ref['sha256']
            references.append({'path': ref['path'], 'sha256': ref['sha256']})
        with Image.open(path) as image:
            assert image.format == 'PNG' and list(image.size) == job['native_size']
            assert image.mode == job['mode'] and min(image.size) >= 1000
            image.load()
            if job['transparent_background']:
                assert image.mode == 'RGBA'
                alpha = np.array(image.getchannel('A'))
                assert int(alpha.min()) == 0 and int(alpha.max()) == 255
                mask = alpha >= 16
                ys, xs = np.where(mask)
                bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
                layout = {'strong_alpha_threshold': 16, 'bounds': bounds,
                          'top_left_alpha': int(alpha[0, 0]),
                          'zero_alpha_fraction': float(np.mean(alpha == 0)),
                          'fully_clear_top_left': bool(alpha[0, 0] == 0),
                          'outer_margins': [bounds[0], bounds[1], image.width - bounds[2], image.height - bounds[3]]}
                if job['key'] != 'walk_contact_b_nw':
                    xg, yg = gaps(mask.sum(axis=0)), gaps(mask.sum(axis=1))
                    layout.update({'central_x_clear_runs': xg, 'central_y_clear_runs': yg,
                                   'has_independent_rectangular_cells': bool(xg and yg)})
                else:
                    layout['single_direction'] = 'nw'
            else:
                layout = None
            rows.append({'key': job['key'], 'path': job['path'], 'sha256': sha(path),
                         'bytes': path.stat().st_size, 'mode': image.mode,
                         'native_size': list(image.size), 'references': references, 'layout': layout})
    assert len({row['key'] for row in rows}) == 19
    assert {p.name for p in SOURCE.glob('*.png')} == {r['key'] + '_native.png' for r in rows}
    assert (SOURCE / '.gdignore').is_file()
    return {'mode': 'builtin', 'sources': rows, 'prompt_set_sha256': sha(SOURCE / 'prompt_set.json'),
            'identity_card': 'docs/LIU_TANG_IDENTITY_20261016.md', 'integrity_verified': True,
            'candidate_only': True, 'png_pixel_writes': False, 'production_qualified': False,
            'native_import_run': False, 'gait_accepted': False, 'combat_correction_complete': False,
            'stage_merchant_drawn': False, 'steam_updated': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    report = audit()
    if args.out:
        output = args.out.resolve()
        assert output.is_relative_to(QA.resolve()) and not output.exists()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode())
    unseparated = [r['key'] for r in report['sources'] if r['layout'] and
                   r['layout'].get('has_independent_rectangular_cells') is False]
    alpha_review = [r['key'] for r in report['sources'] if r['layout'] and
                    not r['layout']['fully_clear_top_left']]
    print(json.dumps({'candidate_pngs': len(report['sources']), 'source_integrity_verified': True,
                      'faint_corner_alpha_requires_review': alpha_review,
                      'layout_requires_revision': unseparated, 'candidate_only': True,
                      'production_qualified': False, 'native_run': False}))


if __name__ == '__main__':
    main()
