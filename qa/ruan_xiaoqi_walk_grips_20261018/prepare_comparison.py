import copy,datetime,hashlib,json,pathlib,re,shutil,sys,uuid
import numpy as np
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import build_ruan_xiaoqi_layered_20261018 as builder
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
base=load(R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json');m=copy.deepcopy(base)
raw=load(R/'assets/characters/ruan_xiaoqi_walk_grips_20261018/prompt_set.json');by_key={x['key']:x for x in raw['sources']}
specs={'push_contact_a':('contact_a',{'se':[[414,378],[534,326]],'sw':[[762,332],[886,382]]}),
'push_passing_a':('passing_a_padded',{'se':[[397,380],[516,327]],'sw':[[751,326],[870,384]],'ne':[[512,963]],'nw':[[743,965]]}),
'push_contact_b':('contact_b',{'se':[[407,360],[540,310]],'sw':[[747,317],[889,369]],'ne':[[537,933]],'nw':[[750,941]]}),
'push_passing_b':('passing_b_padded',{'se':[[402,392],[519,332]],'sw':[[753,329],[887,398]],'ne':[[523,934]],'nw':[[768,945]]})}
targets={'se':[[52,194],[171,141]],'sw':[[1086,155],[1200,198]],'ne':[[194,1069]],'nw':[[1047,1088]]};roots={'se':305,'sw':965,'ne':310,'nw':970};changes=[];worksheet={}
for state,(source_key,grips) in specs.items():
    row=by_key[source_key];origin=R/row['path'];assert sha(origin)==row['sha256']
    with Image.open(origin) as im:alpha=np.asarray(im)[:,:,3]
    key=origin.stem+'_'+row['sha256'][:8];m['sources'][key]={'path':row['path'],'candidate_origin':row['path'],'sha256':row['sha256'],'native_size':row['native_size'],'imported_size':row['native_size'],'selected_directions':list(grips)}
    for d,points in grips.items():
        name=state+'_'+d;old=base['poses'][name];cart=base['poses']['cart_only_'+d];region=row['geometry'][d]['region'];x,y,w,h=region
        yy,xx=np.nonzero(alpha[y:y+h,x:x+w]>=64);assert yy.min()>0 and yy.max()<h-1 and xx.min()>0 and xx.max()<w-1
        reference=(int(yy.max())+1-int(yy.min()))/old['body_height_target'];pivot=[roots[d],y+int(yy.max())+1]
        p=builder.canvas_pose(region,pivot,reference,y+int(yy.min()))
        source_norm=[[(pt[i]-pivot[i])/reference for i in range(2)] for pt in points]
        target_norm=[[(pt[i]-cart['pivot_native'][i]+cart['draw_offset_px'][i])/cart['virtual_canvas_reference'] for i in range(2)] for pt in targets[d]]
        delta=[sum(t[i]-s[i] for s,t in zip(source_norm,target_norm))/len(points) for i in range(2)]
        residual=[float(np.linalg.norm(np.array(s)+delta-np.array(t))) for s,t in zip(source_norm,target_norm)]
        reg={'manual_source_grip_centres':points,'manual_cart_grip_targets':targets[d],'translation_per_body_size':delta,'estimated_residual_per_body_size':residual,'occluded_far_hand':d in ['ne','nw'],'method':'Approximate primary-agent landmarks, translation-only front-pair midpoint or visible rear near-grip alignment. Single-point residual0 is arithmetic, not physical contact or far-hidden-hand proof. Full gait/foot-root continuity remains unaccepted.'}
        p.update(source=key,independent_cart=True,body_height_target=old['body_height_target'],draw_offset_px=[v*reference for v in delta],hand_registration=reg,operations='Unmodified built-in original atlas, selected native region and virtual padding/uniform height calibration, static translation-only grip fit. Fixed cart untouched. Not final hand/gait/body continuity acceptance.')
        m['poses'][name]=p;changes.append({'pose':name,'before':old,'after':p});worksheet[name]=reg
assert len(changes)==14
used={v['source'] for v in m['poses'].values()};m['sources']={k:v for k,v in m['sources'].items() if k in used};assert len(m['sources'])==7
changed={x['pose'] for x in changes}
for k,v in base['poses'].items():
    if k not in changed:assert m['poses'][k]==v,k
assert m['canonical_cart_geometry']==base['canonical_cart_geometry']
save(E/'candidate_manifest.json',m);save(E/'candidate_changes.json',changes);save(E/'grip_worksheet.json',worksheet)
P=E/'native_comparison'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);P.mkdir(parents=True)
empty=load(R/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json');empty_resources={d:next(n for n in empty['resources'] if n.endswith('_idle_'+d+'.tres')) for d in ['se','sw','ne','nw']}
textures={v['path']:v for v in m['sources'].values()};textures[empty['sources']['idle_spacing']['path']]=empty['sources']['idle_spacing']
for name in textures:
    dest=P/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/name,dest)
    if (R/(name+'.import')).exists():shutil.copyfile(R/(name+'.import'),P/(name+'.import'))
    else:
        text=(R/'assets/characters/shi_en_portrait_20261015/shi_en.png.import').read_text('utf-8');res='res://'+name;cache='res://.godot/imported/'+dest.name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex'
        text=re.sub(r'uid="[^"]+"','uid="uid://c'+hashlib.sha256(res.encode()).hexdigest()[:11].replace('9','8')+'"',text).replace('res://.godot/imported/shi_en.png-a2331b28a9f426ad055239a96d5b6025.ctex',cache).replace('res://assets/characters/shi_en_portrait_20261015/shi_en.png',res)
        (P/(name+'.import')).write_bytes(text.encode())
for name in empty_resources.values():
    dest=P/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/name,dest)
for name,content in builder.render(m).items():
    dest=P/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(content.encode())
save(P/'manifest.json',m);save(P/'inputs.json',{'textures':{n:{'size':list(Image.open(R/n).size),'source_sha256':sha(R/n)} for n in textures},'empty_resources':empty_resources})
shutil.copyfile('D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018/resource_preview.gd',P/'preview.gd')
(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Ruan7 remaining fourteen walk grips"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
frozen=[{'path':f.relative_to(P).as_posix(),'sha256':sha(f)} for f in P.rglob('*') if f.is_file()]
save(P/'receipt.json',{'state':'prepared','project':str(P),'frozen':frozen,'texture_count':len(textures),'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False});save(E/'prepared_pointer.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({'receipt':str(P/'receipt.json'),'textures':len(textures),'frozen':len(frozen),'changed_poses':14,'unchanged_poses':10,'candidate_residual_max':max(max(x['estimated_residual_per_body_size']) for x in worksheet.values()),'game_changed':False}))
