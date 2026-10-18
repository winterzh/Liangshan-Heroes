"""Freeze source-only assessment and verify production/foreign preservation."""
from pathlib import Path
import ast, datetime, hashlib, json, shutil
from PIL import Image

Q = Path(__file__).resolve().parent
R = Q.parents[1]
E = Path('D:/CodexEvidence/shuihu/deng_fei_portrait_20261019')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def save(name, data):
    with (Q / name).open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
originals = []
for key in ['portrait_v1', 'portrait_v2', 'portrait_v3']:
    row = json.loads((Q / ('source_' + key + '.json')).read_text(encoding='utf-8'))
    original = Q / row['file']
    assert sha(original) == row['sha256'] == sha(Path(row['generated_original']))
    args = json.loads((Q / row['exact_tool_arguments']).read_text(encoding='utf-8'))
    assert hashlib.sha256(args['prompt'].encode()).hexdigest() == row['prompt_sha256']
    assert args['transparent_background'] is False
    for reference in row['references']:
        assert sha(Path(reference['path'])) == reference['sha256']
    with Image.open(original) as im:
        assert list(im.size) == row['size'] == [1254, 1254]
        assert im.mode == row['pixel_mode'] == 'RGB'
    originals.append(row)
for prefix in ['readability', 'readability_portrait_v3']:
    receipt = json.loads((Q / (prefix + '_receipt.json')).read_text(encoding='utf-8'))
    assert sha(Q / (prefix + '.png')) == receipt['png_sha256']
    assert sha(Q / (prefix + '.svg')) == receipt['svg_sha256']
    for row in receipt['sources'].values():
        assert sha(Path(row['path'])) == row['sha256']
    assert receipt['exit_code'] == 0
save('prompt_set_v3.json', {'mode': 'builtin_imagegen', 'originals': originals,
     'canon_basis': 'canon_basis.json', 'candidate_for_native_comparison': 'portrait_v3',
     'selection_reason': 'Closer face than v1; v3 restores a thin paper margin above the hair cropped in v2.',
     'production_adopted': False, 'native_accepted': False, 'full_goal_complete': False})
save('visual_assessment.json', {'reviewed_originals': [r['file'] for r in originals],
     'reviewed_browser_captures': ['readability.png', 'readability_portrait_v3.png'],
     'v1': 'Identity/style coherent with references, but face small at 64px.',
     'v2': 'Closer face; upper hair tip cropped, not selected.',
     'v3': 'Thin top paper margin restored. Black curly tied hair, beard, brown cloth and natural red-brown eyes retained. At 64px face and beard read more clearly than v1.',
     'limits': ['32px does not preserve readable eye-color detail.',
                'No claim of exact face geometry or exact requested percentage margin.',
                'Browser source-only display is not Godot import, HUD, codex, exported package or player acceptance.'],
     'canon_scope': 'Chapter44 red eyes and iron chain only; no creature anatomy, magical eye glow, fire or new plot.',
     'production_adopted': False, 'native_accepted': False})
groups = {}
for name, manifest in [('runtime129', 'qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json'),
                       ('protected16', 'qa/tribute_cart_wheel_unit_20261018/protected_next.json'),
                       ('foreign81', 'qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json')]:
    rows = json.loads((R / manifest).read_text(encoding='utf-8'))
    for row in rows:
        assert sha(R / row['path']) == row['sha256'], row['path']
    groups[name] = {'manifest': manifest, 'files': len(rows), 'changes': 0}
assert [groups[k]['files'] for k in ['runtime129', 'protected16', 'foreign81']] == [129, 16, 81]
hud = R / 'scripts/hud.gd'
assert sha(hud) == 'e4bacd9d3ee62cca8328f0468f02a45b72705bd8c3adabcf183706ac9d901c58'
save('preservation.json', {'checked_at': datetime.datetime.now().isoformat(), 'groups': groups,
     'hud_sha256': sha(hud), 'production_changed': False})
parsed = []
for path in Q.glob('*.py'):
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
    parsed.append(path.name)
save('python_syntax.json', {'parsed': sorted(parsed), 'scope': 'Python AST only; not Godot syntax or runtime.'})
archive = Q / 'browser_logs'
archive.mkdir()
for source_dir, tag in [(E / 'readability', 'v1'), (E / 'readability_v3', 'v3')]:
    for name in ['stdout.log', 'stderr.log']:
        shutil.copyfile(source_dir / name, archive / (tag + '_' + name))
print(json.dumps({'originals': len(originals), 'browser_captures': 2, 'preserved': groups,
                  'native_accepted': False, 'production_adopted': False}))
