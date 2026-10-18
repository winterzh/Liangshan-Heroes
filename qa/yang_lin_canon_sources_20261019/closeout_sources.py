"""Source-only closeout: canon evidence, provenance and unchanged production."""
from pathlib import Path
import ast, datetime, hashlib, json
from PIL import Image
Q = Path(__file__).resolve().parent
R = Q.parents[1]
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def save(name, value):
    with (Q / name).open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
book_path = R / 'qa/deng_fei_portrait_20261019/chapter44.txt'
book = book_path.read_text(encoding='utf-8')
quotes = ['手里提著一根浑铁笔管枪。', '生得头圆耳大，鼻直口方，眉秀目疏，腰细膀阔。']
assert all(quote in book for quote in quotes)
source_record = R / 'qa/deng_fei_portrait_20261019/chapter44_source.json'
prior = json.loads(source_record.read_text(encoding='utf-8'))
assert sha(book_path) == prior['extracted_text_sha256']
save('canon_basis.json', {'chapter': 44, 'primary_text': book_path.relative_to(R).as_posix(),
     'primary_text_sha256': sha(book_path), 'web_source_record': source_record.relative_to(R).as_posix(),
     'web_url': prior['url'], 'web_fetched_utc': prior['recorded_utc'],
     'source_reused_not_refetched': True, 'quotes': quotes,
     'art_interpretations': ['Headwrap, bun, beard, leopard-patterned coat, wool trim and colors follow the existing rescued model; the novel nickname does not literally prescribe this costume.',
                             'Plain iron spearhead detail and standing stance are game art interpretations of the named weapon.',
                             'Warm paper portrait background follows the current portrait visual family.'],
     'scope': 'Ordinary named Yang Lin portrait and spear idle candidates only. Do not add weapons to rescued/bound actors, rewrite chapter events or qualify skills from these sources.'})
originals = []
for key in ['portrait_v1', 'idle_v1', 'idle_v2']:
    row = json.loads((Q / ('source_' + key + '.json')).read_text(encoding='utf-8'))
    path = Q / row['file']
    assert sha(path) == row['sha256'] == sha(Path(row['generated_original']))
    args = json.loads((Q / row['exact_tool_arguments']).read_text(encoding='utf-8'))
    assert hashlib.sha256(args['prompt'].encode()).hexdigest() == row['prompt_sha256']
    for reference in row['references']:
        assert sha(Path(reference['path'])) == reference['sha256']
    with Image.open(path) as im:
        assert list(im.size) == row['size'] == [1254, 1254] and im.mode == row['pixel_mode']
    originals.append(row)
save('prompt_set.json', {'mode': 'builtin_imagegen', 'originals': originals,
     'canon_basis': 'canon_basis.json', 'portrait_candidate': 'portrait_v1',
     'idle_candidate': 'idle_v2 with selected_regions_v3.json and registration_v1.json',
     'idle_v1_selection': 'rejected: meaningful foreground reaches nominal center sampling boundaries',
     'production_adopted': False, 'native_accepted': False, 'full_goal_complete': False})
sampling = json.loads((Q / 'selected_regions_v3.json').read_text(encoding='utf-8'))
assert not sampling['nominal_627_cell_edges_accepted']
assert sampling['sampling_edges_accepted'] and sampling['omitted_max_alpha'] == 1
for row in sampling['regions']:
    assert row['edge_alpha_nonzero_pixels'] == 0
    x, y, w, h = row['region']
    with Image.open(Q / sampling['source']) as im:
        a = im.getchannel('A').crop((x, y, x+w, y+h))
        assert not any(a.crop((0, 0, w, 1)).tobytes())
        assert not any(a.crop((0, h-1, w, h)).tobytes())
        assert not any(a.crop((0, 0, 1, h)).tobytes())
        assert not any(a.crop((w-1, 0, w, h)).tobytes())
for filename, image_name, svg_name in [('browser_receipt.json', 'review.png', 'review.svg'),
                                       ('registration_v1.json', 'registered.png', 'registered.svg')]:
    receipt = json.loads((Q / filename).read_text(encoding='utf-8'))
    assert receipt['exit_code'] == 0 and receipt['binding_sha256'] == sha(Q/'selected_regions_v3.json')
    assert receipt['png_sha256'] == sha(Q/image_name) and receipt['svg_sha256'] == sha(Q/svg_name)
save('visual_assessment.json', {'reviewed_originals': [r['file'] for r in originals],
     'reviewed_browser_captures': ['review.png', 'registered.png'],
     'observations': ['Portrait and armed idle preserve headwrap, neat beard, cloth colors and adult human identity; no curved sword or ninja weapon in the candidates.',
                      'Four spear idle views show front SE/SW and authored rear NE/NW; selected rectangles retain full heads, boots and spear silhouettes.',
                      'Registered preview uses one common scale and manually chosen two-boot midpoint per direction; no bounding-box size normalization.',
                      'Portrait face is clearer than old torso-heavy region at 64px; 32px does not support fine facial-detail acceptance.'],
     'limits': ['idle_v1 and idle_v2 nominal equal-cell raw-alpha boundary checks remain unaccepted.',
                'idle_v2 is a spatial sampling candidate, not a perfectly clean whole atlas; 408 omitted isolated source pixels have alpha1, original file unchanged.',
                'Manual boot points retain about 10-source-pixel uncertainty; this does not prove physical floor contact.',
                'Rear spear shaft is occluded by torso/legs; its full motion/length and grip require subsequent action-chain checks.',
                'No Godot import, ordinary Unit, rescued/bound regression, HUD, codex, animation, package or performance acceptance.'],
     'production_adopted': False, 'native_accepted': False})
defs = R / 'scripts/defs.gd'
ability_lines = [{'line': i+1, 'text': line.strip()} for i, line in enumerate(defs.read_text(encoding='utf-8').splitlines())
                 if any('"yang_lin_'+suffix+'"' in line for suffix in ['q', 'w', 'e', 'r']) and '"name"' in line]
assert len(ability_lines) == 5  # hero definition plus four ability definitions
save('skill_review_pending.json', {'source': 'scripts/defs.gd', 'source_sha256': sha(defs), 'lines': ability_lines,
     'finding': 'Current names/descriptions include shuriken, concealment/blink and hunt/haste motifs. Chapter44 weapon/appearance evidence does not establish these. Cross-chapter review is still required; this source batch neither approves nor changes them.',
     'skill_canon_accepted': False, 'changed': False})
groups = {}
for name, manifest in [('runtime129', 'qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json'),
                       ('protected16', 'qa/tribute_cart_wheel_unit_20261018/protected_next.json'),
                       ('foreign81', 'qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json')]:
    rows = json.loads((R/manifest).read_text(encoding='utf-8'))
    for row in rows:
        assert sha(R/row['path']) == row['sha256'], row['path']
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
save('python_syntax.json', {'parsed': sorted(parsed), 'scope': 'Python AST only; not native or Godot syntax acceptance.'})
print(json.dumps({'originals': len(originals), 'browser_frames': 2, 'preserved': groups,
                  'native_accepted': False, 'production_adopted': False}))
