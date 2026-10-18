from pathlib import Path
import datetime,hashlib,json,re,shutil,sys
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];src=Path(sys.argv[1]);dst=Q/'native_originals/portrait_v1.png';dst.parent.mkdir();assert not dst.exists()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(src,dst);assert sha(src)==sha(dst);im=Image.open(dst);assert im.mode in ['RGB','RGBA'] and im.size==(1254,1254)
args_path=Q/'tool_prompt_portrait_v1.json';args=json.loads(args_path.read_text());refs=[{'path':p,'role':'identity_reference_only' if i==0 else 'style_reference_only_different_character','sha256':sha(Path(p))} for i,p in enumerate(args['referenced_image_paths'])]
row={'key':'portrait_v1','mode':'builtin_imagegen','intent':'new_portrait_from_references_not_edit','file':dst.relative_to(Q).as_posix(),'generated_original':str(src),'sha256':sha(dst),'bytes':dst.stat().st_size,'pixel_mode':im.mode,'size':list(im.size),'rgba8_readonly_sha256':hashlib.sha256(im.convert('RGBA').tobytes()).hexdigest(),'paper_background_intended':True,'exact_tool_arguments':args_path.name,'prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),'references':refs,'local_pixel_writes':False,'production_adopted':False,'recorded_at':datetime.datetime.now().isoformat()}
save(Q/'source_portrait_v1.json',row)
book=(Q/'chapter44.txt').read_text(encoding='utf-8');quotes=['原是襄阳闲扑汉，江湖飘荡不思归。','多餐人肉双睛赤，火眼狻猊是邓飞。','能使一条铁链，人皆近他不得。']
assert all(q in book for q in quotes)
save(Q/'canon_basis.json',{'source':'chapter44_source.json','quotes':quotes,'explicit_facts':['Xiangyang origin; human Deng Fei with red eyes, nicknamed Fire-eyed Suanni.','The narration states he can use an iron chain.'],'art_interpretations':['Exact face, age impression, black curly gathered hair, beard, cloth tie, brown cloth and armor follow the currently routed game model, not literal novel costume directions.','Warm paper background, muted reddish-brown irises and non-attacking shoulder chain arrangement are portrait art choices.'],'avoid':['No creature anatomy, glowing magical eyes, flames, lion spirit transformation, gore or added plot death.','Do not infer current rescued/bound actor is armed or alter chapter events because a generic portrait includes a chain.'],'adoption_scope':'Candidate for named Deng Fei standard UI portrait only; no implementation or full-character canon acceptance.'})
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':[row],'canon_basis':'canon_basis.json','current_runtime_owner':'deng_fei','current_legacy_portrait':{'path':'assets/portraits13.png','region':[0,0,410,400]},'production_adopted':False,'native_accepted':False,'full_goal_complete':False})
print(json.dumps({'sha256':row['sha256'],'size':row['size'],'pixel_mode':row['pixel_mode'],'production_adopted':False}))
