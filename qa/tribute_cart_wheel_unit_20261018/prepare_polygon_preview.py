import datetime,hashlib,json,pathlib,shutil,uuid
E=pathlib.Path(__file__).parent
S=E/'candidate_v2'
P=E/'polygon_native'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
P.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((E/'candidate_v2_manifest.json').read_text())
for row in manifest['files']:
    if row['path'] in ['scripts/unit.gd','assets/characters/tribute_cart_wheel_runtime_20261018/manifest.json']:continue
    src=S/row['path'];assert sha(src)==row['sha256']
    dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
shutil.copyfile(E/'polygon_preview.gd',P/'preview.gd')
(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Cart polygon rendering preview"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=1000\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf-8')
frozen=[{'path':f.relative_to(P).as_posix(),'sha256':sha(f)} for f in P.rglob('*') if f.is_file()]
rec={'state':'prepared','project':str(P),'frozen':frozen,'texture_count':3,'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False,'scope':'New polygon renderer exact candidate helper and three original PNGs; stand-in CartPaint, not real Unit.'}
rp=P/'receipt.json';rp.write_text(json.dumps(rec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(E/'polygon_prepared_pointer.json').write_text(json.dumps({'receipt':str(rp)},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(rp)
