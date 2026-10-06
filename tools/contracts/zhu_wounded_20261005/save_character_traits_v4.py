"""Save native ordinary-idle art and read-only quarter bounds for named heroes."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
key,original_arg=sys.argv[1:3]
assert key in ('wu_song','lin_chong')
state=sys.argv[3] if len(sys.argv)>3 else 'idle_traits'
assert state in ('idle_traits','idle_spacing_traits','idle_spacing2_traits')
original=Path(original_arg);request=HERE/'requests'/f'{key}_{state}_v4.json'
args=json.loads(request.read_text(encoding='utf-8'))
baseline=json.loads((HERE/'selection_idle_traits_v4.json').read_text(encoding='utf-8'))['baseline']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
refs=[]
for ref in args['referenced_image_paths']:
    p=Path(ref);rel=p.relative_to(ROOT).as_posix()
    parent_state='idle_spacing_traits' if state=='idle_spacing2_traits' else 'idle_traits'
    parent_path=HERE/'jobs'/f'{key}_{parent_state}_v4.json'
    if state!='idle_traits' and parent_path.exists():
        parent=json.loads(parent_path.read_text(encoding='utf-8'))
        assert rel==parent['output'] and sha(p)==parent['output_sha256']
        refs.append({'path':rel,'sha256':sha(p),'parent_job':parent_path.relative_to(ROOT).as_posix()})
    else:
        blob=subprocess.run(['git','show',baseline+':'+rel],cwd=ROOT,capture_output=True,check=True,timeout=10).stdout
        assert hashlib.sha256(blob).hexdigest()==sha(p)
        refs.append({'path':rel,'sha256':sha(p),'baseline':baseline})
filename={'idle_traits':'idle_v4.png','idle_spacing_traits':'idle_spacing_v4.png','idle_spacing2_traits':'idle_spacing2_v4.png'}[state]
dest=ROOT/'assets/characters'/f'{key}_traits_20261006'/filename
job_path=HERE/'jobs'/f'{key}_{state}_v4.json'
assert not dest.exists() and not job_path.exists()
with Image.open(original) as im:
    assert im.mode=='RGBA' and max(im.size)<=1536
    assert im.getextrema()[3][0]==0 and im.getextrema()[3][1]>0
    size=list(im.size);alpha=im.getchannel('A');rows=[]
    w,h=im.width//2,im.height//2
    for i,d in enumerate(('se','sw','ne','nw')):
        a=alpha.crop(((i%2)*w,(i//2)*h,(i%2+1)*w,(i//2+1)*h))
        b=a.point(lambda v:255 if v>16 else 0).getbbox();assert b
        clearance=min(b[0],b[1],w-b[2],h-b[3])
        rows.append({'direction':d,'bounds':list(b),'clearance':clearance,'passed':clearance>=4})
dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,dest);assert sha(dest)==sha(original)
job={'schema':1,'character':key,'state':'ordinary_idle','revision':'character_traits_v4',
    'method':'built-in image_gen native PNG byte-preserved','generation_id':original.stem,
    'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'references':refs,
    'output':dest.relative_to(ROOT).as_posix(),'output_sha256':sha(dest),'native_size':size,'mode':'RGBA',
    'native_pixel_edits':False,'direct_visual_review':'Four full upright facings directly inspected; existing identity and equipment retained. Original Unit/routing/actions/UI pending.',
    'posture_profile':f'tools/contracts/zhu_wounded_20261005/character_posture_profiles_v4.json#{key}',
    'runtime_qualified':False,'production_qualified':False}
job['direct_visual_review']='Native output directly inspected. Upright posture candidate only; whole-body heading, hand/weapon anatomy and uniform identity still require per-quadrant acceptance.'
job_path.write_text(json.dumps(job,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
receipt={'schema':1,'source':job['output'],'sha256':sha(dest),'checks':rows,'passed':all(r['passed'] for r in rows),
    'scope':'Native byte and read-only quadrant boundaries; not Godot import, movement, weapon-hand anatomy or original-game acceptance','production_qualified':False}
(ROOT/'qa/zhu_wounded_20261005'/f'{key}_{state}_authoring_v4.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'output':job['output'],'sha256':sha(dest),'bounds_passed':receipt['passed'],'clearances':[r['clearance'] for r in rows],'production_qualified':False}))
