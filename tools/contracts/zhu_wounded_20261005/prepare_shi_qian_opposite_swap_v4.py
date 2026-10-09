"""Persist a direct four-cell support reversal after the multi-reference B failure."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
path='assets/characters/shi_qian_wounded_20261005/walk_a_spacing_atlas_v4.png'
j=json.loads((HERE/'jobs/shi_qian_walk_a_spacing_atlas_v4.json').read_text(encoding='utf-8'))
assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==j['output_sha256']
prompt='''Edit this native correctly spaced FOUR-CELL Shi Qian walking A sheet to create OPPOSING WALK B. Change ONLY legs below hip and minimal following lower tunic fabric, preserving every figure's exact face/mask/headcloth, slim adult proportions, shoulder/body width, charcoal subtle cloth pattern/layers, tan sash, diagonal shin wraps, ordinary cloth boots, lighting and elevated isometric camera. Keep soft knees, modest functional hip lean, searching level eyes and close empty hands; not military parade or rounded elderly hump.
MANDATORY FOUR DIFFERENT SUPPORT REVERSALS:
TOP-LEFT SE: currently image-RIGHT foreground boot planted and image-LEFT boot raised behind. SWAP: image-LEFT boot must now be FLAT planted carrying weight at lower-left, image-RIGHT boot raised a little behind at upper-right. Both toes still down-RIGHT.
TOP-RIGHT SW: currently image-LEFT foreground boot planted, image-RIGHT rear boot raised. SWAP: image-RIGHT foreground boot FLAT planted at lower-right, image-LEFT rear boot raised modestly at upper-left. Both toes down-LEFT.
BOTTOM-LEFT NE: currently lower image-LEFT rear boot planted and upper image-RIGHT boot raised. SWAP: image-RIGHT foreground boot FLAT planted at lower-right, image-LEFT boot bent behind and modestly raised at upper-left. Both toes up-RIGHT, torso/head still AWAY-right.
BOTTOM-RIGHT NW: currently image-LEFT boot planted, image-RIGHT boot raised behind. SWAP: image-RIGHT boot FLAT planted at lower-right, image-LEFT rear boot modestly raised at upper-left. Both toes up-LEFT, torso/head AWAY-left.
Each leg stays attached to its OWN hip. These support reversals are essential; do not retain A's grounded legs. Compact light natural short step, no wide lunge, high knee, huge sole/kick, crossed hips or figure mirroring. Preserve anatomical slim adult leg lengths.
KEEP THIS EXACT SPACING:1254square transparent RGBA, four627square cells, each WHOLE figure about450–470pixels tall with at least60–80px clear margin. Top bodies wholly within y80..550, bottom within y710..1180, no toe/cloth/hand across x627 or y627. Keep four same figure centers/layout/camera and proportions. No extra person, added grid/text/labels/background/floor/shadow, weapon/rope/sack/armor/new prop. Exactly4 complete newly opposed Shi Qian figures.'''
req={'transparent_background':True,'referenced_image_paths':[(ROOT/path).as_posix()],'prompt':prompt}
dest=HERE/'requests/shi_qian_walk_b_swap_atlas_v4.json'
if dest.exists():assert json.loads(dest.read_text(encoding='utf-8'))==req
else:dest.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':dest.relative_to(ROOT).as_posix(),'target_source_sha256':j['output_sha256']}))
