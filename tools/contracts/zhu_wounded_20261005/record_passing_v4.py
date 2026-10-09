"""Preserve twenty native poses and rendered frames; visual acceptance is separate."""
from pathlib import Path
import hashlib, json, shutil, sys
ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src, dst):
    if dst.exists(): assert sha(src) == sha(dst)
    else: shutil.copyfile(src, dst)
imp_run, preview_run = map(Path, sys.argv[1:3])
variant = sys.argv[3] if len(sys.argv)>3 else 'passing'
assert variant in ('passing','refined','footclear')
slot=variant+'_v4'
imp, r = read(imp_run/'receipt.json'), read(preview_run/'receipt.json')
m = read(ROOT/f'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_{slot}.json')
assert m['states'] == {'idle':['idle'], 'walk':['walk_a','passing_a','walk_b','passing_b']}
assert len(m['sources']) == len(m['poses']) == 20 and not m['production_qualified']
assert imp['complete'] and imp['dimensions']['passed'] and imp['lock_released']
assert len(imp['dimensions']['checks']) == 20
for row in imp['source_files']:
    if row['path'].endswith('.png'):
        assert sha(ROOT/row['path']) == row['before_sha256'] == row['after_sha256']
assert r['complete'] and r['lock_released'] and r['input_sha_drift'] == 0
assert len(r['inputs']) == 50 and len(r['captures']) == 64 and len(r['preview']['seen']) == 20
for row in r['inputs']:
    assert sha(ROOT/row['path']) == row['sha256'] == sha(preview_run/'project'/row['path'])
for row in r['captures']: assert sha(preview_run/'project'/row['path']) == row['sha256']
sources = read(QA/f'shi_xiu_walk_sources_{slot}.json')
assert sources['passed'] and all(c['passed'] for c in sources['checks'])
matrix = preview_run/'project/walk_matrix_v3.png'
assert sha(matrix) == r['matrix_sha256']
preserve(imp_run/'receipt.json', QA/f'shi_xiu_walk_texture_{slot}.json')
preserve(preview_run/'receipt.json', QA/f'shi_xiu_walk_cycle_{slot}.json')
preserve(matrix, QA/f'shi_xiu_walk_cycle_{slot}.png')
phases = [next(c for c in r['preview']['captures'] if c['moving'] and c['indexes'][0] == p) for p in range(4)]
review = {
    'schema':1, 'result':'twenty_native_poses_rendered_gait_not_qualified',
    'review':'Direct 20-pose native matrix and actual captured phases 0/1/2/3 viewed',
    'matrix_sha256':sha(matrix), 'phase_rows':phases,
    'improvements':['Four full-canvas idle views match the contact-body material template',
                    'Eight separately authored passing views replace reused stationary idle',
                    'SW/NE wrong-support first versions preserved and replaced by explicit opposite support candidates'],
    'remaining':['SW passing B lifted foot still appears extended and stiff',
                 'NE passing B swing-foot height and continuity need movement review',
                 'Actual Unit movement, secondary motion, anchors and original campaign still pending'],
    'limits':['Discrete recorded phases were viewed; no continuous browser playback acceptance',
              'Isolated SpriteFrames process-clock/start/stop renderer; not actual Unit physics or campaign'],
    'continuous_gait_qualified':False, 'production_qualified':False,
}
if variant in ('refined','footclear'):
    review['improvements'].append('SW/NE B passing amplitude lowered in separate native edits')
    review['remaining']=['SW passing B support/swing reading remains ambiguous at this lower lift',
                         'Actual Unit recheck of revised frames and continuous foot/cloth transition review pending',
                         'Original campaign and production routing remain unqualified']
if variant=='footclear':
    review['improvements'].append('SW B5 foreground swing tucked and visibly raised; rear support boot flat. B4 wrong support retained as rejected sibling.')
    review['remaining']=['Actual Unit recheck of SW B5 and continuous foot/cloth transition acceptance pending',
                         'Original campaign, other six gait sets and production routing remain unqualified']
unit_receipt=QA/f'shi_xiu_unit_motion_{variant}_v4.json'
if unit_receipt.exists():
    unit=read(unit_receipt)
    assert unit['complete'] and unit['lock_released'] and unit['input_sha_drift']==0
    review['unit_fixture_receipt']={'path':unit_receipt.relative_to(ROOT).as_posix(),
                                    'sha256':sha(unit_receipt),'functional_checks':len(unit['result']['checks'])}
    review['remaining']=[s for s in review['remaining'] if 'Actual Unit' not in s]
    review['remaining'].append('Detached Unit functional check passed; continuous foot/cloth acceptance and original campaign still required')
(QA/f'shi_xiu_walk_{variant}_review_v4.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True, 'source_checks':len(sources['checks']), 'inputs':len(r['inputs']), 'input_drift':0, 'production_qualified':False}))
