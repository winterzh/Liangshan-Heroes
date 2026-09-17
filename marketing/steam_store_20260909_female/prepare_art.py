"""Reproduce only delivery dimensions; all creative layouts come from image_gen.

Run without flags to verify and record every expected delivery artifact.
--rebuild explicitly overwrites the normalized delivery PNGs, never native sources.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parent
ART = [
    ('source/main_approved.png', 'capsules/main.png', 1232, 706, True),
    ('source/header_native.png', 'capsules/header.png', 920, 430, True),
    ('source/small_native.png', 'capsules/small.png', 462, 174, True),
    ('source/vertical_native.png', 'capsules/vertical.png', 748, 896, True),
    ('source/library_capsule_native.png', 'library/library_capsule.png', 600, 900, True),
    ('source/library_hero_native.png', 'library/library_hero.png', 3840, 1240, True),
    ('source/promo_native.png', 'promotional/promo_1920x1080.png', 1920, 1080, False),
    ('source/promo_native.png', 'promotional/announcement_800x450.png', 800, 450, False),
]

def info(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    w, h = struct.unpack('>II', data[16:24])
    return {'path': path.relative_to(ROOT).as_posix(), 'width': w, 'height': h,
            'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rebuild', action='store_true')
    args = parser.parse_args()
    rows = []
    for source, output, width, height, localized in ART:
        src, out = ROOT / source, ROOT / output
        if args.rebuild:
            out.parent.mkdir(parents=True, exist_ok=True)
            scale_filter = f'scale={width}:{height}:flags=lanczos'
            if output == 'library/library_hero.png':
                scale_filter = 'scale=3840:-1:flags=lanczos,crop=3840:1240:0:0,setsar=1'
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                            '-i', str(src), '-vf', scale_filter,
                            '-frames:v', '1', '-update', '1', str(out)], check=True)
            if localized:
                shutil.copy2(out, out.with_name(out.stem + '_schinese.png'))
        native, delivery = info(src), info(out)
        assert (delivery['width'], delivery['height']) == (width, height), output
        row = {'source': native, 'delivery': delivery}
        if localized:
            row['schinese'] = info(out.with_name(out.stem + '_schinese.png'))
            assert row['schinese']['sha256'] == delivery['sha256'], output
        rows.append(row)
    for suffix in ['', '_schinese']:
        src = ROOT / f'capsules/header{suffix}.png'
        dst = ROOT / f'library/library_header{suffix}.png'
        if args.rebuild:
            shutil.copy2(src, dst)
        assert info(src)['sha256'] == info(dst)['sha256']
        rows.append({'copied_from': info(src)['path'], 'delivery': info(dst)})
    approved = info(ROOT / 'source/main_approved.png')
    assert approved['sha256'] == '543d3b6298be9d49eb00752c7e5d2ac7a797e76e35c180051c4f2a1ae96510de'
    result = {'status': 'PASS', 'scope': 'Local PNG dimensions, source hashes and language-copy identity only; not publication or visual approval.', 'assets': rows}
    (ROOT / 'art_manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'PASS', 'asset_rows': len(rows), 'approved_source_unchanged': True}))

if __name__ == '__main__':
    main()
