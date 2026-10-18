import datetime,hashlib,json,pathlib,re,shutil,uuid
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent;Q=R/'qa/tribute_cart_wheel_layers_20261018'
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
raw=load(R/'assets/characters/tribute_cart_wheel_layers_20261018/prompt_set.json');layout=R/'assets/characters/tribute_cart_wheel_layers_20261018/component_layout.json'
P=E/'native_comparison'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);P.mkdir(parents=True)
rows={'original':raw['original_production_cart']}|{x['key']:x for x in raw['sources']};textures={}
for key,row in rows.items():
 source=R/row['path'];assert sha(source)==row['sha256'];name=key+'.png';shutil.copyfile(source,P/name)
 text=(R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png.import').read_text('utf-8');old='res://assets/characters/liu_tang_pushcart_20261017/cart_only.png';res='res://'+name
 text=re.sub(r'uid="[^"]+"','uid="uid://c'+hashlib.sha256(res.encode()).hexdigest()[:11].replace('9','8')+'"',text)
 text=re.sub(r'res://\.godot/imported/cart_only\.png-[0-9a-f]+\.ctex','res://.godot/imported/'+name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex',text).replace(old,res)
 (P/(name+'.import')).write_bytes(text.encode());textures[key]={'path':name,'size':list(Image.open(source).size),'source_sha256':sha(source),'canonical_source':row['path']}
shutil.copyfile(layout,P/'component_layout.json');shutil.copyfile(E/'preview.gd',P/'preview.gd');save(P/'inputs.json',{'textures':textures})
(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Unadopted Jiangzhou cart component comparison"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
frozen=[{'path':f.relative_to(P).as_posix(),'sha256':sha(f)} for f in P.rglob('*') if f.is_file()]
save(P/'receipt.json',{'state':'prepared','project':str(P),'frozen':frozen,'texture_count':3,'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False,'rotating_animation_accepted':False});save(E/'prepared_pointer.json',{'receipt':str(P/'receipt.json')})
prepared=Q/'prepared_centered';prepared.mkdir()
for name in ['receipt.json','inputs.json','component_layout.json','preview.gd','project.godot']:shutil.copyfile(P/name,prepared/name)
shutil.copyfile(E/'prepare_native_centered.py',Q/'prepare_native_centered.py');shutil.copyfile('D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018/prepare_native_preview.py',prepared/'native_runner.py')
save(Q/'native_gate.json',{'state':'prepared','resource_receipt':str(P/'receipt.json'),'textures':3,'frozen_files':len(frozen),'native_launched':False,'runtime_adopted':False,'rotating_animation_accepted':False,'priority':'Run after the already queued Ruan Xiaoqi fourteen-pose resource comparison; never overlap another engine or remove a foreign lock.','resume_command':['python','-X','utf8','-B','D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018/prepare_native_preview.py','--run-existing',str(P/'receipt.json')],'next':'Directly inspect four raw compositing screenshots. Correct hub/ground/rim/chassis overlap before any production integration or rolling implementation. No old check transfer.'})
print(json.dumps({'receipt':str(P/'receipt.json'),'textures':3,'frozen':len(frozen),'native_launched':False,'runtime_adopted':False}))
