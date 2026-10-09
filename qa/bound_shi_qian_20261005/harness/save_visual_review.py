"""Record the root reviewer's direct inspection of the eight final native screenshots."""
from pathlib import Path
from PIL import Image
import json,hashlib
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
run=base/'20261005_114753_cd5cab75'
r=json.loads((run/'evidence/bound_shi_qian/report.json').read_text(encoding='utf-8'))
assert r['passed'] and r['checks']==116 and len(r['screenshots'])==8
rows=[]
for row in r['screenshots']:
 p=Path(row['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']
 bound=row['name'].startswith('shi_bound_current_')
 note=('Directly viewed final original current RTS actor: masked black headwrap, charcoal cloth, front bound wrists and empty hands, no sack or extra programmatic rope; rear wrists naturally occluded. Existing Qin bound body now visibly rendered with red scarf/robe and front rope, no white rectangle.' if bound else 'Directly viewed final original rescued actor: existing masked dark-cloth walk strip and brown sack, existing facing/mirroring rules retained. This is not authored generic four-direction walking.')
 item=row|{'passed':True,'review':note+' The other four programmatic bodies remain armed historical visuals; their art is still pending. Same actor and noncombat state established by runtime assertions. Screenshot FPS/first prepared HUD is not performance qualification.'}
 if bound:
  im=Image.open(p).convert('RGB');white=sum(1 for y in range(250,800) for x in range(400,1100) if min(im.getpixel((x,y)))>0.99*255)
  assert white<500;item['white_pixels_same_scene_region']=white
 rows.append(item)
v={'complete':True,'passed':True,'method':'Direct view_image inspection of every full final native render by primary agent; PNGs unmodified. Additional read-only white-pixel measurements authenticate the regression.', 'run':str(run),'screenshots':rows,'limits':['Only current original bound Shi Qian idle authored, walk/hurt standing fallback; not full art scope.','Normal timed rescue and local movement with rescuer contact-position/nonparticipant/pose fixtures; not full chapter or cross-process continue.','Shared engine naturally waited; no other-task messaging or process control.','First engine-passing run rejected for Qin white block, retained in failed evidence.']}
(repo/'qa/bound_shi_qian_20261005/visual_review.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'reviewed':8,'final_white_counts':[x['white_pixels_same_scene_region'] for x in rows if 'white_pixels_same_scene_region' in x]}))
