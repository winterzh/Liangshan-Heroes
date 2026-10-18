"""Preserve the exact built-in atlas framing edit and its edit target."""
from pathlib import Path
import datetime, hashlib, json, shutil, sys
from PIL import Image
Q = Path(__file__).resolve().parent
source = Path(sys.argv[1]).resolve()
target = Q / 'native_originals/idle_v2.png'
assert not target.exists()
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
args_file = Q / 'tool_prompt_idle_v2.json'
args = json.loads(args_file.read_text(encoding='utf-8'))
assert args['transparent_background'] is True
assert len(args['referenced_image_paths']) == 1
shutil.copyfile(source, target)
assert sha(source) == sha(target)
with Image.open(target) as im:
    assert im.mode == 'RGBA' and im.size == (1254, 1254)
    row = {'key': 'idle_v2', 'mode': 'builtin_imagegen', 'intent': 'atlas_framing_edit',
           'file': target.relative_to(Q).as_posix(), 'generated_original': str(source),
           'sha256': sha(target), 'bytes': target.stat().st_size, 'pixel_mode': im.mode,
           'size': list(im.size), 'exact_tool_arguments': args_file.name,
           'prompt_sha256': hashlib.sha256(args['prompt'].encode()).hexdigest(),
           'transparent_background_requested': True,
           'references': [{'path': p, 'sha256': sha(Path(p)), 'role': 'edit_target'}
                          for p in args['referenced_image_paths']],
           'local_pixel_writes': False, 'production_adopted': False,
           'recorded_at': datetime.datetime.now().isoformat()}
with (Q / 'source_idle_v2.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(row, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'sha256': row['sha256'], 'size': row['size'], 'mode': row['pixel_mode']}))
