from pathlib import Path
import datetime,hashlib,json,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];P=R/'qa/li_yun_zou_run_portraits_20261019'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
    with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
original=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853');(Q/'native_originals').mkdir(exist_ok=False)
generated={'li_yun':'exec-292f6a3d-5ef9-4022-acd3-696b64874820.png','zou_run':'exec-432ef131-e84f-4ae4-a7f3-76c1d3e8b247.png'};sources=[];canon=[];routes=[]
for key,name in generated.items():
    target=Q/'native_originals'/f'{key}_v2.png';shutil.copyfile(original/name,target);assert sha(target)==sha(original/name)
    with Image.open(target) as image:assert image.mode in ['RGB','RGBA'] and image.size==(1254,1254);mode=image.mode
    prompt=Q/f'tool_prompt_{key}_v2.json';args=json.loads(prompt.read_text(encoding='utf-8'))
    source={'key':key+'_v2','mode':'builtin_imagegen','intent':'targeted_portrait_edit','file':target.relative_to(Q).as_posix(),'generated_original':str(original/name),'sha256':sha(target),'bytes':target.stat().st_size,'size':[1254,1254],'pixel_mode':mode,
        'exact_tool_arguments':prompt.name,'prompt_sha256':sha(prompt),'references':[{'path':path,'repository_path':Path(path).relative_to(R).as_posix(),'sha256':sha(Path(path)),'role':'edit_target' if i==0 else 'current_cap_reference'} for i,path in enumerate(args['referenced_image_paths'])],
        'local_pixel_writes':False,'production_adopted':False,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    write(Q/f'source_{key}_v2.json',source);sources.append(source)
    prior=json.loads((P/f'canon_{key}.json').read_text(encoding='utf-8'));book=P/prior['primary_text'];assert sha(book)==prior['primary_text_sha256']
    for quote in prior['quotes']:assert quote['text'] in book.read_text(encoding='utf-8').splitlines()[quote['line']-1]
    canon.append({'key':key,'basis':(P/f'canon_{key}.json').relative_to(R).as_posix(),'basis_sha256':sha(P/f'canon_{key}.json'),'primary_text':book.relative_to(R).as_posix(),'primary_text_sha256':sha(book),'quotes':prior['quotes'],'source_reused_not_refetched':True,
        'scope':'Same verified chapter43/49 traits. Cap shape, hair arrangement, flesh prominence size and precise colors remain art design, not new literal novel claims.'})
    route=json.loads((P/f'routing_{key}_before.json').read_text(encoding='utf-8'))
    for row in route['source_files']:assert sha(R/row['path'])==row['sha256']
    routes.append({'key':key,**route})
write(Q/'canon_basis.json',{'characters':canon,'production_adopted':False,'full_character_canon_accepted':False})
write(Q/'routing_before.json',{'characters':routes,'source_pngs_unchanged':True,'production_adopted':False})
write(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':sources,'production_adopted':False,'native_accepted':False})
print(json.dumps({'sources':[{'key':row['key'],'sha256':row['sha256']} for row in sources],'canon_reused':2,'production_adopted':False}))
