"""Audit the complete Daming 1+8+52 cohort from original closed evidence.

Default: named source/AST checks only. --verify consumes complete producer and
negative receipts; --write-proof writes metadata only after every gate passes.
No engine, live profile, SDK, source adoption or publication is performed.
"""
from __future__ import annotations
import argparse,ast,importlib.util,json,re,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
NEG=HERE.parent/'daming_negative_v2'
spec=importlib.util.spec_from_file_location('daming61_original_negative_runner',NEG/'run_negative.py')
n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n)
a,p,h,require=n.a,n.p,n.h,n.require
CONTENT='source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132'
FALSE_FLAGS=('original_19_faults_qualified','native_sdk_qualified','public_continue_qualified','native_release_tested','desktop_os_input','human_acceptance','full_campaign_qualified','published')


def source_pins():
 pins=n.source_pins()
 for module in (n,a,p,n.prep,h,h.common,h.shared,h.identity,a.fixture):p.pin(Path(module.__file__).resolve(),pins)
 required={Path(name) for name in pins}
 doc=h.read(HERE/'sources.json')
 require(doc.get('schema')=='daming61_evidence_audit_sources_v1' and doc.get('source_identity')==CONTENT and doc.get('stage_counts')==[1,8,52], 'Exact frozen b22/61 audit contract required')
 own={Path(__file__).resolve(),HERE/'README.md'}
 require(len(doc.get('files',[]))==2 and {ROOT/row['path'] for row in doc['files']}==own, 'Exact auditor and README required')
 rows=doc.get('dependencies',[])
 require(len(rows)==len(required) and {ROOT/row['path'] for row in rows}==required,'Exact original negative runner/source/helper closure required')
 for row in [*doc['files'],*rows]:
  path=n.prep.inside(ROOT,row['path']);require(path.suffix.lower() not in ('.exe','.dll','.pck'),'Named audit cannot read binaries')
  p.pin(path,pins,row['sha256']);require(p.fs(path).stat().st_size==row['bytes'],'Named input size changed')
 p.pin(HERE/'sources.json',pins)
 for name in pins:
  if Path(name).suffix=='.py':ast.parse(p.fs(name).read_text(encoding='utf-8-sig'),filename=name)
 return pins


def strict_receipt(path,parent):
 path=Path(path).absolute()
 require(path.name=='receipt.json' and path.parent.parent==ROOT/'.godot'/parent and '..' not in path.parts,'Original exact run receipt required')
 h.identity.no_links(p.fs(path));return path,a.document(path)


def frozen_pin_map(run,pins):
 """Verify immutable runner inputs/raw reports; never the advancing profiles."""
 mapped={};binary=[]
 require(type(pins) is dict and pins,'Nonempty actual run pins required')
 for name,digest in pins.items():
  original=Path(name);require(original.is_absolute() and original.is_relative_to(ROOT) and a.fixture.hex_text(digest,64),'Strict original pin path/hash')
  if original.suffix.lower()=='.exe':binary.append({'source':name,'sha256':digest,'metadata_only':True,'read':False});continue
  frozen=original if original.is_relative_to(run) else run/'runner_inputs'/original.relative_to(ROOT)
  require(p.fs(frozen).is_file(),'Frozen run input missing: '+str(frozen));p.pin(frozen,mapped,digest)
 return mapped,binary


