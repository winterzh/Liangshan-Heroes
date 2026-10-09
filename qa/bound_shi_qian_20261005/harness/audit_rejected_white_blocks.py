from pathlib import Path
from PIL import Image
import hashlib,json
base=Path(__file__).parent;repo=Path('E:/ChatGPT/水浒')
rows=[]
for p in sorted((base/'20261005_113221_50bc6117/evidence/bound_shi_qian').glob('shi_bound_current_*.png')):
 im=Image.open(p).convert('RGB')
 count=sum(1 for y in range(250,800) for x in range(400,1100) if min(im.getpixel((x,y)))>0.99*255)
 assert count>=500
 rows.append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'white_pixels':count,'new_guard_would_reject':True})
assert len(rows)==4
(repo/'qa/bound_shi_qian_20261005/white_block_negative_control.json').write_text(json.dumps({'complete':True,'passed':True,'method':'Read-only original PNG pixel count; same fixed viewport rectangle/threshold as new Godot guard. No image editing.','threshold':500,'region':[400,250,1100,800],'screenshots':rows},indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows))
