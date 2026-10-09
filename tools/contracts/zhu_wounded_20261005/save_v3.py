"""Preserve native upright-soldier PNG and its request/source lineage; no pixel edits."""
from pathlib import Path
import hashlib, json, shutil, sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

key, state, original_arg = sys.argv[1:4]
version = sys.argv[4] if len(sys.argv)>4 else 'v3'
assert version in ('v3','v4')
original = Path(original_arg)
request = HERE / 'requests' / f'{key}_{state}_{version}.json'
args = json.loads(request.read_text(encoding='utf-8'))
dest = ROOT / 'assets' / 'characters' / f'{key}_wounded_20261005' / f'{state}_{version}.png'
job_path = HERE / 'jobs' / f'{key}_{state}_{version}.json'
assert not dest.exists() and not job_path.exists(), 'Preserve earlier outputs; use a new state name.'
with Image.open(original) as im:
    assert im.mode == 'RGBA' and max(im.size) <= 1536
    assert im.getextrema()[3][0] == 0 and im.getextrema()[3][1] > 0
    size = list(im.size)
refs = []
for ref in args.get('referenced_image_paths', []):
    path = Path(ref)
    refs.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)})
dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(original, dest)
assert sha(dest) == sha(original)
job = {
    'schema': 1, 'character': key, 'state': state, 'revision': 'upright_soldier_v3' if version=='v3' else 'character_traits_v4',
    'method': 'built-in image_gen native PNG byte-preserved',
    'generation_id': original.stem, 'request': request.relative_to(ROOT).as_posix(),
    'request_sha256': sha(request), 'references': refs,
    'output': dest.relative_to(ROOT).as_posix(), 'output_sha256': sha(dest),
    'native_size': size, 'mode': 'RGBA', 'native_pixel_edits': False,
    'continuous_gait_qualified': False, 'runtime_qualified': False,
    'production_qualified': False,
}
job_path.parent.mkdir(parents=True, exist_ok=True)
job_path.write_text(json.dumps(job, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(job, ensure_ascii=False))
