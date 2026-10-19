"""Portable read-only verification of committed originals, raw sampling edges and canon provenance."""
from pathlib import Path
import ast,hashlib,json
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for version,report_name in [('v1','source_admission.json'),('v2','source_admission_v2.json')]:
    source=json.loads((Q/f'source_full_leg_{version}.json').read_text(encoding='utf-8'))
    assert sha(Q/source['file'])==source['sha256'] and sha(Q/source['exact_tool_arguments'])==source['prompt_sha256']
    report=json.loads((Q/report_name).read_text(encoding='utf-8'));assert report['source_sha256']==source['sha256']
    with Image.open(Q/source['file']) as image:
        assert image.mode=='RGBA' and image.size==(1254,1254);alpha=image.getchannel('A')
        for region in report['regions']:
            x,y,w,h=region['region'];edge=[alpha.getpixel((xx,yy)) for xx in range(x,x+w) for yy in [y,y+h-1]]+[alpha.getpixel((xx,yy)) for yy in range(y,y+h) for xx in [x,x+w-1]]
            assert max(edge)==region['edge_max_alpha']
            if region['strict_edge_clear']:assert not any(edge)
    rows.append({'version':version,'source_sha256':source['sha256'],'strict_clear_regions':sum(row['strict_edge_clear'] for row in report['regions']),'source_alpha_accepted':report['source_alpha_accepted']})
assert rows[0]['strict_clear_regions']==6 and rows[1]['strict_clear_regions']==8
canon=json.loads((Q/'canon_basis.json').read_text(encoding='utf-8'));assert sha(R/canon['primary_text'])==canon['primary_text_sha256']
for p in Q.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'))
result={'scope':'Original byte hashes, selected raw-alpha rectangle edges, exact prompts, AST and chapter44 text only. Extra faint components remain; not a claim that all image pixels outside the clothing are empty.',
    'versions':rows,'passed':True,'production_adopted':False,'native_accepted':False}
if (Q/'verification.json').exists():
    assert json.loads((Q/'verification.json').read_text(encoding='utf-8'))==result
else:
    with (Q/'verification.json').open('x',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result))
