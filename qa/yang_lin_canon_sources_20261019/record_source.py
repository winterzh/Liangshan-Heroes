"""Copy a built-in original without altering image pixels; provenance only."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, sys
from PIL import Image
Q = Path(__file__).resolve().parent
key, generated = sys.argv[1], Path(sys.argv[2]).resolve()
assert re.fullmatch(r'(portrait|idle)_v[1-9][0-9]*', key)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
args_file = Q / ('tool_prompt_' + key + '.json')
args = json.loads(args_file.read_text(encoding='utf-8'))
target = Q / 'native_originals' / (key + '.png')
target.parent.mkdir(exist_ok=True)
assert not target.exists()
shutil.copyfile(generated, target)
assert sha(generated) == sha(target)
with Image.open(target) as im:
    im.verify()
with Image.open(target) as im:
    assert im.size == (1254, 1254)
    assert im.mode == ('RGBA' if args['transparent_background'] else 'RGB')
    row = {'key': key, 'mode': 'builtin_imagegen', 'intent': 'new_generation_from_references',
           'file': target.relative_to(Q).as_posix(), 'generated_original': str(generated),
           'sha256': sha(target), 'bytes': target.stat().st_size,
           'pixel_mode': im.mode, 'size': list(im.size), 'exact_tool_arguments': args_file.name,
           'prompt_sha256': hashlib.sha256(args['prompt'].encode()).hexdigest(),
           'transparent_background_requested': args['transparent_background'],
           'references': [{'path': p, 'sha256': sha(Path(p)),
                           'role': 'identity_and_existing_body_clothing_reference' if i == 0 else
                                   'different_character_style_only' if key.startswith('portrait') else
                                   'same_character_portrait_identity_reference'}
                          for i, p in enumerate(args['referenced_image_paths'])],
           'local_pixel_writes': False, 'production_adopted': False,
           'recorded_at': datetime.datetime.now().isoformat()}
with (Q / ('source_' + key + '.json')).open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(row, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'saved': str(target), 'sha256': row['sha256'], 'pixel_mode': row['pixel_mode']}))
