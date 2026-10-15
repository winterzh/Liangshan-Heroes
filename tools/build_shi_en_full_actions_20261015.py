"""Build unchanged native Shi En attack/hurt/death atlases after real import proof."""
from pathlib import Path
import argparse,hashlib,json,math,importlib.util
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
QA='qa/shi_en_full_actions_20261015/'
FAMILY='character_traits_v1_shi_en_combat'
MANIFEST='assets/direction4/ordinary_shi_en_20261015_combat_v1.json'
INPUTS=['qa/shi_en_combat_20261015/source_manifest.json','qa/shi_en_reaction_20261015/source_manifest.json']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def prepare():
    attack,reaction=[json.loads((ROOT/p).read_text(encoding='utf-8')) for p in INPUTS]
    plan={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'shi_en',
        'candidate_source_manifest_sha256':hashlib.sha256(b''.join((ROOT/p).read_bytes() for p in INPUTS)).hexdigest(),
        'source_manifests':{p:sha(ROOT/p) for p in INPUTS},'sources':{},'poses':{},
        'states':{'attack':['windup','windup','strike','strike','strike','followthrough','recover','recover'],**reaction['states']},
        'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for d in ('se','sw','ne','nw') for s in ('attack','hurt','death')],
        'native_dimensions_verified':False,'production_qualified':False}
    raw_poses={}
    for row in attack['sources']:
        key='attack_'+row['direction'];plan['sources'][key]={**row,'uniform_virtual_canvas':700}
        for pose in row['poses']:
            raw_poses[pose['phase']+'_'+row['direction']]={**pose,'source':key,'virtual_canvas':700}
    plan['sources'].update(reaction['sources'])
    raw_poses.update(reaction['poses'])
    for key,row in list(plan['sources'].items()):
        original=ROOT/row['path'];assert sha(original)==row['sha256']
        assert sha(ROOT/row['request'])==row['request_sha256']
        for ref in row['references']:assert sha(ROOT/ref['path'])==ref['sha256']
        with Image.open(original) as image:
            alpha=image.getchannel('A');corners=[(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)]
            corner_alphas=[alpha.getpixel(p) for p in corners]
            first_zero=alpha.tobytes().index(0);transparent_probe=[first_zero%image.width,first_zero//image.width]
        plan['sources'][key]={'candidate_origin':row['path'],'path':'assets/characters/shi_en_combat_runtime_20261015/'+original.name,
            'sha256':row['sha256'],'native_size':row['native_size'],'imported_size':row['native_size'],
            'import_limit':2048,'import_dimensions_verified':False,'uniform_virtual_canvas':row['uniform_virtual_canvas'],
            'native_corner_alphas':corner_alphas,'transparent_probe_xy':transparent_probe}
    for key,row in raw_poses.items():
        native=ROOT/plan['sources'][row['source']]['candidate_origin'];x,y,w,h=row['region']
        with Image.open(native) as image:
            box=image.getchannel('A').crop((x,y,x+w,y+h)).getbbox();assert box
            l,t,r,b=max(0,box[0]-4),max(0,box[1]-4),min(w,box[2]+4),min(h,box[3]+4)
        rx,ry,rw,rh=x+l,y+t,r-l,b-t
        intended=row['virtual_canvas'];px,py=row['candidate_pivot_native'];vx,vy=px-rx,py-ry
        canvas=max(intended,math.ceil(2*vx),math.ceil(2*(rw-vx)),math.ceil(vy/.82),math.ceil((rh-vy)/.18))
        left,top=canvas*.5-vx,canvas*.82-vy
        assert min(left,top)>=0 and left+rw<=canvas and top+rh<=canvas,(key,left,top,rw,rh,canvas)
        plan['poses'][key]={'source':row['source'],'region':[rx,ry,rw,rh],
            'margin':[left,top,canvas-rw,canvas-rh],'draw_offset_px':[0,0],'draw_scale':canvas/intended,
            'uniform_source_virtual_canvas':intended,'pivot':row['candidate_pivot_native'],
            'operations':'Native atlas sampling and transparent margin metadata only; unchanged PNG bytes, no stretch or mirror.'}
    assert len(plan['poses'])==40 and len(plan['sources'])==13
    return plan
def build(path):
    plan=prepare();proof=json.loads(path.read_text(encoding='utf-8'))
    assert proof['passed'] and not proof['failures'] and proof['plan_sha256']==sha(ROOT/QA/'runtime_plan.json')
    assert proof['candidate_source_manifest_sha256']==plan['candidate_source_manifest_sha256']
    assert set(proof['sources'])==set(plan['sources'])
    for key,row in plan['sources'].items():
        assert proof['sources'][key]['sha256']==row['sha256'] and proof['sources'][key]['imported_size']==row['native_size']
        assert sha(ROOT/row['path'])==row['sha256']
        desc=Path(str(ROOT/row['path'])+'.import').read_text(encoding='utf-8')
        assert 'mipmaps/generate=true' in desc and 'process/size_limit=2048' in desc
        row['import_dimensions_verified']=True
    plan['native_dimensions_verified']=True;plan['actual_import_report_sha256']=sha(path)
    write(ROOT/MANIFEST,plan)
    spec=importlib.util.spec_from_file_location('shi_en_frame_builder',ROOT/'tools/build_directional_spriteframes.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    for name,text in module.render(plan).items():
        dest=ROOT/name;assert not dest.exists(),name
        dest.write_text(text,encoding='utf-8',newline='\n')
    return plan
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepare',action='store_true');ap.add_argument('--from-import',type=Path);args=ap.parse_args()
    if args.from_import:
        plan=build(args.from_import);print(json.dumps({'written_resources':len(plan['resources']),'native_import_verified':True,'scene_pending':True}));return
    plan=prepare();path=ROOT/QA/'runtime_plan.json'
    if args.prepare and not path.exists():write(path,plan)
    assert json.loads(path.read_text(encoding='utf-8'))==plan
    print(json.dumps({'native_sources':13,'poses':40,'planned_resources':12,'source_geometry_verified':True,'native_scene_pending':True}))
if __name__=='__main__':main()
