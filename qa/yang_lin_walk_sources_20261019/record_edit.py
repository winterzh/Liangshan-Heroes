"""Preserve an exact built-in pose edit, including unused quadrants."""
from pathlib import Path
import datetime, hashlib, json, re, shutil, sys
from PIL import Image
Q = Path(__file__).resolve().parent
key, source = sys.argv[1], Path(sys.argv[2]).resolve()
assert re.fullmatch(r'[a-z_]+_v[2-9][0-9]*', key)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
args_file = Q/('tool_prompt_'+key+'.json')
args = json.loads(args_file.read_text(encoding='utf-8'))
assert args['transparent_background'] is True and len(args['referenced_image_paths']) == 1
target = Q/'native_originals'/(key+'.png')
assert not target.exists()
shutil.copyfile(source, target)
assert sha(source) == sha(target)
with Image.open(target) as im:
    assert im.mode == 'RGBA' and im.size == (1254,1254)
    row = {'key': key, 'mode': 'builtin_imagegen', 'intent': 'pose_edit_selected_quadrant_scope',
           'file': target.relative_to(Q).as_posix(), 'generated_original': str(source),
           'sha256': sha(target), 'bytes': target.stat().st_size, 'pixel_mode': im.mode,
           'size': list(im.size), 'exact_tool_arguments': args_file.name,
           'prompt_sha256': hashlib.sha256(args['prompt'].encode()).hexdigest(),
           'references': [{'path': p, 'sha256': sha(Path(p)), 'role':'edit_target'}
                          for p in args['referenced_image_paths']],
           'local_pixel_writes': False, 'production_adopted': False, 'native_accepted': False,
           'recorded_at': datetime.datetime.now().isoformat()}
with (Q/('source_'+key+'.json')).open('x', encoding='utf-8') as stream:
    stream.write(json.dumps(row, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({'key': key, 'sha256': row['sha256']}))
