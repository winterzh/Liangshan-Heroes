from pathlib import Path
import datetime,hashlib,json,re,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,data):
    with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
data={
 'li_yun':{'chapter':43,'image':'exec-82945563-7c8e-4d59-a4f8-874e89b4c125.png','atlas':'assets/portraits17.png','region':[781,400,419,377],
    'quotes':['面阔眉浓须鬓赤，双睛碧绿似番人。','沂水县中青眼虎，豪杰都头是李云。','只见李云挺著一条朴刀，飞也似赶来，'],
    'facts':['Human Li Yun, Yishui constable, broad face, thick brows, red beard/sideburns, green eyes; pu-dao in this encounter.'],
    'interpretations':['Exact face, age, beard length, cap/armor shape and colors are art design. New soft dark cap folds do not exactly match the current walking cap; alignment remains pending.','Green eyes are natural colored irises without glow; parchment/close framing are UI design.'],
    'pending':'Current dark-magic/black-rain skills and detailed outfit/weapon mapping require separate cross-chapter and behavior review.'},
 'zou_run':{'chapter':49,'image':'exec-6403164b-7211-4a65-8fd2-0f317b211f3d.png','atlas':'assets/portraits16.png','region':[777,800,423,400],
    'quotes':['第二个好汉，名唤邹润，是他侄儿，年纪与叔叔仿佛，二人争差不多，身材长大，天生一等异相，脑后一个肉瘤，以此人都唤他做“独角龙”。','邹渊、邹润各拔出短刀在手。'],
    'facts':['Human Zou Run, nephew of Zou Yuan but approximately the same age, tall/large stature, a fleshy prominence at the back of his head; short knife appears in this chapter.'],
    'interpretations':['Exact face, beard, hairstyle, red cloth, armor and prominence size are art design. Back-of-head contour is shown without a forehead horn; small-size anatomical readability still pending.','Side/three-quarter close portrait has no weapon; not a statement that every story state is unarmed or armored.'],
    'pending':'Current forehead pointed horn, long-blade body and skills require their own cross-chapter/visual review; this portrait does not approve or change them.'}
}
original_base=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853');(Q/'native_originals').mkdir(exist_ok=False);originals=[]
art=(R/'scripts/art_db.gd').read_text(encoding='utf-8');regions=(R/'scripts/portrait_atlas_regions.gd').read_text(encoding='utf-8');defs=(R/'scripts/defs.gd').read_text(encoding='utf-8')
standalone=art.split('const STANDALONE_PORTRAITS := {',1)[1].split('\n}',1)[0]
for key,row in data.items():
    src=original_base/row['image'];target=Q/'native_originals'/f'{key}_v1.png';shutil.copyfile(src,target);assert sha(src)==sha(target)
    with Image.open(target) as image:assert image.mode in ['RGB','RGBA'] and image.size==(1254,1254);mode=image.mode
    prompt=Q/f'tool_prompt_{key}_v1.json';args=json.loads(prompt.read_text(encoding='utf-8'))
    source={'key':key+'_v1','mode':'builtin_imagegen','intent':'new_named_portrait_with_verified_novel_traits','file':target.relative_to(Q).as_posix(),'generated_original':str(src),'sha256':sha(target),'bytes':target.stat().st_size,'size':[1254,1254],'pixel_mode':mode,
        'exact_tool_arguments':prompt.name,'prompt_sha256':sha(prompt),'references':[{'path':p,'repository_path':Path(p).relative_to(R).as_posix(),'sha256':sha(Path(p)),'role':'named_atlas_identity_region' if i==0 else 'current_walking_body_reference_not_blanket_canon_approval'} for i,p in enumerate(args['referenced_image_paths'])],
        'atlas_identity_region':row['region'],'local_pixel_writes':False,'paper_background_intended':True,'production_adopted':False,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    save(Q/f'source_{key}_v1.json',source);originals.append(source)
    text_path=Q/f'chapter{row["chapter"]}.txt';book=text_path.read_text(encoding='utf-8');assert all(q in book for q in row['quotes'])
    save(Q/f'canon_{key}.json',{'chapter':row['chapter'],'primary_text':text_path.name,'primary_text_sha256':sha(text_path),'web_source':f'chapter{row["chapter"]}_source.json',
        'quotes':[{'text':quote,'line':next(i+1 for i,line in enumerate(book.splitlines()) if quote in line)} for quote in row['quotes']],
        'explicit_facts':row['facts'],'art_interpretations':row['interpretations'],'scope':'Standard UI portrait candidate only, not production/native/whole-character acceptance.'})
    assert '"'+key+'"' not in standalone
    rect=', '.join(map(str,row['region']));assert f'"{key}": ["res://{row["atlas"]}", Rect2({rect})]' in regions
    paths=['scripts/art_db.gd','scripts/portrait_atlas_regions.gd','scripts/defs.gd',row['atlas'],f'assets/anim/{key}_walk.png']
    save(Q/f'routing_{key}_before.json',{'source_files':[{'path':p,'sha256':sha(R/p)} for p in paths],'legacy_portrait_region':row['region'],'new_portrait_adopted':False})
    skills=[line for line in defs.splitlines() if re.match(r'\s*"'+key+r'_[qwer]":',line)];assert len(skills)==4
    save(Q/f'pending_{key}.json',{'source':'scripts/defs.gd','source_sha256':sha(R/'scripts/defs.gd'),'actual_skill_definition_lines':skills,'status':row['pending']})
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':originals,'production_adopted':False,'native_accepted':False,'full_goal_complete':False})
print(json.dumps({'originals':[{'key':r['key'],'sha256':r['sha256']} for r in originals],'production_adopted':False}))
