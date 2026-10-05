"""Record exact active source inheritance and dynamic sites without claiming render coverage."""
from pathlib import Path
import hashlib,json,re,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
import campaign_art_entrypoint_audit as entry
registered=entry.audit();rows=[];inputs={}
for level in registered['registered_chapters']:
    path=level['registered_script'];chain=[];seen=set()
    while path:
        assert path not in seen;seen.add(path)
        p=repo/path;data=p.read_text(encoding='utf-8');digest=hashlib.sha256(p.read_bytes()).hexdigest();inputs[path]=digest
        refs=[];function='';preloads=[]
        for n,line in enumerate(data.splitlines(),1):
            match=re.match(r'func (\w+)\(',line)
            if match:function=match[1]
            if any(x in line for x in ('spawn_at(', 'spawn_unit(', '_guard(', 'art_variant', 'defeat_outcome', 'resolve_story(', 'play_story_pose(', 'produces', 'const ', 'super.')):
                refs.append({'line':n,'function':function,'text':line.strip()})
            preloads+=re.findall(r'(?:preload|load)\("res://([^\"]+\.gd)"\)',line)
        parent=re.search(r'^extends "res://([^\"]+\.gd)"',data,re.M)
        chain.append({'script':path,'sha256':digest,'parent':parent[1] if parent else None,'references':refs,'referenced_helpers':sorted(set(preloads))})
        path=parent[1] if parent else None
    rows.append({'id':level['id'],'entrypoint':level['registered_script'],'source_chain':chain,
                 'dynamic_review_pending':'Opening runtime inventory must be joined with late production, story transformations and helper calls; literals are source sites only.'})
result={'complete':True,'scope':'Authoritative current registration, actual inheritance chains and annotated source sites; no coverage percentage or complete dynamic requirement claim.',
        'registered_chapters':rows,'input_sha256':inputs,'legacy_entrypoints_matching_current':registered['entrypoints_matching_curated']}
(base/'source_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'chapters':len(rows),'source_files':len(inputs),'legacy_matching':registered['entrypoints_matching_curated']}))
