"""Copy native image_gen sources and conform dimensions only using FFmpeg.

No crop, repaint, compositing, or text replacement is performed here.
All creative layout and lettering were produced by the built-in image_gen tool.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ASSETS = [
    ('main', 'exec-8b4ca627-db2d-4f41-8ebb-df228afc1d20.png', 1232, 706),
    ('header', 'exec-ba763add-867e-4135-ab7f-e2b5e3b2385a.png', 920, 430),
    ('small', 'exec-2c5d2e16-a6e6-49ea-bc59-ced1088b68c7.png', 462, 174),
    ('vertical', 'exec-30824001-09a7-433d-9729-4ae799017920.png', 748, 896),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-dir', type=Path)
    args = parser.parse_args()
    base = Path(__file__).resolve().parent
    (base / 'source').mkdir(exist_ok=True)
    (base / 'capsules').mkdir(exist_ok=True)
    receipt = []
    for name, original, width, height in ASSETS:
        source = base / 'source' / (name + '_native.png')
        if args.native_dir:
            shutil.copy2(args.native_dir / original, source)
        target = base / 'capsules' / (name + '.png')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source), '-vf', f'scale={width}:{height}:flags=lanczos', '-frames:v', '1', '-update', '1', str(target)], check=True)
        localized = target.with_name(name + '_schinese.png')
        shutil.copy2(target, localized)
        receipt.append({'asset': name, 'source': source.relative_to(base).as_posix(), 'native_sha256': sha(source), 'upload': target.relative_to(base).as_posix(), 'schinese_upload': localized.relative_to(base).as_posix(), 'width': width, 'height': height, 'sha256': sha(target), 'bytes': target.stat().st_size, 'localized_identical': sha(target) == sha(localized)})
    (base / 'capsule_manifest.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
