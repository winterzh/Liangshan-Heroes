"""Compile a native Lin southwest death correction; no bitmap pixel edits."""
from pathlib import Path
import argparse, hashlib, json, re, shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--import-receipt',type=Path);args=ap.parse_args()
    prefix='assets/characters/lin_chong_traits_20261006/'
    source_path=prefix+'death_sw2_v10.png';source=ROOT/source_path
    jobs=[]
    for name,gid in [('sw','d12c91e7-00be-4ac6-9dd6-25f4d901f7d5'),('sw2','581c91c5-4f6d-4432-bcda-01dbf83a5a81')]:
        path=ROOT/(prefix+'death_'+name+'_v10.png');request=HERE/('lin_chong_death_'+name+'_v10_request.json');q=read(request)
        with Image.open(path) as im:assert im.mode=='RGBA';size=list(im.size)
        jobs.append({'key':'death_'+name+'_v10','generation_id':gid,'method':'built_in_imagegen','path':path.relative_to(ROOT).as_posix(),
                     'sha256':sha(path),'native_size':size,'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'prompt':q['prompt'],
                     'references':[{'path':Path(x).relative_to(ROOT).as_posix(),'sha256':sha(Path(x))} for x in q['referenced_image_paths']],
                     'native_pixel_edits':False,'selection':'selected' if name=='sw2' else 'retained wrong-facing fatal ancestor'})
    with Image.open(source) as im:
        assert im.size==(1254,1254) and im.mode=='RGBA'
        mask=im.getchannel('A').point(lambda a:255 if a>16 else 0)
        def bounds(window):
            x,y,x2,y2=window;b=mask.crop((x,y,x2,y2)).getbbox();assert b
            return [x+b[0],y+b[1],x+b[2],y+b[3]]
        head=bounds([245,80,400,230]);left=bounds([260,490,390,645]);right=bounds([440,475,615,635])
        pivot=[(left[0]+left[2]+right[0]+right[2])/4,(left[3]+right[3])/2-2]
        reference=pivot[1]-head[1];assert reference>400
        # Upper pose extends below the equal-square row; use the actual clear gutter.
        regions=[[0,0,627,720],[627,0,627,720],[0,740,627,514],[627,740,627,514]]
        poses={};samples=[]
        for i,state in enumerate(['fatal','fall','impact','rest']):
            region=regions[i];x,y,w,h=region;box=mask.crop((x,y,x+w,y+h)).getbbox();assert box
            assert box[0]>0 and box[1]>0 and box[2]<w and box[3]<h,(state,box)
            size=max(w,h);pad=[(size-w)/2,(size-h)/2,size-w,size-h]
            raw_pivot=pivot if state=='fatal' else [w*.70,h*.85] if state=='fall' else [w*.5,h*.61]
            anchor=[raw_pivot[0]+pad[0],raw_pivot[1]+pad[1]]
            poses[state+'_sw']={'source':'sw2','region':region,'margin':pad,'virtual_size_imported':size,'pivot':anchor,
                'draw_offset_px':[round(size*.5-anchor[0],6),round(size*.82-anchor[1],6)],'draw_scale':round(size*.78/reference,6)}
            samples.append({'pose':state+'_sw','native_alpha_bounds_in_region':list(box),'head':head,'left_boot':left,'right_boot':right,
                            'fixed_anatomical_reference_height':reference,'support_anchor':raw_pivot,'actual_world_support_qualified':False})
    descriptor=Path(str(source)+'.import')
    if not descriptor.exists():
        seed_path=prefix+'idle_spacing2_v4.png';text=(ROOT/(seed_path+'.import')).read_text(encoding='utf-8')
        text=re.sub(r'^uid=.*\n','',text,flags=re.M).replace(seed_path,source_path)
        old=Path(seed_path).name+'-'+hashlib.md5(('res://'+seed_path).encode()).hexdigest()
        new=source.name+'-'+hashlib.md5(('res://'+source_path).encode()).hexdigest()
        descriptor.write_bytes(text.replace(old,new).encode('utf-8'))
    family='character_traits_v10_lin_chong_death'
    resource='assets/anim/'+family+'_death_sw.tres'
    lines=['[gd_resource type="SpriteFrames" load_steps=6 format=3]','',
           '[ext_resource type="Texture2D" path="res://'+source_path+'" id="sw2"]']
    for state in ['fatal','fall','impact','rest']:
        p=poses[state+'_sw']
        lines+=['','[sub_resource type="AtlasTexture" id="'+state+'"]','atlas = ExtResource("sw2")',
                'region = Rect2('+', '.join(map(str,p['region']))+')','margin = Rect2('+', '.join(map(str,p['margin']))+')',
                'filter_clip = true','metadata/draw_offset_px = Vector2(%s, %s)'%tuple(p['draw_offset_px']),
                'metadata/authored_direction4 = true','metadata/draw_scale = '+str(p['draw_scale'])]
    lines+=['','[resource]','animations = [{','"frames": [',
            ',\n'.join('{"duration": 1.0, "texture": SubResource("%s")}'%s for s in ['fatal','fall','impact','rest']),
            '],','"loop": false,','"name": &"default",','"speed": 4.0','}]','']
    (ROOT/resource).write_bytes('\n'.join(lines).encode('utf-8'))
    resources=[resource];preserved=[]
    for direction in ['se','ne','nw']:
        original='assets/anim/lin_chong_death_'+direction+'.tres'
        alias='assets/anim/'+family+'_death_'+direction+'.tres';shutil.copy2(ROOT/original,ROOT/alias)
        assert sha(ROOT/original)==sha(ROOT/alias)
        resources.append(alias);preserved.append({'original':original,'alias':alias,'sha256':sha(ROOT/alias)})
    imported=False
    if args.import_receipt:
        r=read(args.import_receipt);assert r['complete'] and r['lock_released'] and r['dimensions']['passed']
        row=r['dimensions']['checks'][0];assert row['path']==source_path and row['width']==row['height']==1254 and row['passed']
        assert r['source_files'][0]['before_sha256']==r['source_files'][0]['after_sha256']==sha(source);imported=True
    manifest={'schema':'native_direction4_spriteframes_v1','revision':'character_traits_v5','character':family,'identity_key':'lin_chong',
              'candidate_only':True,'production_qualified':False,'runtime_death_qualified':False,'states':{'death':['fatal','fall','impact','rest']},
              'sources':{'sw2':{'path':source_path,'sha256':sha(source),'mode':'RGBA','native_size':[1254,1254],'imported_size':[1254,1254],'import_dimensions_verified':imported}},
              'poses':poses,'resources':resources,'preserved_resources':preserved,
              'scope':'Only southwest has four new native poses. Other three resources are exact byte aliases of existing Lin death resources; their actual texture queries must remain equal. Existing originals and failed first candidate retained. Actual world support, death/shadow/release and production adoption pending.'}
    dump(ROOT/'assets/direction4/ordinary_lin_chong_20261007_death_v10.json',manifest)
    dump(ROOT/'qa/zhu_wounded_20261005/lin_sw_death_sampling_v10.json',{'native_pixels_edited':False,'samples':samples,'runtime_qualified':False})
    dump(HERE/'generation_lin_chong_death_v10.json',{'jobs':jobs,'preserved_resources':preserved,'scope':manifest['scope']})
    print(json.dumps({'native_jobs':2,'selected_sources':1,'new_poses':4,'resources':4,'preserved_directional_resources':3,'native_import_verified':imported}))

if __name__=='__main__':main()
