"""Record independent replay without rewriting first-run receipts."""
from pathlib import Path
import ast, hashlib, json, shutil
Q = Path(__file__).resolve().parent
E = Path('D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
archive = Q / 'first_executed_tools'
archive.mkdir()
tools = []
for name in ['render_review.py', 'render_registered.py']:
    source = E / 'executed_tools_v1' / name
    shutil.copyfile(source, archive / name)
    assert sha(source) == sha(archive/name)
    tools.append({'file': 'first_executed_tools/'+name, 'sha256': sha(source)})
rows = []
for label, subdir, png, svg, receipt_name in [
        ('source_review', 'review_replay', 'review.png', 'review.svg', 'browser_receipt.json'),
        ('registered_review', 'registered_replay', 'registered.png', 'registered.svg', 'registration.json')]:
    output = E / subdir
    receipt = json.loads((output/receipt_name).read_text(encoding='utf-8'))
    helper = 'render_review.py' if label == 'source_review' else 'render_registered.py'
    assert receipt['executed_helper_sha256'] == sha(Q/helper)
    assert sha(output/png) == sha(Q/png) == receipt['png_sha256']
    assert sha(output/svg) == sha(Q/svg) == receipt['svg_sha256']
    archived_receipt = Q / (label+'_replay_receipt.json')
    assert not archived_receipt.exists()
    shutil.copyfile(output/receipt_name, archived_receipt)
    rows.append({'case': label, 'png_byte_identical_to_first_capture': True,
                 'svg_byte_identical_to_first_capture': True,
                 'png_sha256': sha(output/png), 'svg_sha256': sha(output/svg),
                 'current_helper': helper, 'current_helper_sha256': sha(Q/helper),
                 'receipt': archived_receipt.name})
syntax = []
for path in Q.rglob('*.py'):
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
    syntax.append({'file': path.relative_to(Q).as_posix(), 'sha256': sha(path)})
with (Q/'replay_verification.json').open('x', encoding='utf-8') as stream:
    stream.write(json.dumps({'scope': 'Independent browser replay only, not native/UI or game qualification.',
                'first_executed_tools_archived': tools, 'replays': rows, 'python_ast_current': syntax,
                'production_adopted': False, 'native_accepted': False}, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({'replays': len(rows), 'png_byte_identical': True, 'svg_byte_identical': True,
                  'python_ast_files': len(syntax), 'native_accepted': False}))
