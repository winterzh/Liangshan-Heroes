"""Build an explicit two-hero ordinary-idle selection from retained native jobs."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
baseline=json.loads((HERE/'selection_idle_traits_v4.json').read_text(encoding='utf-8'))['baseline']
characters={};identity={}
for key,state in [('wu_song','idle_spacing_traits'),('lin_chong','idle_spacing2_traits')]:
    job=json.loads((HERE/'jobs'/f'{key}_{state}_v4.json').read_text(encoding='utf-8'))
    original=json.loads((HERE/'jobs'/f'{key}_idle_traits_v4.json').read_text(encoding='utf-8'))
    receipt=f'qa/zhu_wounded_20261005/{key}_{state}_authoring_v4.json'
    characters[key]={'job':f'{key}_{state}_v4','path':job['output'],'sha256':job['output_sha256'],'bounds_receipt':receipt,'direct_visual_review':job['direct_visual_review']}
    identity[key]={'references':original['references']}
for name,value in [('selection_ordinary_traits_v4.json',{'schema':1,'baseline':baseline,'revision':'character_traits_v4','characters':characters,'production_qualified':False}),
                   ('ordinary_identity_references_v4.json',{'schema':1,'characters':identity,'scope':'Committed identity sources for ordinary hero idle; not rescued actors'})]:
    (HERE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'characters':list(characters),'production_qualified':False}))
