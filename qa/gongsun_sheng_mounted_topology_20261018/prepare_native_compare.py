"""Immutable mounted topology preview; native imports are a separate admission."""
from pathlib import Path
import hashlib,json,re,shutil
import numpy as np
from PIL import Image

R=Path(__file__).resolve().parents[2]
Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_mounted_topology_20261018')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')

def main():
    assert not E.exists(),'Never overwrite immutable prepared input'
    selection=json.loads((Q/'candidate_selection.json').read_text())
    lineage=json.loads((Q/'prompt_set.json').read_text())
    assert sha(Q/'source_basis.json')==lineage['source_basis_sha256']
    for row in lineage['jobs']:
        assert sha(Q/row['file'])==row['sha256']
        assert sha(Q/row['prompt_file'])==row['prompt_sha256']
        assert all(sha(R/x['path'])==x['sha256'] for x in row['references'])
    old=Path('D:/CodexEvidence/shuihu/gongsun_mounted_idle_mass_20261018')
    previous=Path(json.loads((old/'latest.json').read_text())['receipt'])
    receipt=json.loads(previous.read_text());assert receipt['complete']
    report=json.loads((Path(receipt['project'])/'report.json').read_text())
    template=(old/'prepared/idle_padded.png.import').read_text()
    E.mkdir(parents=True);P=E/'prepared';P.mkdir();(P/'frames').mkdir()
    data={'textures':{},'views':{},'placement':{},'previous_receipt':str(previous),
          'previous_idle_native_hash':report['texture_references']['idle_padded']['data_sha256'],
          'scope':'Static topology comparison only. One shared directional source scale; each original/new pair shares the original phase ground anchor. No per-new-frame fitting, source pixel writes, actual Unit, full attack/gait/damage/death, chapter binding or final art acceptance.'}
    pixels={}
    def register(key,source):
        if key in data['textures']:return
        path=P/(key+'.png');shutil.copyfile(source,path);assert sha(path)==sha(source)
        a=np.asarray(Image.open(source));assert a.shape==(1254,1254,4);pixels[key]=a
        res='res://'+path.name;cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex'
        text=re.sub(r'uid="[^"]+"','uid="uid://c'+hashlib.sha256(res.encode()).hexdigest()[:11].replace('9','8')+'"',template)
        text=text.replace('res://.godot/imported/idle_padded.png-32fa80ea88f3346751cd676b48d49064.ctex',cache).replace('res://idle_padded.png',res)
        Path(str(path)+'.import').write_text(text,encoding='utf-8')
        data['textures'][key]={'file':path.name,'sha256':sha(path),'rgba8_sha256':hashlib.sha256(a.tobytes()).hexdigest(),'canonical_source':source.relative_to(R).as_posix()}
    register('idle_reference',R/'assets/characters/gongsun_sheng_mounted_sources_20261018/idle_padded.png')
    for state in ['reach','point']:register('old_'+state,R/('assets/characters/gongsun_sheng_mounted_sources_20261018/'+state+'_v2.png'))
    def geometry(key,d):
        di=['se','sw','ne','nw'].index(d);x=di%2*627;y=di//2*627
        a=pixels[key][y:y+627,x:x+627];yy,xx=np.nonzero(a[:,:,3]>=128);assert len(xx)>1000
        return [x,y,627,627],[int(xx.min()),int(yy.min()),int(xx.max()),int(yy.max())]
    for d in ['se','sw','ne','nw']:
        _,idle_box=geometry('idle_reference',d)
        data['placement'][d]={'idle_reference_height':idle_box[3]-idle_box[1]+1,'common_scale_all_columns':True,'new_frame_autofit':False}
        specs=[('idle_reference','idle_reference','IDLE REFERENCE'),('old_reach','old_reach','ORIGINAL REACH'),('new_reach','old_reach','CORD-FIX REACH'),('old_point','old_point','ORIGINAL POINT'),('new_point','old_point','CORD-FIX POINT')]
        data['views'][d]=[]
        for kind,anchor,label in specs:
            key=kind
            if kind.startswith('new_'):
                state=kind[4:];name=selection['states'][state][d]
                source=Q/name if name.startswith('native_originals/') else R/name
                key=anchor if sha(source)==data['textures'][anchor]['sha256'] else 'selected_'+source.stem
                register(key,source)
            region,bounds=geometry(key,d);_,old_box=geometry(anchor,d)
            resource='frames/'+kind+'_'+d+'.tres'
            (P/resource).write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://'+data['textures'][key]['file']+'" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2('+', '.join(map(str,region))+')\nfilter_clip = true\n',encoding='utf-8')
            data['views'][d].append({'source_key':key,'resource':resource,'region':region,'label':label,'original_ground_y':old_box[3],'new_strong_bounds':bounds,'no_new_frame_ground_fit':True})
    save(P/'inputs.json',data);shutil.copyfile(Q/'preview.gd.txt',P/'preview.gd')
    (P/'project.godot').write_text('[application]\nconfig/name="GongsunMountedTopologyCompare"\n[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
    save(E/'prepared_binding.json',{'prepared':True,'native_executed':False,'project':str(P),'frozen':frozen,'preparer_sha256':sha(Path(__file__)),'png_count':len(data['textures']),'production_adopted':False,'candidate_views':8,'new_source_selected_views':5,'previous_receipt':str(previous)})
    for src,dst in [(P/'inputs.json',Q/'native_prepared_inputs.json'),(E/'prepared_binding.json',Q/'native_prepared_binding.json')]:shutil.copyfile(src,dst)
    print(json.dumps({'prepared_files':len(frozen),'pngs':len(data['textures']),'native_executed':False}))

if __name__=='__main__':main()
