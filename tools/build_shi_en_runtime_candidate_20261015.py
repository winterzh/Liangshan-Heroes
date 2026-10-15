"""Author native Shi En atlas geometry; emit resources only after real import proof."""
from pathlib import Path
import argparse,hashlib,json,importlib.util,math
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/shi_en_gait_20261015'
FAMILY='character_traits_v1_shi_en_gait'
MANIFEST='assets/direction4/ordinary_shi_en_20261015_gait_v1.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def prepare():
    source=json.loads((QA/'source_manifest.json').read_text(encoding='utf-8'))
    plan={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'shi_en',
        'candidate_source_manifest_sha256':sha(QA/'source_manifest.json'),
        'sources':{},'poses':{},'states':source['states'],
        'resources':[f'assets/anim/{FAMILY}_{state}_{d}.tres' for d in ('se','sw','ne','nw') for state in ('idle','walk')],
        'production_qualified':False,'native_dimensions_verified':False}
    for key,row in source['sources'].items():
        native=ROOT/row['path'];assert sha(native)==row['sha256']
        runtime='assets/characters/shi_en_gait_runtime_20261015/'+native.name
        plan['sources'][key]={'path':runtime,'candidate_origin':row['path'],'sha256':row['sha256'],
            'native_size':row['native_size'],'imported_size':row['native_size'],
            'import_limit':2048,'import_dimensions_verified':False,
            'import_dimension_status':'Expected only; real native import proof required',
            'uniform_virtual_canvas':row['uniform_virtual_canvas']}
    for key,row in source['poses'].items():
        x,y,w,h=row['region'];native=ROOT/source['sources'][row['source']]['path']
        with Image.open(native) as image:
            # Atlas sampling bounds only; retain all nonzero-alpha source pixels
            # of this selected region, including weak edges. Never emit a PNG.
            bbox=image.getchannel('A').crop((x,y,x+w,y+h)).getbbox();assert bbox
            l,t,r,b=max(0,bbox[0]-4),max(0,bbox[1]-4),min(w,bbox[2]+4),min(h,bbox[3]+4)
        rx,ry,rw,rh=x+l,y+t,r-l,b-t
        intended_canvas=row['virtual_canvas'];px,py=row['pivot_native']
        pivot_x,pivot_y=px-rx,py-ry
        # Weak native alpha can extend beyond the substantial-alpha silhouette.
        # Fit the entire source sampling box without shrinking or cropping the
        # actual person: scale compensation preserves native pixels per screen px.
        canvas=max(intended_canvas,math.ceil(2*pivot_x),math.ceil(2*(rw-pivot_x)),
            math.ceil(pivot_y/.82),math.ceil((rh-pivot_y)/.18))
        left=canvas*.5-(px-rx);top=canvas*.82-(py-ry)
        assert 0<=left and left+rw<=canvas and 0<=top and top+rh<=canvas,(key,left,top,rw,rh,canvas)
        plan['poses'][key]={'source':row['source'],'region_raw':[rx,ry,rw,rh],'region':[rx,ry,rw,rh],
            'margin':[left,top,canvas-rw,canvas-rh],'draw_offset_px':[0,0],
            'draw_scale':canvas/intended_canvas,'uniform_source_virtual_canvas':intended_canvas,
            'virtual_size_imported':canvas,'pivot':row['pivot_native'],
            'operations':'Native atlas sampling and square transparent margin only; no pixel edit, stretch or mirror.'}
    return plan
def build(report_path):
    plan=prepare();report=json.loads(report_path.read_text(encoding='utf-8'))
    assert report['passed'] and not report['failures']
    assert report['plan_sha256']==sha(QA/'runtime_plan.json')
    assert report['candidate_source_manifest_sha256']==plan['candidate_source_manifest_sha256']
    assert set(report['sources'])==set(plan['sources'])
    for key,row in plan['sources'].items():
        observed=report['sources'][key]
        assert observed['sha256']==row['sha256'] and observed['imported_size']==row['native_size']
        assert sha(ROOT/row['path'])==row['sha256']
        descriptor=Path(str(ROOT/row['path'])+'.import').read_text(encoding='utf-8')
        assert 'mipmaps/generate=true' in descriptor and 'process/size_limit=2048' in descriptor
        row.update(import_dimensions_verified=True,import_dimension_status='Actual isolated Godot cold-import probe dimensions verified')
    plan['native_dimensions_verified']=True;plan['actual_import_report_sha256']=sha(report_path)
    path=ROOT/MANIFEST;write(path,plan)
    helper=ROOT/'tools/build_directional_spriteframes.py'
    spec=importlib.util.spec_from_file_location('shi_en_existing_builder',helper)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    assert module.ROOT==ROOT
    for name,text in module.render(plan).items():
        target=ROOT/name;assert not target.exists(), 'Never overwrite existing character resource'
        target.write_text(text,encoding='utf-8',newline='\n')
    return plan
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--from-import',type=Path);args=parser.parse_args()
    if args.prepare:
        plan=prepare();path=QA/'runtime_plan.json'
        if path.exists():assert json.loads(path.read_text(encoding='utf-8'))==plan,'Existing plan changed; preserve prior evidence before revising'
        else:write(path,plan)
        print(json.dumps({'prepared_poses':len(plan['poses']),'planned_resources':len(plan['resources']),'resources_written':False,'import_pending':True}));return
    if args.from_import:
        plan=build(args.from_import);print(json.dumps({'written_resources':len(plan['resources']),'actual_import_dimensions_verified':True,'game_scene_pending':True}));return
    plan=prepare();assert json.loads((QA/'runtime_plan.json').read_text(encoding='utf-8'))==plan
    print(json.dumps({'runtime_geometry_matches_native_sources':True,'resources_not_yet_qualified':True}))
if __name__=='__main__':main()
