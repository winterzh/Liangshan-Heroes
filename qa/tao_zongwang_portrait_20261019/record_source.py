from pathlib import Path
import datetime,hashlib,json,re,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
original=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853/exec-7bfe0ed7-3fb1-4e51-a2ee-d70cdbb4078e.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,value):
    with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
target=Q/'native_originals/portrait_v1.png';target.parent.mkdir(exist_ok=False);shutil.copyfile(original,target);assert sha(original)==sha(target)
with Image.open(target) as image:assert image.mode in ['RGB','RGBA'] and image.size==(1254,1254);mode=image.mode
args=json.loads((Q/'tool_prompt_portrait_v1.json').read_text(encoding='utf-8'))
source={'key':'portrait_v1','mode':'builtin_imagegen','intent':'new_named_human_portrait_from_current_identity_and_model',
    'file':'native_originals/portrait_v1.png','generated_original':str(original),'sha256':sha(target),'bytes':target.stat().st_size,'size':[1254,1254],'pixel_mode':mode,
    'exact_tool_arguments':'tool_prompt_portrait_v1.json','prompt_sha256':sha(Q/'tool_prompt_portrait_v1.json'),
    'references':[{'path':p,'repository_path':Path(p).relative_to(R).as_posix(),'sha256':sha(Path(p)),'role':'named_identity_region' if i==0 else 'current_walking_model_material_and_spade_reference'} for i,p in enumerate(args['referenced_image_paths'])],
    'atlas_identity_region':[786,401,414,377],'local_pixel_writes':False,'paper_background_intended':True,'production_adopted':False,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
save(Q/'source_portrait_v1.json',source)
book=(Q/'chapter41.txt').read_text(encoding='utf-8');quotes=['第四个好汉姓陶，名宗旺，祖贯是光州人氏。庄家田户出身，惯使一把铁锹，有的是气力，亦能使枪抡刀，因此人都唤做“九尾龟”。','宗旺力如猛虎，铁锹到处无情，','神龟九尾喻多能，都是英雄头领。']
assert all(quote in book for quote in quotes)
save(Q/'canon_basis.json',{'chapter':41,'primary_text':'chapter41.txt','primary_text_sha256':sha(Q/'chapter41.txt'),'web_source':'chapter41_source.json',
    'quotes':[{'text':quote,'line':next(i+1 for i,line in enumerate(book.splitlines()) if quote in line)} for quote in quotes],
    'explicit_facts':['Human Tao Zongwang, from Guang prefecture (光州), farming household, strong, accustomed to iron spade, also able to wield spear/saber.','The poem explicitly frames the turtle nickname as a metaphor.'],
    'art_interpretations':['Exact face, age, sun-weathered skin, beard, cloth headwrap, brown work clothes follow existing game references; not literal novel costume/phenotype assertions.','Spade shape, shoulder arrangement, parchment and close-bust composition are portrait design.'],
    'avoid':['No turtle anatomy, tails, shell, magic, new plot/casualty or inference that every chapter uses this clothing.','Do not qualify current skills from this art source.'],
    'scope':'Standard portrait candidate only; production route and body unchanged.'})
art=(R/'scripts/art_db.gd').read_text(encoding='utf-8');regions=(R/'scripts/portrait_atlas_regions.gd').read_text(encoding='utf-8')
assert '"tao_zongwang": ["res://assets/portraits15.png", Rect2(786, 401, 414, 377)]' in regions
standalone=art.split('const STANDALONE_PORTRAITS := {',1)[1].split('\n}',1)[0];assert '"tao_zongwang"' not in standalone
paths=['scripts/art_db.gd','scripts/portrait_atlas_regions.gd','scripts/defs.gd','assets/portraits15.png','assets/anim/tao_zongwang_walk.png']
save(Q/'routing_before.json',{'source_files':[{'path':p,'sha256':sha(R/p)} for p in paths],'legacy_portrait_region':[786,401,414,377],'new_portrait_adopted':False})
defs=(R/'scripts/defs.gd').read_text(encoding='utf-8');skills=[line for line in defs.splitlines() if re.match(r'\s*"tao_zongwang_[qwer]":',line)]
assert len(skills)==4
save(Q/'skill_review_pending.json',{'source':'scripts/defs.gd','source_sha256':sha(R/'scripts/defs.gd'),'actual_skill_definition_lines':skills,
    'status':'Not modified or canon-qualified by this portrait batch. Existing glue/mud, back-shell and skill effects require their own text/behavior review.'})
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':[source],'canon_basis':'canon_basis.json','production_adopted':False,'native_accepted':False})
print(json.dumps({'source_sha256':source['sha256'],'size':source['size'],'mode':mode,'canon_quotes_verified':len(quotes),'production_adopted':False}))
