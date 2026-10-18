"""Preserve a built-in edit original; never rewrite generated pixels or old evidence."""
from pathlib import Path
import datetime, hashlib, json, shutil, sys
from PIL import Image

Q = Path(__file__).resolve().parent
key, source = sys.argv[1], Path(sys.argv[2]).resolve()
assert key in {'portrait_v2', 'portrait_v3'}
destination = Q / 'native_originals' / (key + '.png')
arguments_file = Q / ('tool_prompt_' + key + '.json')
arguments = json.loads(arguments_file.read_text(encoding='utf-8'))
assert arguments['transparent_background'] is False
assert len(arguments['referenced_image_paths']) == 1
assert not destination.exists()
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
shutil.copyfile(source, destination)
assert sha(source) == sha(destination)
with Image.open(destination) as im:
    im.verify()
with Image.open(destination) as im:
    assert im.size == (1254, 1254) and im.mode in {'RGB', 'RGBA'}
    row = {'key': key, 'mode': 'builtin_imagegen', 'intent': 'portrait_composition_edit',
           'file': destination.relative_to(Q).as_posix(), 'generated_original': str(source),
           'sha256': sha(destination), 'bytes': destination.stat().st_size,
           'pixel_mode': im.mode, 'size': list(im.size),
           'rgba8_readonly_sha256': hashlib.sha256(im.convert('RGBA').tobytes()).hexdigest(),
           'paper_background_intended': True, 'exact_tool_arguments': arguments_file.name,
           'prompt_sha256': hashlib.sha256(arguments['prompt'].encode()).hexdigest(),
           'references': [{'path': p, 'role': 'edit_target', 'sha256': sha(Path(p))}
                          for p in arguments['referenced_image_paths']],
           'local_pixel_writes': False, 'production_adopted': False,
           'recorded_at': datetime.datetime.now().isoformat()}
with (Q / ('source_' + key + '.json')).open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(row, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'saved': str(destination), 'sha256': row['sha256'], 'mode': row['pixel_mode']}))
