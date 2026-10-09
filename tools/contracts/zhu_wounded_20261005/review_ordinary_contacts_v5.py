"""Verify byte-preserved candidate inputs; record the limits of static visual review."""
from pathlib import Path
import hashlib, json
from PIL import Image
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'qa/zhu_wounded_20261005/ordinary_contacts_static_review_v5.json'
assert not OUT.exists()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
rows = []
for key, state, selected in [
    ('wu_song', 'walk_a_se', True), ('wu_song', 'walk_b_se', True),
    ('lin_chong', 'walk_a_se', True), ('lin_chong', 'walk_b_se', False),
    ('lin_chong', 'walk_b_se2', True),
]:
    jp = HERE / 'jobs' / f'{key}_{state}_v5.json'
    j = json.loads(jp.read_text(encoding='utf-8'))
    p = ROOT / j['output']; request = ROOT / j['request']
    assert sha(p) == j['output_sha256'] and sha(request) == j['request_sha256']
    for ref in j['references']:
        assert sha(ROOT / ref['path']) == ref['sha256']
        if 'parent_job' in ref:
            assert sha(ROOT / ref['parent_job']) == ref['parent_job_sha256']
        for evidence in ref.get('geometry_only_parent_evidence', []):
            assert sha(ROOT / evidence['manifest']) == evidence['manifest_sha256']
            for artifact in evidence['generator_artifacts']:
                assert sha(ROOT / artifact['path']) == artifact['sha256']
    with Image.open(p) as im:
        assert im.mode == 'RGBA' and list(im.size) == j['native_size']
        a = im.getchannel('A'); bounds = a.point(lambda v: 255 if v > 16 else 0).getbbox()
        assert list(bounds) == j['alpha_bounds'] and a.getextrema()[0] == 0
        clear = a.histogram()[0] / (im.width * im.height)
        assert clear > .35 and 0 < bounds[0] < bounds[2] < im.width and 0 < bounds[1] < bounds[3] < im.height
        margins = [bounds[0], bounds[1], im.width-bounds[2], im.height-bounds[3]]
    rows.append({'key':key, 'state':state, 'job':jp.relative_to(ROOT).as_posix(),
                 'job_sha256':sha(jp), 'path':j['output'], 'sha256':sha(p),
                 'candidate_selected':selected, 'transparent_fraction':clear,
                 'native_clear_margins':margins, 'not_clipped':True})
value = {
    'scope':'Read-only native bytes/alpha/request/reference validation plus direct static image inspection; no engine import or animation acceptance.',
    'passed':True, 'files':rows, 'method':'built-in image_gen; no local raster edits',
    'visual_observations':[
        'Wu Song A/B show upright mature upper body, low twin-dao carry and opposing leg support; identity/clothing remain recognizable.',
        'Lin Chong A shows upright disciplined upper body with one low diagonal spear.',
        'Lin Chong first B is rejected: image-right leg still supports, duplicating A instead of exchanging support.',
        'Lin Chong B2 exchanges the support visibly: image-left planted, image-right recovery. Upper-body/armor/spear continuity and scale still need motion comparison.',
        'Generated clear margins do not all meet requested100px; minimum58px remains transparent with no clipping. Final sampling/pivot/scale not authored yet.',
    ],
    'rejected':['assets/characters/lin_chong_traits_20261006/walk_b_se_v5.png'],
    'remaining':['other three headings', 'two passing phases per heading', 'native imports and frame resources',
                 'actual idle/start/stop/reverse comparison', 'original chapter/weapon/combat/UI verification'],
    'runtime_qualified':False, 'production_qualified':False, 'continuous_gait_qualified':False,
}
OUT.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
print(json.dumps({'passed':True,'native_files':len(rows),'selected_static_candidates':4,'rejected':1,'production_qualified':False}))
