from pathlib import Path
import datetime,hashlib,json,re,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
original=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853/exec-01e29d3c-a091-467d-9f3c-687fe69e8ed1.png')
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
    'atlas_identity_region':[0,800,388,400],'local_pixel_writes':False,'paper_background_intended':True,'production_adopted':False,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
save(Q/'source_portrait_v1.json',source)
book=(Q/'chapter47.txt').read_text(encoding='utf-8');quotes=['因为他面颜生得麤莽，以此人都叫他做‘鬼脸儿’。','每日拨万论千，尽托付与杜兴身上，甚是信任','杜兴也披一副甲，持把枪上马，带领二十馀骑马军。','杨雄见他说起拳棒都省得，一力维持救了他。']
assert all(quote in book for quote in quotes)
save(Q/'canon_basis.json',{'chapter':47,'primary_text':'chapter47.txt','primary_text_sha256':sha(Q/'chapter47.txt'),'web_source':'chapter47_source.json',
    'quotes':[{'text':quote,'line':next(i+1 for i,line in enumerate(book.splitlines()) if quote in line)} for quote in quotes],
    'explicit_facts':['Human Du Xing from Zhongshan prefecture; nickname explained by rough facial appearance.','Trusted steward in Li Ying household; knows fist/staff practice; wears armor and carries a spear in the narrated encounter.'],
    'art_interpretations':['Exact brow, nose, jaw, tan skin, short beard, cloth headband/topknot and lamellar colors follow existing named art/body references; not literal detailed novel costume/phenotype assertions.','Weapon-free close portrait is a UI design choice, not proof that the character is always unarmed.'],
    'avoid':['No ghost anatomy, mask, supernatural eyes, magic, invented scars or new plot/casualty.','Do not qualify current curved long-blade body/portrait weapons or existing blink/astral skills from this chapter.'],
    'scope':'Named standard portrait candidate only; no production route/body/skill change or universal costume assertion.'})
art=(R/'scripts/art_db.gd').read_text(encoding='utf-8');regions=(R/'scripts/portrait_atlas_regions.gd').read_text(encoding='utf-8')
assert '"du_xing": ["res://assets/portraits16.png", Rect2(0, 800, 388, 400)]' in regions
standalone=art.split('const STANDALONE_PORTRAITS := {',1)[1].split('\n}',1)[0];assert '"du_xing"' not in standalone
paths=['scripts/art_db.gd','scripts/portrait_atlas_regions.gd','scripts/defs.gd','assets/portraits16.png','assets/anim/du_xing_walk.png']
save(Q/'routing_before.json',{'source_files':[{'path':p,'sha256':sha(R/p)} for p in paths],'legacy_portrait_region':[0,800,388,400],'new_portrait_adopted':False})
defs=(R/'scripts/defs.gd').read_text(encoding='utf-8');skills=[line for line in defs.splitlines() if re.match(r'\s*"du_xing_[qwer]":',line)]
assert len(skills)==4
save(Q/'skill_review_pending.json',{'source':'scripts/defs.gd','source_sha256':sha(R/'scripts/defs.gd'),'actual_skill_definition_lines':skills,
    'status':'Not modified or canon-qualified by this portrait batch. Existing blink, void/astral effects and long-blade body require their own chapter/behavior review.'})
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':[source],'canon_basis':'canon_basis.json','production_adopted':False,'native_accepted':False})
print(json.dumps({'source_sha256':source['sha256'],'size':source['size'],'mode':mode,'canon_quotes_verified':len(quotes),'production_adopted':False}))
