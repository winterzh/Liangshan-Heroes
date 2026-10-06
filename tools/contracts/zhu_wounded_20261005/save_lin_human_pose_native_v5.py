"""Byte-preserve native ordinary armed-walk candidates and exact parent evidence."""
from pathlib import Path
import hashlib,json,shutil,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
key,state,original_arg=sys.argv[1:4]
assert key in ['wu_song','lin_chong'] and state.startswith(('walk_a_','walk_b_','passing_a_','passing_b_'))
request=HERE/'requests'/f'{key}_{state}_v5.json';args=json.loads(request.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
original=Path(original_arg);dest=ROOT/'assets/characters'/f'{key}_traits_20261006'/f'{state}_v5.png'
job=HERE/'jobs'/f'{key}_{state}_v5.json';assert not dest.exists() and not job.exists()
with Image.open(original) as im:
    assert im.mode=='RGBA' and max(im.size)<=1536 and im.getextrema()[3][0]==0 and im.getextrema()[3][1]>0
    size=list(im.size);bounds=list(im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox())
refs=[]
for raw in args['referenced_image_paths']:
    p=Path(raw);rel=p.relative_to(ROOT).as_posix();row={'path':rel,'sha256':sha(p)}
    if p.parent.name==f'{key}_traits_20261006':
        if p.stem in ['idle_spacing_v4','idle_spacing2_v4']:
            parent='idle_spacing_traits' if key=='wu_song' else 'idle_spacing2_traits'
            jp=HERE/'jobs'/f'{key}_{parent}_v4.json'
        else:
            assert p.stem.endswith('_v5')
            jp=HERE/'jobs'/f'{key}_{p.stem}.json'
        jr=json.loads(jp.read_text(encoding='utf-8'));assert jr['output']==rel and jr['output_sha256']==sha(p);row.update(parent_job=jp.relative_to(ROOT).as_posix(),parent_job_sha256=sha(jp))
    elif p.parent.name=='wu_song_traits_20261006' and key=='lin_chong':
        jp=HERE/'jobs'/f'wu_song_{p.stem}.json'
        jr=json.loads(jp.read_text(encoding='utf-8'))
        assert jr['output']==rel and jr['output_sha256']==sha(p)
        row.update(reference_role='Human leg geometry/camera ONLY; no identity, clothes or weapons inherited',parent_job=jp.relative_to(ROOT).as_posix(),parent_job_sha256=sha(jp))
    elif p.parent.name=='guides':
        evidence=[]
        for gp in [HERE/'generation_qin_ming_walk_passing_v4.json',HERE/'generation_wang_ying_walk_passing_v4.json']:
            gm=json.loads(gp.read_text(encoding='utf-8'))
            for j in gm['jobs']:
                if j['repository_path']==rel:
                    assert j['sha256']==sha(p);evidence.append({'manifest':gp.relative_to(ROOT).as_posix(),'manifest_sha256':sha(gp),'job_key':j['key'],'generator_artifacts':j.get('generator_artifacts',[])})
        assert evidence;row['geometry_only_parent_evidence']=evidence
    else:raise AssertionError('Unregistered ordinary identity/geometry reference: '+rel)
    refs.append(row)
dest.parent.mkdir(exist_ok=True);shutil.copyfile(original,dest);assert sha(dest)==sha(original)
value={'schema':1,'character':key,'state':state,'revision':'ordinary_upright_walk_v5','method':'built-in image_gen native PNG byte-preserved','generation_id':original.stem,
       'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'references':refs,'output':dest.relative_to(ROOT).as_posix(),'output_sha256':sha(dest),
       'native_size':size,'mode':'RGBA','alpha_bounds':bounds,'native_pixel_edits':False,'runtime_qualified':False,'production_qualified':False,'continuous_gait_qualified':False}
job.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf-8'));print(json.dumps({'output':value['output'],'sha256':value['output_sha256'],'native_size':size,'bounds':bounds,'production_qualified':False}))
