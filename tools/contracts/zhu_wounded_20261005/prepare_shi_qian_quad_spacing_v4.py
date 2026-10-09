"""Persist native full-figure spacing edits; never crop or resize image pixels locally."""
from pathlib import Path
import argparse,json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('phase',choices=('walk_a','passing_a','walk_b','passing_b'))
args=parser.parse_args();phase=args.phase
j=json.loads((HERE/f'jobs/shi_qian_{phase}_traits_atlas_v4.json').read_text(encoding='utf-8'))
p=ROOT/j['output'];assert hashlib.sha256(p.read_bytes()).hexdigest()==j['output_sha256']
prompt=f'''Edit this FOUR-FIGURE Shi Qian {phase.upper()} atlas only to give each complete figure MUCH MORE CLEAR CELL PADDING. Earlier boots crossed the horizontal cell seam; this output must not cross any seam. Keep the EXACT four identities, gait/support poses, black mask/headwrap, mature slim adult proportions, charcoal tunic/trousers with subtle textile and layering, plain tan sash, diagonal shin wraps, normal boots, light soft-kneed infiltrator bearing and empty near-body hands. No soldier-parade chest, elderly hump or deep squat. Do not change left/right support legs or direction.
NATIVE SPACING: redraw the same complete figures SMALLER and centered in their SAME four cells, keeping all internal body/head/limb proportions. Canvas remains1254x1254 square transparent RGBA. Each cell is627x627. Each WHOLE FIGURE INCLUDING headcloth tails, fingers and boots must be no taller than450–470pixels, about72–75% cell height. Use at least70–80pixels CLEAR margin on ALL four sides of each cell. TOP-LEFT and TOP-RIGHT figures wholly inside y80..550; BOTTOM figures wholly inside y710..1180. Top-left centered near x313,y313, top-right x940,y313, bottom-left x313,y940, bottom-right x940,y940. No figure or boot intrudes across x627 or y627. Each headcloth/hand/boot wholly contained inside its own cell.
Keep SE front-right in top-left, SW front-left in top-right, NE back-right in bottom-left and NW back-left in bottom-right, same painterly elevated isometric camera/light/palette. Native redraw to correct spacing, no added figure/grid/seam line/text/labels/background/floor/shadow/weapon/rope/sack/armor/prop. Exactly4 intact Shi Qian figures and genuine transparent alpha. Preserve the specific {phase} leg positions while expanding the clear gaps between complete silhouettes.'''
req={'transparent_background':True,'referenced_image_paths':[p.as_posix()],'prompt':prompt}
dest=HERE/f'requests/shi_qian_{phase}_spacing_atlas_v4.json'
if dest.exists():assert json.loads(dest.read_text(encoding='utf-8'))==req
else:dest.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':dest.relative_to(ROOT).as_posix(),'parent_sha256':j['output_sha256']}))