def verify(flow_path,negative_path,named):
 # Existing full Flow admission checks all eight reports, current LC3/Intent2/
 # ACK2, cold receipt, original closed-A inventory, nonce/PID/source bindings.
 flow_path,flow=strict_receipt(flow_path,'daming_projectile_flow_20261027')
 inputs=n.admits(flow_path)
 require(flow['content_version']==CONTENT,'Exact b22 producer identity required')
 negative_path,neg=strict_receipt(negative_path,'daming_negative_v2_20261027');run=negative_path.parent
 required=('complete','negative_52_passed','initial_identity_passed','final_identity_passed','cold_import_qualified','child_process_terminal','lock_ownership_confirmed','engine_lane_idle','lock_released')
 require(neg.get('schema')=='daming_negative_52_process_v2' and all(neg.get(k) is True for k in required) and neg.get('cleanup_errors')==[] and 'error' not in neg,'Complete clean 52-process native receipt required')
 require(all(neg.get(k) is False for k in n.WIDER_FLAGS),'Negative runner may not grant wider qualification')
 require(neg.get('flow_receipt')==str(flow_path) and neg.get('base_run')==flow['base_run'] and neg.get('project')==flow['project'] and neg.get('content_version')==CONTENT and neg.get('engine_sha256')==flow['engine_sha256'] and neg.get('import_receipts')==flow['import_receipts'],'Both runs must consume the exact same frozen source and own cold import')
 require(neg.get('candidate_script_count')==26 and neg.get('native_asset_count')==1 and neg.get('actual_process_count')==52,'Exact native cohort shape required')
 plan=a.static_plan();steps=neg.get('steps',[]);reports=neg.get('reports',[]);attempts=neg.get('attempts',[])
 require(len(steps)==len(reports)==len(attempts)==len(plan)==52 and a.fixture.hex_text(neg.get('batch_nonce'),32),'All actual 52 native stages required')
 pins=dict(named);producer_pins,binary_producer=frozen_pin_map(flow_path.parent,flow['pinned_files']);consumer_pins,binary_consumer=frozen_pin_map(run,neg['pinned_files'])
 n.prep.merge_pins(pins,producer_pins);n.prep.merge_pins(pins,consumer_pins);p.pin(flow_path,pins);p.pin(negative_path,pins)
 # Reuse the exact frozen consumer implementation whose validation is called.
 for name,digest in n.source_pins().items():require(neg['pinned_files'].get(name)==digest,'Current consumer contract differs from actual frozen consumer')
 for module in (n,a,p,n.prep,h,h.common,h.shared,h.identity,a.fixture):
  name=str(Path(module.__file__).resolve());require(neg['pinned_files'].get(name)==h.sha(name),'Consumer helper source differs from actual run')
 generation_path=Path(flow['base_run'])/'generation.json';require(neg['pinned_files'].get(str(generation_path))==a.pin(generation_path)['sha256'],'Actual frozen generation must be consumer-pinned')
 generation=a.document(generation_path);require('source-v1:'+generation['identity']['source_sha256']==CONTENT,'Original generated identity must be b22');files={row['path']:row for row in generation['identity']['files']}
 names=set(re.findall(r'res://scripts/[A-Za-z0-9_]+\.gd',a.raw(NEG/'component_worker.gd').decode('utf-8')))
 names.update('res://scripts/'+name+'.gd' for name in ('run_level8_world_factory','run_content_identity','run_campaign_progress_gate','run_battle_barrier'))
 source_map={name:files[name.removeprefix('res://')]['sha256'] for name in sorted(names)}
 for name,digest in source_map.items():require(neg['pinned_files'].get(str(Path(neg['project'])/name.removeprefix('res://')))==digest,'Native component script must match original frozen generation')
 state={'content_version':CONTENT,'engine_sha256':neg['engine_sha256'],'component_source_pins':source_map}
 seen=set();nonces=set();cohort=[];total_checks=0
 for index,(planned,step,summary,attempt) in enumerate(zip(plan,steps,reports,attempts),1):
  role,family=planned['first_role'],planned['family'];case=planned.get('case','')
  stage=run/(str(index).zfill(2)+'_'+role+'_'+family+('_'+case if case else ''))
  request_path=stage/'request.json';request=a.document(request_path)
  require(neg['pinned_files'].get(str(request_path))==a.pin(request_path)['sha256'],'Exact original request bytes required')
  profile=str(Path(ROOT.anchor)/'CodexQA/dn52'/neg['batch_nonce'][:12]/str(index).zfill(2));nonce=request.get('consumer_process_nonce')
  require(a.fixture.hex_text(nonce,32) and nonce not in nonces,'Unique actual consumer nonce required');nonces.add(nonce)
  expected=dict(inputs[role]);expected.update(family=family,case=case,expected_code=planned.get('expected_code',''),consumer_batch_nonce=neg['batch_nonce'],consumer_process_nonce=nonce,consumer_profile=profile,source_pins=source_map)
  require(request==expected,'Original request must bind the exact closed producer, planned case and private consumer')
  expected_attempt={'index':index,'first_role':role,'family':family,'case':case,'profile':profile,'process_nonce':nonce}
  require(attempt==expected_attempt and all(step.get(k)==v and summary.get(k)==v for k,v in expected_attempt.items()),'Actual process/summary/attempt order differs')
  report_path=stage/'report.json';require(summary.get('path')==str(report_path) and summary.get('sha256')==a.pin(report_path)['sha256']==neg['pinned_files'].get(str(report_path)),'Original actual report bytes required')
  report=a.document(report_path);n.validate_report(report,request,step,stage,state,seen)
  require(summary.get('passed') is True and summary.get('checks')==len(report['checks']),'Complete native report count required')
  for item in report.get('evidence',[]):require(neg['pinned_files'].get(item['path'])==item['sha256'],'Every actual row artifact must be final consumer-pinned')
  total_checks+=len(report['checks']);cohort.append({'stage':index+9,'first_role':role,'family':family,'case':case,'pid':step['pid'],'process_nonce':nonce,'checks':len(report['checks']),'report_sha256':summary['sha256']})
 require(len(seen)==len(nonces)==52,'All 52 independent actual consumers required')
 flow_nonces={report['process_nonce'] for report in [a.document(row['path']) for row in flow['reports']]}
 require(len(flow_nonces)==8 and not flow_nonces.intersection(nonces),'Actual Flow and negative process nonce cohorts must be independent')
 cold=a.document(Path(flow['import_receipts'][0]));require(len(cold['steps'])==1 and cold['steps'][0]['exit_code']==0 and cold['steps'][0]['errors']==[],'Original own cold import stage required')
 # Every source/report pin is reread after the complete audit; no mutable
 # business tree, current engine lane, or executable bytes were opened.
 p.verify_pins(pins)
 return {'schema':'daming_same_source_61_evidence_qualification_v1','complete':True,'full_61_qualified':True,'qualification_scope':'only frozen b22 Daming own cold + actual two-role Flow + original 52 negatives',
  'source_identity':CONTENT,'base_run':flow['base_run'],'project':flow['project'],'engine_sha256':flow['engine_sha256'],'candidate_manifest_sha256':flow['candidate_manifest_sha256'],
  'stage_counts':{'own_cold_import':1,'actual_flow':8,'actual_negative':52,'total':61},'negative_checks':total_checks,'original_receipts':{'flow':a.pin(flow_path),'negative':a.pin(negative_path),'cold':a.pin(Path(flow['import_receipts'][0]))},
  'flow_stages':[{'first_role':row['first_role'],'mode':row['mode'],'pid':step['pid'],'report_sha256':row['sha256'],'checks':row['checks']} for row,step in zip(flow['reports'],flow['steps'])],
  'negative_stages':cohort,'source_and_evidence_pins':pins,'binary_hash_metadata_only':binary_producer+binary_consumer,'current_project_full_rehash_performed':False,
  'engine_started':False,'profile_created':False,'physical_live_profiles_read':False,'business_payloads_copied':False,**{k:False for k in FALSE_FLAGS}}


