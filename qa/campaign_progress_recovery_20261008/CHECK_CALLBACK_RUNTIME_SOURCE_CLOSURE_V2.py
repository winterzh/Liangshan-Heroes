"""Static source-pin/local-tools import audit only; no candidate execution."""
from pathlib import Path
import argparse,ast,hashlib,json
ROOT=Path(__file__).resolve().parents[2]

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--spec',type=Path,default=Path(__file__).with_name('CALLBACK_RUNTIME_SOURCE_SPEC_V2.json'));parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args();raw=args.spec.read_bytes();spec=json.loads(raw);pins={str(Path(v['path']).resolve()).casefold():v for v in spec['pins']};assert len(pins)==len(spec['pins']), 'Duplicate or aliased source pins';edges=[];missing=[]
 for pin in pins.values():
  p=Path(pin['path']);data=p.read_bytes();assert len(data)==pin['bytes'] and hashlib.sha256(data).hexdigest()==pin['sha256']
  if p.suffix!='.py':continue
  tree=ast.parse(data,filename=str(p))
  for n in ast.walk(tree):
   modules=[n.module] if isinstance(n,ast.ImportFrom) and n.level==0 else [v.name for v in n.names] if isinstance(n,ast.Import) else []
   for m in modules:
    if not m:continue
    target=ROOT/'tools'/(m.split('.')[0]+'.py')
    if target.is_file():
     row={'source':str(p),'module':m,'target':str(target)};edges.append(row)
     if str(target.resolve()).casefold() not in pins:missing.append(row)
 result={'schema':'callback_runtime_source_closure_v2','spec_sha256':hashlib.sha256(raw).hexdigest(),'checker_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'pin_count':len(pins),'all_pinned_local_tools_import_edges':len(edges),'missing_local_import_pins':missing,'static_closure_passed':not missing,'dynamic_imports_not_proven_by_AST':True,'native_started':False,'approved_stages':[]}
 with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'pins':len(pins),'static_edges':len(edges),'missing':len(missing),'native_started':False}))
 if missing:raise SystemExit(1)
if __name__=='__main__':main()
