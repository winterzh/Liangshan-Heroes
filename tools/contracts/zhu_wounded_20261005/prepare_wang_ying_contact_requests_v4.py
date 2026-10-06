"""Persist native short-stride contact A edits anchored to each Wang Ying idle."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
directions={'se':'FRONT-RIGHT / southeast, head and both boot toes point down-right',
    'sw':'FRONT-LEFT / southwest, head and both boot toes point down-left',
    'ne':'BACK-RIGHT / northeast, face away with visible right profile, both boot toes point up-right',
    'nw':'BACK-LEFT / northwest, face away with visible left profile, both boot toes point up-left'}
for d,heading in directions.items():
    ref=ROOT/f'assets/characters/wang_ying_wounded_20261005/idle_single_{d}_v4.png'
    job=json.loads((HERE/f'jobs/wang_ying_idle_single_{d}_v4.json').read_text(encoding='utf-8'))
    assert sha(ref)==job['output_sha256']
    prompt=f'''Use case: identity-preserve. Edit this ONE native full-body Wang Ying sprite into short natural walking CONTACT A phase. Input is the exact identity, body proportions, costume, rendering and {d.upper()} facing template.
Preserve this MATURE naturally SHORT, broad STOCKY adult; rough bearded face, headband/topknot, red tunic, brown brass-riveted armor/round-studded belt/bracers, grey trousers and wrapped boots. Keep the same head size, torso width, shoulder height, adult limb lengths, palette, camera and every garment layer. Upright grounded adult posture with slight natural walking motion, not taller, thinner, childlike, overarched parade stance or hunched. Empty hands naturally swing only a little.
Only change his quiet feet into a modest short walking step: anatomical LEFT leg steps FORWARD and its boot is planted flat carrying weight; anatomical RIGHT leg trails BACK with heel lifted and toe lightly contacting ground. Modest stride, both knees close to their natural body axis. No wide lunge, high knee, jumping, combat stance or kicked-up sole. Keep hip/upper-body centered above the support, natural pelvis rotation. Clearly distinguish the two legs and preserve their true attachment to the hip.
Whole head, torso, knees and both toes maintain {heading}, at the SAME elevated isometric viewing angle as reference. Exactly ONE complete person on genuine transparent RGBA square canvas, max1536, ample clear margin at every edge, entire cloth tails/fingers/boots contained. Same native painterly game detail. No rope, weapon, shadow, floor, grid, label, background, extra people or new accessories. CONTACT A is the first planted-foot pose; do not reuse neutral idle feet. Keep the frame suitable for later opposing contact B and two low passing phases. Always preserve short adult anatomy.'''
    request={'transparent_background':True,'referenced_image_paths':[ref.as_posix()],'prompt':prompt}
    p=HERE/f'requests/wang_ying_walk_a_{d}_v4.json'
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==request
    else:p.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'requests':4,'native_parent_hashes_verified':4}))
