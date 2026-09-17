"""Copy only final upload assets into a clean, grouped handoff directory."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    target = args.output_dir.resolve()
    video_files = list((ROOT / 'video').glob('*.mp4'))
    screenshots = sorted((ROOT / 'video/screenshots').glob('*.png'))
    assert len(video_files) == 1, video_files
    assert len(screenshots) == 5, screenshots
    groups = {
        '01-商店封面': sorted((ROOT / 'capsules').glob('*.png')),
        '02-游戏库图片': sorted((ROOT / 'library').glob('*.png')),
        '03-实机截图': screenshots,
        '04-实机视频': video_files,
        '05-视频封面与公告配图': sorted((ROOT / 'promotional').glob('*.png')),
    }
    assert [len(v) for v in groups.values()] == [8, 6, 5, 1, 2]
    rows = []
    for group, paths in groups.items():
        (target / group).mkdir(parents=True, exist_ok=True)
        for source in paths:
            destination = target / group / source.name
            expected = sha(source)
            if destination.exists():
                assert sha(destination) == expected, f'Refusing to overwrite a different file: {destination}'
            else:
                shutil.copy2(source, destination)
            assert sha(destination) == expected
            rows.append({'source': source.relative_to(ROOT).as_posix(),
                         'destination': destination.relative_to(target).as_posix(),
                         'bytes': destination.stat().st_size, 'sha256': expected})
    result = {'status': 'PASS', 'scope': 'Local final-file copy identity; no Steam upload implied.',
              'target': str(target), 'files': rows, 'count': len(rows)}
    (target / 'files_manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    shutil.copy2(ROOT / 'UPLOAD_GUIDE.md', target / '先看这里.md')
    (ROOT / '../../qa/steam_store_media_20260909_female/upload_bundle.json').resolve().write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'PASS', 'count': len(rows), 'target': str(target)}, ensure_ascii=False))

if __name__ == '__main__':
    main()
