"""Read-only current campaign registration versus curated art plan audit.

Literal references are source evidence, not a complete dynamic spawn inventory.
This audit cannot qualify art, runtime behavior or campaign completion.
"""
from pathlib import Path
import argparse,hashlib,json,re
import campaign_direction4_coverage_audit as legacy

ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def audit():
 registry=ROOT/'scripts/campaign.gd';source=registry.read_text(encoding='utf-8')
 block=re.search(r'const LEVELS := \[(.*?)\n\]',source,re.S)
 if not block:raise ValueError('Missing explicit campaign registration')
 entries=re.findall(r'\{"id": "([^"]+)",.*?"script": "res://([^"]+)"\}',block[1])
 if len(entries)!=8 or len({x[0] for x in entries})!=8:raise ValueError('Expected eight unique registered chapters')
 inputs={'scripts/campaign.gd':sha(registry),'tools/campaign_art_entrypoint_audit.py':sha(Path(__file__)),'tools/campaign_direction4_coverage_audit.py':sha(ROOT/'tools/campaign_direction4_coverage_audit.py')}
 rows=[]
 for ident,path in entries:
  p=ROOT/path;data=p.read_text(encoding='utf-8');inputs[path]=sha(p)
  old=legacy.LEVEL_SPECS[ident]['script'];oldp=ROOT/old;inputs[old]=sha(oldp)
  # Annotated literal assignments/spawns/definitions help locate the next
  # source review. Dynamic loops and helper arguments require manual review.
  refs=[]
  for line_no,line in enumerate(data.splitlines(),1):
   if any(t in line for t in ['art_variant','defeat_outcome','play_story_pose','resolve_story','spawn_unit(','spawn_at(','_guard(','_spawn(','"art_variant"']):
    refs.append({'line':line_no,'text':line.strip()})
  rows.append({'id':ident,'registered_script':path,'registered_sha256':sha(p),'curated_art_script':old,'curated_matches_registered_entrypoint':path==old,'registered_literal_references':refs,'manual_dynamic_review_required':True})
 result={'complete':True,'scope':'Registration and literal source references only. Legacy specs may differ from active entries; legacy coverage percentages must not be presented as current eight-chapter art qualification. No dynamic spawn or render acceptance.','registered_chapters':rows,'entrypoints_matching_curated':sum(x['curated_matches_registered_entrypoint'] for x in rows),'input_sha256':inputs}
 payload=json.dumps(result,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8');result['deterministic_payload_sha256']=hashlib.sha256(payload).hexdigest()
 return result

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 output=args.output.resolve()
 if output.is_relative_to(ROOT/'assets') or output.is_relative_to(ROOT/'scripts'):raise ValueError('Do not overwrite production inputs')
 result=audit();output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 print(json.dumps({'complete':True,'registered_chapters':len(result['registered_chapters']),'entrypoints_matching_curated':result['entrypoints_matching_curated'],'mismatches':[x['id'] for x in result['registered_chapters'] if not x['curated_matches_registered_entrypoint']],'output':str(output),'deterministic_payload_sha256':result['deterministic_payload_sha256']}))
 return 0
if __name__=='__main__':raise SystemExit(main())
