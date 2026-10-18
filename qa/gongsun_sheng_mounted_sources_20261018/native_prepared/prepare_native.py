from pathlib import Path
import datetime,hashlib,json,re,shutil,uuid
import numpy as np
from PIL import Image
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent
manifest=json.loads((R/'assets/characters/gongsun_sheng_mounted_sources_20261018/prompt_set.json').read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
save=lambda p,v:p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
P=E/'native_resources'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);P.mkdir(parents=True);(P/'frames').mkdir()
textures={};poses=[]
for row in manifest['sources']:
 if row['key'] not in manifest['candidate_keys']:continue
 key=row['key'];source=R/row['path'];assert sha(source)==row['sha256'];shutil.copyfile(source,P/(key+'.png'))
 resource='res://'+key+'.png'
 text=(R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png.import').read_text(encoding='utf-8')
 text=re.sub(r'uid="[^"]+"','uid="uid://c'+hashlib.sha256(resource.encode()).hexdigest()[:11].replace('9','8')+'"',text)
 text=re.sub(r'res://\.godot/imported/cart_only\.png-[0-9a-f]+\.ctex','res://.godot/imported/'+key+'.png-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex',text).replace('res://assets/characters/liu_tang_pushcart_20261017/cart_only.png',resource)
 (P/(key+'.png.import')).write_bytes(text.encode())
 textures[key]={'path':key+'.png','size':[1254,1254],'source_sha256':row['sha256'],'canonical_source':row['path']}
 a=np.asarray(Image.open(source))[:,:,3]
 for d,x,y in [('se',0,0),('sw',627,0),('ne',0,627),('nw',627,627)]:
  cell=a[y:y+627,x:x+627];ys,xs=np.where(cell>16)
  strong=[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())]
  found=None
  for padding in range(12,25):
   left=max(0,strong[0]-padding);top=max(0,strong[1]-padding);right=min(627,strong[2]+padding+1);bottom=min(627,strong[3]+padding+1)
   region=a[y+top:y+bottom,x+left:x+right]
   corners=[int(region[0,0]),int(region[0,-1]),int(region[-1,0]),int(region[-1,-1])]
   if corners==[0,0,0,0]:found=(left,top,right,bottom,padding);break
  assert found is not None,(key,d)
  left,top,right,bottom,padding=found;w=right-left;h=bottom-top
  name='frames/'+key+'_'+d+'.tres'
  (P/name).write_bytes(('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="'+resource+'" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\nfilter_clip = true\n'%(x+left,y+top,w,h,left,top,627-w,627-h)).encode())
  poses.append({'key':key,'direction':d,'resource':name,'source':row['path'],'region':[x+left,y+top,w,h],'native_padding':padding,'strong_local':strong,'selected_corner_alpha':corners,'whole_cell_corner_alpha':[int(cell[0,0]),int(cell[0,-1]),int(cell[-1,0]),int(cell[-1,-1])]})
save(P/'inputs.json',{'textures':textures,'poses':poses,'scope':'Proposed source selection rectangles, preserving all strong alpha and original PNG bytes. Native padding12..24 chosen only to obtain zero rectangle corners; whole-cell failures are retained. No adoption or animation qualification.'})
shutil.copyfile(E/'resource_preview.gd',P/'preview.gd')
(P/'project.godot').write_bytes(b'config_version=5\n[application]\nconfig/name="Chapter54 unbound mounted source comparison"\n[display]\nwindow/size/viewport_width=1440\nwindow/size/viewport_height=620\nwindow/size/window_position_type=0\nwindow/size/initial_position=Vector2i(30000,30000)\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
frozen=[{'path':q.relative_to(P).as_posix(),'sha256':sha(q)} for q in P.rglob('*') if q.is_file()]
save(P/'receipt.json',{'state':'prepared','project':str(P),'frozen':frozen,'texture_count':5,'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False,'scope':'Standalone20-region comparison only, not mounted game character or completed gait.'})
save(E/'native_prepared_pointer.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({'prepared':str(P/'receipt.json'),'textures':5,'poses':20,'frozen':len(frozen),'selected_corner_zeros':sum(x['selected_corner_alpha']==[0,0,0,0] for x in poses),'whole_cell_failures_retained':sum(x['whole_cell_corner_alpha']!=[0,0,0,0] for x in poses)}))
