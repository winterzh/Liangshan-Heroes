"""Preserve one targeted native edit request after the NE support review."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
ref=ROOT/'assets/characters/wang_ying_wounded_20261005/walk_a_ne_v4.png'
j=json.loads((HERE/'jobs/wang_ying_walk_a_ne_v4.json').read_text(encoding='utf-8'))
assert hashlib.sha256(ref.read_bytes()).hexdigest()==j['output_sha256']
prompt='''Edit ONLY the two legs/boots and necessary lowest tunic overlap of this ONE NE/back-right Wang Ying walking sprite. Preserve exact mature short broad stocky adult body, upright head/back, face profile, torso/shoulder width, brown riveted armor, round belt studs, red tunic/headband, tied hair, empty hands, grey trousers/wrapped boots, lighting and camera. Same NE direction: whole man faces away/up-right and both toes point up-right. Do not stretch his stature or change head/upper-body/materials.
The current image is a rejected contact-A pose: the image-right leg is ahead and the image-left leg is stretched behind. SWAP that gait below the hip while preserving each leg attachment. Anatomical LEFT leg (emerging from image-left hip) must step FORWARD and carry weight on a FLAT planted boot. Bend that knee mildly forward, move its boot toward up-right from its old bottom-left position; on this1254canvas approximately x620,y1040. Anatomical RIGHT leg (image-right hip) must trail BACK, knee naturally relaxed, its heel raised a little with ONLY THE TOE STILL TOUCHING ground, approximately x720,y1160. Do not leave either foot fully floating. Preserve short adult thigh/calf lengths. Two separate natural legs, no twisting/crossed hips, no high kick/large lunge/oversized feet. This is a compact quiet walking CONTACT A step, not passing/running/jumping.
Redraw the leg pose natively; preserve everything above pelvis including his short stout identity. Exactly one full complete man centered on genuine transparent RGBA square<=1536, ample clear margins, both boots wholly contained, no floor/shadow/background/grid/text/rope/weapons or new accessories.'''
request={'transparent_background':True,'referenced_image_paths':[ref.as_posix()],'prompt':prompt}
p=HERE/'requests/wang_ying_walk_a2_ne_v4.json'
if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==request
else:p.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':p.relative_to(ROOT).as_posix(),'parent_sha256':j['output_sha256']}))
