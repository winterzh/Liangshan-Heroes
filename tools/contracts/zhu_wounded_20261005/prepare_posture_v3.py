"""Read-only reference audit and v3 idle authoring metadata; never edit PNGs."""
from pathlib import Path
import hashlib, json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
if (ROOT/'qa/zhu_wounded_20261005/user_character_traits_review_v4.json').exists():
    raise RuntimeError('Uniform soldier v3 authoring superseded by character_posture_profiles_v4.json; preserve historical requests and use individual posture profiles.')
KEYS = ('shi_qian', 'shi_xiu', 'qin_ming', 'yang_lin', 'huang_xin', 'wang_ying', 'deng_fei')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

identity = json.loads((HERE/'authoring.json').read_text(encoding='utf-8'))['characters']
records, checks = {}, []
for key in KEYS:
    jp = HERE/'jobs'/f'{key}_posture_v3.json'
    job = json.loads(jp.read_text(encoding='utf-8'))
    raw = ROOT/job['output']
    rp = ROOT/job['request']
    args = json.loads(rp.read_text(encoding='utf-8'))
    assert sha(raw) == job['output_sha256'] and sha(rp) == job['request_sha256']
    assert len(args['referenced_image_paths']) == len(job['references'])
    for archived_path, ref in zip(args['referenced_image_paths'],job['references']):
        assert archived_path.replace('\\','/').lower().endswith('/'+ref['path'].lower())
    for ref in job['references']:
        assert sha(ROOT/ref['path']) == ref['sha256']
    with Image.open(raw) as image:
        assert image.mode == 'RGBA' and list(image.size) == job['native_size'] and max(image.size) <= 1536
        alpha = image.getchannel('A')
        bbox = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
        assert bbox and alpha.getextrema()[0] == 0
        clearance = min(bbox[0], bbox[1], image.width-bbox[2], image.height-bbox[3])
        assert clearance >= 4
        zero_fraction = alpha.histogram()[0]/(image.width*image.height)
    checks.append({'character': key, 'path': job['output'], 'sha256': job['output_sha256'],
                   'native_size': job['native_size'], 'clearance_px': clearance,
                   'alpha_zero_fraction': zero_fraction, 'byte_request_parent_checks_passed': True})
    prompt = (
        'Use case: identity-preserve. Create native FOUR independently drawn isometric IDLE views of this SAME upright adult soldier. '
        'Reference is the selected v3 single-body posture; preserve its face, proportions, clothing and colors. '
        'Exactly 2 columns x 2 rows: TOP LEFT SE front three-quarter looking screen DOWN-RIGHT; '
        'TOP RIGHT SW front three-quarter looking screen DOWN-LEFT; BOTTOM LEFT NE back three-quarter looking screen UP-RIGHT; '
        'BOTTOM RIGHT NW back three-quarter looking screen UP-LEFT. Turn the WHOLE torso, hips and both feet into each direction. '
        'SE and SW must be genuinely opposite whole-body views; do not repeat SW in the SE cell. '
        'Back views show back clothes and back of head, with only a small far cheek visible. Never mirror a rendered cell. '
        'ALL FOUR poses stand dignified and upright like disciplined soldiers: lifted head, LEVEL chin/horizon gaze, '
        'neck vertically above torso, stacked natural spine, shoulders back/down, naturally open lifted chest. '
        'Elevated camera never means bowed head. NO hunch, forward neck, closed chest, tired shoulder slump, '
        'shrug, belly thrust or arched lower back. Empty relaxed hands and naturally straight arms at sides. '
        'Stable feet at modest hip width, straight natural knees. Keep mature adult head/hands/boots and adult leg lengths. '
        'Body type identity: ' + identity[key]['identity'] + ' '
        'Preserve v3 body anatomy over any old compact sprite instructions; never chibi. '
        'Same front/back clothing hem length and construction, no weapons/sheaths/rope/chains/blood/new props. '
        'Each whole figure fits inside its OWN quadrant with wide true-alpha outer margins and wide empty transparent central gutters; '
        'no tails/capes/boots cross cell boundaries. Figures equal body height within this character. '
        'Native square max1536, painterly reference quality, TRUE RGBA transparent background; '
        'no floor/shadows/text/labels/grid/checkerboard.'
    )
    if key != 'shi_xiu':
        prompt += (' Layout priority: figures occupy only 78–82% of EACH quadrant height, '
                   'about490–515px tall at1254px native square. Center each figure inside its cell; '
                   'keep at least45px transparent clearance on every cell edge, including cape/boots/headcloth. '
                   'The central horizontal gutter should be at least80px. Reduce whole figure size uniformly '
                   'to leave room; NEVER shorten legs or enlarge heads to fit. Do not nearly touch the two rows.')
    idle_args = {'prompt': prompt, 'referenced_image_paths': [raw.as_posix()], 'transparent_background': True}
    idle_request = HERE/'requests'/f'{key}_idle_v3.json'
    if idle_request.exists() and (HERE/'jobs'/f'{key}_idle_v3.json').exists():
        archived = json.loads(idle_request.read_text(encoding='utf-8'))
        assert archived['prompt'] == prompt and archived['transparent_background'] is True, 'Use a new request name after changing a generated request.'
        assert len(archived['referenced_image_paths'])==1 and archived['referenced_image_paths'][0].replace('\\','/').lower().endswith('/'+job['output'].lower())
    else:
        write(idle_request, idle_args)
    records[key] = {'identity': identity[key]['identity'], 'reference_job': jp.relative_to(ROOT).as_posix(),
                    'reference_path': job['output'], 'reference_sha256': job['output_sha256'],
                    'reference_visual_review': 'directly viewed single SW posture; head lifted/chest open direction accepted for authoring only',
                    'idle_request': idle_request.relative_to(ROOT).as_posix(),
                    'four_direction_qualified': False, 'continuous_gait_qualified': False,
                    'actual_campaign_qualified': False, 'production_qualified': False}
write(HERE/'authoring_v3.json', {'schema': 1, 'baseline': '27f45b245e2b39f1f779fbfa62772e14bb68dd56',
      'revision': 'upright_soldier_v3', 'scope': 'All seven rescued unarmed idle/walk; standing references are not runtime sprites.',
      'posture': 'Head lifted/level chin/horizon gaze; vertical neck, stacked spine, shoulders back/down, chest naturally open; no hunch or fatigue slump.',
      'supersedes': 'All v2 posture qualifications and all old fatigue/slump prompt guidance; raw ancestry retained.',
      'walk_requirements': ['same upright torso through all phases and four directions', 'opposite support/trailing feet with natural short strides',
                            'consistent face/body size/clothes hem/foot anchors', 'continuous gait, start/stop and turning reviewed in actual runtime'],
      'characters': records, 'production_qualified': False})
write(ROOT/'qa/zhu_wounded_20261005/posture_reference_audit_v3.json', {'schema': 1, 'passed': True,
      'scope': 'Seven native reference byte/request/immediate-parent identities, RGBA/native dimensions/clearance only; no anatomy metric, engine import or gameplay acceptance.',
      'native_pixel_edits': False, 'checks': checks, 'production_qualified': False})
print(json.dumps({'reference_count': len(checks), 'passed': True, 'idle_requests': len(records), 'runtime_qualified': False}))
