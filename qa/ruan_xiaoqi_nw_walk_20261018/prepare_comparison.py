import copy, datetime, hashlib, json, pathlib, re, shutil, sys, uuid
import numpy as np
from PIL import Image

R=pathlib.Path('D:/AI项目/水浒/开发工程')
E=pathlib.Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import build_ruan_xiaoqi_layered_20261018 as layered

def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

base=load(R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json')
m=copy.deepcopy(base)
raw=load(R/'assets/characters/ruan_xiaoqi_nw_walk_20261018/prompt_set.json')
by_key={x['key']:x for x in raw['sources']}
new_points={'push_contact_b_nw':[414,531],'push_passing_b_nw':[412,532]}
changes=[]
for pose_key,source_key in [('push_contact_b_nw','contact_b_feet'),('push_passing_b_nw','passing_b')]:
    row=by_key[source_key];path=R/row['path'];assert sha(path)==row['sha256']
    with Image.open(path) as im:a=np.asarray(im)[:,:,3];size=list(im.size)
    yy,xx=np.nonzero(a>=64)
    assert yy.min()>0 and yy.max()<size[1]-1 and xx.min()>0 and xx.max()<size[0]-1
    old=base['poses'][pose_key];ratio=old['body_height_target']
    reference=(int(yy.max())+1-int(yy.min()))/ratio
    pivot=[old['pivot_native'][0],int(yy.max())+1]
    p=layered.canvas_pose([0,0,*size],pivot,reference,int(yy.min()))
    old_hand=old['hand_registration']['manual_source_grip_centres'][0]
    old_anchor=[(old_hand[i]-old['pivot_native'][i]+old['draw_offset_px'][i])/old['virtual_canvas_reference'] for i in range(2)]
    offset=[old_anchor[i]*reference-(new_points[pose_key][i]-pivot[i]) for i in range(2)]
    key=path.stem+'_'+row['sha256'][:8]
    p.update(source=key,independent_cart=True,body_height_target=ratio,draw_offset_px=offset,
        operations='Unchanged built-in generated PNG, original full region and alpha. Same authored body-height target, translation-only registration to the old approximate near grip. Cart unchanged. Not final gait/grounding/grip acceptance.',
        hand_registration={'manual_source_near_grip':new_points[pose_key],'old_normalized_near_grip_anchor':old_anchor,'method':'Approximate primary-agent landmark, translation only; far grip not claimed accepted.'})
    m['poses'][pose_key]=p
    m['sources'][key]={'path':row['path'],'candidate_origin':row['path'],'sha256':row['sha256'],'native_size':size,'imported_size':size,'selected_directions':['nw']}
    changes.append({'pose':pose_key,'before':old,'after':p,'source':row['path']})
used={p['source'] for p in m['poses'].values()}
m['sources']={k:v for k,v in m['sources'].items() if k in used}
assert len(m['sources'])==13
for k,v in base['poses'].items():
    if k not in new_points:assert m['poses'][k]==v,k
assert m['canonical_cart_geometry']==base['canonical_cart_geometry']
save(E/'candidate_manifest.json',m);save(E/'candidate_changes.json',changes)
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
P=E/'native_comparison'/stamp;P.mkdir(parents=True)
old=load(R/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json')
empty_resources={d:next(p for p in old['resources'] if p.endswith('_idle_'+d+'.tres')) for d in ['se','sw','ne','nw']}
textures={v['path']:v for v in m['sources'].values()};textures[old['sources']['idle_spacing']['path']]=old['sources']['idle_spacing']
for path in textures:
    dest=P/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/path,dest)
    if (R/(path+'.import')).exists():shutil.copyfile(R/(path+'.import'),P/(path+'.import'))
    else:
        text=(R/'assets/characters/shi_en_portrait_20261015/shi_en.png.import').read_text('utf-8')
        res='res://'+path;cache='res://.godot/imported/'+dest.name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex'
        text=re.sub(r'uid="[^"]+"','uid="uid://c'+hashlib.sha256(res.encode()).hexdigest()[:11].replace('9','8')+'"',text)
        text=text.replace('res://.godot/imported/shi_en.png-a2331b28a9f426ad055239a96d5b6025.ctex',cache).replace('res://assets/characters/shi_en_portrait_20261015/shi_en.png',res)
        (P/(path+'.import')).write_bytes(text.encode())
for path in empty_resources.values():
    dest=P/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/path,dest)
for path,content in layered.render(m).items():
    dest=P/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(content.encode())
save(P/'manifest.json',m)
save(P/'inputs.json',{'textures':{p:{'size':list(Image.open(R/p).size),'source_sha256':sha(R/p)} for p in textures},'empty_resources':empty_resources})
shutil.copyfile('D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018/resource_preview.gd',P/'preview.gd')
(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Ruan7 NW low walk comparison"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
frozen=[{'path':f.relative_to(P).as_posix(),'sha256':sha(f)} for f in P.rglob('*') if f.is_file()]
receipt={'state':'prepared','project':str(P),'frozen':frozen,'texture_count':len(textures),'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False}
save(P/'receipt.json',receipt);save(E/'prepared_pointer.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({'receipt':str(P/'receipt.json'),'textures':len(textures),'poses_changed':list(new_points),'production_changed':False}))
