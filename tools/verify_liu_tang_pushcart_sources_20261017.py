"""Read-only provenance and strict corner-alpha audit of unbound pushcart art."""
import hashlib,json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/characters/liu_tang_pushcart_sources_20261017/prompt_set.json'

def source(name):
    relative=Path(name)
    if relative.is_absolute() or '..' in relative.parts or '\\' in name:
        raise ValueError('Invalid source path: '+name)
    path=ROOT/relative
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError('Source escapes project: '+name)
    return path

def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle,'sha256').hexdigest()

def main():
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
    rows=manifest['sources'];keys=[r['key'] for r in rows]
    assert len(rows)==11 and len(set(keys))==11
    selected=manifest['selected_candidates']
    assert len(selected)==len(set(selected))==5 and set(selected)<=set(keys)
    assert not manifest['runtime_adopted'] and not manifest['pixel_writes']
    assert (MANIFEST.parent/'.gdignore').is_file()
    strict_failures=[];historical_failures=[];references=0
    for row in rows:
        path=source(row['path']);assert digest(path)==row['sha256']
        assert path.stat().st_size==row['bytes'] and not row['runtime_adopted']
        for ref in row['references']:
            assert digest(source(ref['path']))==ref['sha256'];references+=1
        with Image.open(path) as image:
            image.load();assert image.mode=='RGBA'
            assert list(image.size)==row['geometry']['size']
            w,h=image.size
            corners=[image.getpixel(p)[3] for p in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]]
        assert corners==row['geometry']['corner_alpha']
        if any(corners):
            (strict_failures if row['key'] in selected else historical_failures).append(row['key'])
    assert references==14
    print(json.dumps({'source_integrity_passed':True,'sources':len(rows),
        'references':references,'selected_candidates':selected,
        'strict_zero_corner_alpha_passed':not strict_failures,
        'strict_zero_corner_alpha_failures':strict_failures,
        'retained_superseded_corner_alpha_failures':historical_failures,
        'runtime_adopted':False,'native_launched':False},ensure_ascii=False))
    return 1 if strict_failures else 0

if __name__=='__main__':raise SystemExit(main())
