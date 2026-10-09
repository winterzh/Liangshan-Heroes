"""Record reviewed eight native Deng Fei poses only; runtime qualification pending."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def persist(p,v):
    if p.exists():assert read(p)==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
jobs=[];checks=[];prompts=[]
for state in ('idle_single','walk_a'):
    for d in ('se','sw','ne','nw'):
        j=read(HERE/f'jobs/deng_fei_{state}_{d}_v4.json');p=ROOT/j['output'];req=ROOT/j['request']
        assert sha(p)==j['output_sha256'] and sha(req)==j['request_sha256']
        for ref in j['references']:assert sha(ROOT/ref['path'])==ref['sha256']
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.size==(1254,1254)
            a=im.getchannel('A');box=a.point(lambda v:255 if v>16 else 0).getbbox();assert box and min(box[0],box[1],1254-box[2],1254-box[3])>=4
        jobs.append(j);checks.append({'state':state,'direction':d,'path':j['output'],'sha256':j['output_sha256'],'native_size':[1254,1254],'bounds':box,'passed':True})
        prompts.append({'path':j['output'],'sha256':j['output_sha256'],'request':j['request'],'request_sha256':j['request_sha256'],'exact_args':read(req)})
persist(QA/'deng_fei_contact_a_native_review_v4.json',{'scope':'Four idle and four contact A sources directly viewed; not complete gait or runtime acceptance',
    'native_sources':8,'checks':checks,'observations':['Rugged mature adult stance and natural upper back preserved','SE contact A image-right support, SW/NE/NW image-left support directly reviewed','Curly hair/beard, brass/brown armor, rust sash and ragged scarf remain identifiable'],
    'remaining':['Contact B and eight passing sources','Independent native Godot import, full clock, actual Unit','Foot/cloth continuous transitions, original campaign/production/UI'],
    'production_qualified':False})
persist(QA/'deng_fei_native_partial_prompt_set_v4.json',{'method':'built-in image_gen','native_pixel_edits':False,'native_sources':8,'requests':prompts,'production_qualified':False})
print('8 native Deng Fei poses/requests/parents checked and retained; complete gait and runtime pending')