def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify',action='store_true');parser.add_argument('--flow-receipt',type=Path);parser.add_argument('--negative-receipt',type=Path);parser.add_argument('--write-proof',action='store_true');args=parser.parse_args()
 if args.verify and not (args.flow_receipt and args.negative_receipt):parser.error('--verify requires both original completed receipts')
 if not args.verify and (args.flow_receipt or args.negative_receipt or args.write_proof):parser.error('Receipt/proof options require --verify')
 pins=source_pins()
 if not args.verify:
  print(json.dumps({'validation_level':'named_sources_only','named_pins':len(pins),'stage_counts':[1,8,52],'full_61_qualified':False,'engine_started':False,'profile_created':False,'output_created':False}));return
 result=verify(args.flow_receipt,args.negative_receipt,pins)
 if args.write_proof:
  output=ROOT/'.godot/daming61_qualification_20261027'/h.stamp();h.identity.no_links(p.fs(output));p.fs(output).mkdir(parents=True,exist_ok=False);h.save(p.fs(output/'receipt.json'),result);result['proof_output']=str(output)
 print(json.dumps({k:v for k,v in result.items() if k not in ('source_and_evidence_pins','binary_hash_metadata_only','negative_stages','flow_stages')},ensure_ascii=False))
if __name__=='__main__':main()
