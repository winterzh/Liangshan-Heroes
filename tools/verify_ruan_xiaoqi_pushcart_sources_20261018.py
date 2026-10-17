"""Read-only original provenance and explicit Atlas-view audit; never edits pixels.

This verifies source inputs and static view isolation, not native motion/filtering
or production adoption. Rejected gait and whole-PNG alpha failures stay visible.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/characters/ruan_xiaoqi_pushcart_sources_20261018/prompt_set.json'
DIRS = ('se', 'sw', 'ne', 'nw')
POSES = ('push_idle', 'push_contact_a', 'push_passing_a', 'push_contact_b', 'push_passing_b')


def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def path(name):
    p = Path(name)
    assert not p.is_absolute() and '..' not in p.parts and '\\' not in name
    result = (ROOT / p).resolve()
    assert result.is_relative_to(ROOT) and result.is_file()
    assert not (ROOT / p).is_symlink()
    return result


def verify():
    m = json.loads(MANIFEST.read_text(encoding='utf-8'))
    rows = m['sources']
    by_key = {r['key']: r for r in rows}
    assert len(rows) == len(by_key) == 5
    assert set(m['selected_candidates']) == {'push_idle_initial', 'push_contact_a', 'push_passing_a', 'push_contact_b', 'push_passing_b'}
    assert m['mode'] == 'builtin_imagegen' and not m['pixel_writes'] and not m['runtime_adopted']
    assert (MANIFEST.parent / '.gdignore').is_file()
    assert set(m['view_bindings']) == set(POSES)
    checks, failures, images = [], [], {}
    references, available = 0, 0

    def check(ok, label):
        checks.append({'name': label, 'passed': bool(ok)})
        assert ok, label

    for row in rows:
        p = path(row['path'])
        check(sha(p) == row['sha256'] and p.stat().st_size == row['bytes'], 'original bytes ' + row['key'])
        original = Path(row['generated_path'])
        if original.is_file():
            check(sha(original) == row['sha256'], 'original generated file ' + row['key'])
            available += 1
        check(bool(row['prompt']) and bool(row['references']), 'complete request ' + row['key'])
        for ref in row['references']:
            check(sha(path(ref['repository_path'])) == ref['sha256'], 'reference ' + row['key'] + ' ' + ref['repository_path'])
            references += 1
        with Image.open(p) as im:
            check(im.mode == 'RGBA' and list(im.size) == row['geometry']['size'], 'RGBA native dimensions ' + row['key'])
            a = np.asarray(im.getchannel('A')).copy()
        images[row['key']] = a
        corners = a[[0, 0, -1, -1], [0, -1, 0, -1]].tolist()
        check(corners == row['geometry']['corner_alpha'], 'whole-source corner record ' + row['key'])
        sx, sy = row['geometry']['split']
        check([int(a[:, sx].max()), int(a[sy, :].max())] == row['geometry']['axis_max_alpha'], 'recorded low-alpha axes ' + row['key'])
        if any(corners):
            failures.append({'key': row['key'], 'corners': corners, 'selected_directions': row['selected_directions']})

    selected, views = set(), []
    for pose in POSES:
        bindings = m['view_bindings'][pose]
        check(set(bindings) == set(DIRS), 'four explicit directions ' + pose)
        for d in DIRS:
            key = bindings[d]
            selected.add(key)
            row = by_key[key]
            a = images[key]
            h, w = a.shape
            x, y, cw, ch = row['geometry']['cells'][d]['region']
            sx, sy = row['geometry']['split']
            check(min(x, y) >= 0 and min(cw, ch) > 0 and x + cw <= w and y + ch <= h, 'Atlas view bounds ' + pose + d)
            check(not np.any(a[:, sx] >= 16) and not np.any(a[sy, :] >= 16), 'separated strong-alpha axes ' + pose + d)
            corners = a[[y, y, y + ch - 1, y + ch - 1], [x, x + cw - 1, x, x + cw - 1]].tolist()
            check(corners == [0, 0, 0, 0] and corners == row['geometry']['cells'][d]['corner_alpha'], 'selected-view zero corners ' + pose + d)
            x0, y0, xe, ye = {'se': (0, 0, sx, sy), 'sw': (sx, 0, w, sy), 'ne': (0, sy, sx, h), 'nw': (sx, sy, w, h)}[d]
            yy, xx = np.where(a[y0:ye, x0:xe] >= 16)
            bounds = [int(xx.min() + x0), int(yy.min() + y0), int(xx.max() + x0 + 1), int(yy.max() + y0 + 1)]
            check(bounds == row['geometry']['cells'][d]['strong_bounds'] and x <= bounds[0] < bounds[2] <= x + cw and y <= bounds[1] < bounds[3] <= y + ch, 'all strong-alpha view pixels retained ' + pose + d)
            check(row['selected_candidate'] and d in row['selected_directions'], 'selected-view authority ' + pose + d)
            check(m['manual_view_review'][pose][d]['seen'] and m['manual_view_review'][pose][d]['source'] == key, 'recorded direct source review ' + pose + d)
            views.append({'pose': pose, 'direction': d, 'source': key, 'region': [x, y, cw, ch], 'corner_alpha': corners})
    check(selected == set(m['selected_candidates']), 'selected inventory')
    return {'passed': True, 'checks': checks, 'sources': len(rows), 'references': references, 'original_generated_files_available': available,
            'selected_source_pngs': len(selected), 'selected_views': views, 'rejected_sources': [],
            'whole_source_corner_alpha_failures_retained': failures,
            'full_selected_atlases_zero_corner_alpha_passed': not any(r['key'] in selected for r in failures),
            'scope': 'Original byte/reference provenance, static Atlas views retaining all strong-alpha pixels and recorded direct review only. Idle original BL alpha1 remains and whole-selected-atlas corner status is false; 5px minimum strong-alpha x gutter. One-pixel Atlas outer-border omission changes no PNG pixels. Native filtering, rear support-leg alternation, full four-phase balance, wheel/cloth continuity and production adoption remain open.',
            'pixel_writes': False, 'runtime_adopted': False, 'native_launched': False}


if __name__ == '__main__':
    result = verify()
    print(json.dumps({k: v for k, v in result.items() if k not in ['checks', 'selected_views']}, ensure_ascii=False))
