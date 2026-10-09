"""Derive native candidate sampling/lineage; never edit PNG pixels."""
from pathlib import Path
import hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
if (ROOT/'qa/zhu_wounded_20261005/user_posture_review_v3.json').exists():
    raise SystemExit('v2 posture superseded by upright soldier v3; preserve historical evidence, do not rebuild/promote v2 candidates.')
DIRS=('se','sw','ne','nw')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def cuts(a):
    w,h=a.size;bands=[]
    for x in range(int(w*.43),int(w*.57)):
        if sum(a.crop((x,0,x+1,h)).histogram()[16:])==0:
            if not bands or x>bands[-1][-1]+1:bands.append([x])
            else:bands[-1].append(x)
    bands=[b for b in bands if len(b)>=4];assert bands,'No safe native gutter'
    b=min(bands,key=lambda b:abs((b[0]+b[-1])/2-w*.5))
    return [0,(b[0]+b[-1])//2,w]
sel=json.loads((HERE/'selection_v2.json').read_text(encoding='utf-8'))
rejected={r['sha256'] for r in json.loads((ROOT/'qa/zhu_wounded_20261005/user_proportion_review.json').read_text(encoding='utf-8'))['rejected_candidates']}
rejected.update(sha(ROOT/'assets/characters/shi_qian_wounded_20261005'/p) for p in ['walk_v2.png','se_v2.png','sw_b_v2.png','sw_b3_v2.png'])
records={}
for path in sorted((HERE/'jobs').glob('*.json')):
    j=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(j,dict):continue
    output=j.get('output',j.get('repository_input'))
    if output:records[output]=(path.stem,j)
original='assets/characters/shi_qian_bound_20261005/bound.png';graph={}
def add_job(path):
    if path==original:return 'original'
    key,j=records[path]
    if key in graph:return key
    native_sha=j.get('output_sha256',j.get('sha256'));assert sha(ROOT/path)==native_sha
    request=j.get('request',j.get('request_file'))
    rp=ROOT/request if request.startswith('tools/') else HERE/request
    assert sha(rp)==j['request_sha256']
    args=json.loads(rp.read_text(encoding='utf-8'))
    refs=[add_job(Path(p).relative_to(ROOT).as_posix()) for p in args.get('referenced_image_paths',[])]
    graph[key]={'key':key,'method':'built_in_imagegen','generation_id':j['generation_id'],'repository_path':path,'sha256':native_sha,'prompt':args['prompt'],'request':rp.relative_to(ROOT).as_posix(),'request_sha256':sha(rp),'references':refs,'transparent_background':args['transparent_background'],'selected':key in sel['sources'].values(),'native_pixel_edits':False}
    return key
sources={};masks={};regions={}
for name,jobkey in sel['sources'].items():
    path,j=next((p,j) for p,(k,j) in records.items() if k==jobkey)
    assert sha(ROOT/path) not in rejected,'Rejected anatomy/gait cannot be selected'
    im=Image.open(ROOT/path);assert im.mode=='RGBA' and max(im.size)<=1536
    a=im.getchannel('A');masks[name]=a
    if name=='idle':
        xs=cuts(a);ys=cuts(a.transpose(Image.Transpose.TRANSPOSE))
        rs=[[xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]] for y in range(2) for x in range(2)]
    else:rs=[[0,0,*im.size]]
    regions[name]=rs
    sources[name]={'path':path,'sha256':sha(ROOT/path),'job':add_job(path),'mode':'RGBA','native_size':list(im.size),'imported_size':list(im.size),'import_limit':1536,'import_dimension_status':'expected until independent Godot dimension receipt','full_atlas':True,'alpha_zero_fraction':a.histogram()[0]/(im.width*im.height)}
    if name=='idle':
        sources[name]['unused_regions']=[{'region':rs[i],'reason':'Rear idle tunic hem mismatches walk; replaced by independently redrawn adult idle view'} for i in [2,3]]
        sources[name]['full_atlas']=False
    desc=Path(str(ROOT/path)+'.import')
    if not desc.exists():
        old_md5=hashlib.md5(('res://'+original).encode()).hexdigest();new_md5=hashlib.md5(('res://'+path).encode()).hexdigest()
        text=Path(str(ROOT/original)+'.import').read_text(encoding='utf-8')
        text=re.sub(r'^uid=.*\n','',text,flags=re.M).replace(original,path).replace('bound.png-'+old_md5,Path(path).name+'-'+new_md5)
        desc.write_text(text,encoding='utf-8',newline='\n')
manifest={'schema':'native_direction4_spriteframes_v1','character':'zhu_wounded_shi_qian','sources':sources,'states':sel['states'],'poses':{},'resources':[],'scope':sel['scope'],'production_qualified':False};checks=[]
for row,direction in enumerate(DIRS):
    for pose in ['idle','walk_a','walk_b']:
        source=('idle_'+direction if 'idle_'+direction in sources else 'idle') if pose=='idle' else pose+'_'+direction
        region=regions[source][row] if source=='idle' else regions[source][0]
        x,y,w,h=region;a=masks[source].crop((x,y,x+w,y+h));bbox=a.point(lambda v:255 if v>16 else 0).getbbox();assert bbox
        left,top,right,bottom=bbox;clearance=min(left,top,w-right,h-bottom);assert clearance>=4
        virtual=max(w,h);padx=(virtual-w)//2;pady=(virtual-h)//2
        feet=a.crop((0,bottom-int((bottom-top)*.23),w,bottom)).point(lambda v:255 if v>16 else 0).getbbox();assert feet
        pivot=[(feet[0]+feet[2])/2,bottom-4]
        manifest['poses'][pose+'_'+direction]={'source':source,'region_raw':region,'region':region,'margin':[padx,pady,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,'draw_offset_px':[virtual*.5-(padx+pivot[0]),virtual*.82-(pady+pivot[1])],'draw_scale':round(virtual*.78/(bottom-top),6)}
        checks.append({'pose':pose+'_'+direction,'bounds':list(bbox),'clearance_px':clearance,'passed':True,'foot_anchor':'Initial lower-silhouette contact estimate, pending continuous/runtime correction'})
    for state in sel['states']:manifest['resources'].append(f'assets/anim/zhu_wounded_shi_qian_{state}_{direction}.tres')
write(ROOT/'assets/direction4/zhu_wounded_shi_qian_20261005.json',manifest)
write(HERE/'generation_v2.json',{'original_reference':{'path':original,'sha256':sha(ROOT/original)},'jobs':list(graph.values()),'scope':'Required rejected older parent chain retained for the redrawn adult proportion reference; old pixels are not selected.'})
write(ROOT/'qa/zhu_wounded_20261005/shi_qian_bounds_v2.json',{'passed':True,'native_pixel_edits':False,'checks':checks,'scope':'Native sampling/clearance only, no anatomy measurement or runtime acceptance'})
print(json.dumps({'sources':len(sources),'unique_poses':len(checks),'resources':8,'production_qualified':False,'native_pixel_edits':False}))
