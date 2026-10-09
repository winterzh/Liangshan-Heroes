"""Compose inherited natural checks and callback-only hooks; no Godot parse."""
import argparse,hashlib,json,re
from pathlib import Path
from prepare_campaign_first_repeat_labels_v1 import build as parent_contract
from prepare_campaign_file_fault_labels_v3 import check_arguments
ROOT=Path(__file__).resolve().parents[1]
GD=ROOT/'qa/campaign_progress_recovery_20261008/callback_natural_driver_candidate_v1/campaign_original19_natural_callback_v1.gd'
def pin(p):
 raw=p.read_bytes();return {'path':str(p),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
def build():
 parent=parent_contract();text=GD.read_text(encoding='utf-8');functions={part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',text)[1:]};assert set(functions)=={'_fresh','_write','_finish'}
 hooks=[r['label_prefix'] for r in check_arguments(functions['_fresh'])];finish=[r['label_prefix'] for r in check_arguments(functions['_finish'])];assert len(hooks)==4 and len(finish)==2
 n=len(parent['header_labels']);first=parent['complete_labels_by_mode']['first'];ready=parent['preterminal_ready_labels_by_mode']['first'];full=first[:n]+hooks+first[n:]+finish;ready=ready[:n]+hooks+ready[n:]
 assert len(full)==80 and len(ready)==56 and len(parent['complete_labels_by_mode']['restart_first'])==21
 return {'schema':'original19_natural_callback_complete_label_contract_v1','GD':pin(GD),'parent_GD':parent['GD'],'builder':pin(Path(__file__)),'parent_builder':parent['builder'],'parser':parent['parser'],'full_source_inputs':parent['full_source_inputs'],'level':parent['level'],'identity_fields_order':parent['identity_fields_order'],'actors_order':parent['actors_order'],'complete_labels_by_mode':{'first':full,'restart_first':parent['complete_labels_by_mode']['restart_first']},'preterminal_ready_labels_by_mode':{'first':ready},'native_started':False,'GD_parsed':False,'approved_stages':[]}
def main():
 p=argparse.ArgumentParser();p.add_argument('--write',type=Path,required=True);a=p.parse_args();v=build()
 with a.write.open('x',encoding='utf-8',newline='\n') as f:json.dump(v,f,ensure_ascii=False,indent=2);f.write('\n')
 print(json.dumps({'source_only':True,'first_labels':80,'preterminal_labels':56,'restart_labels':21,'native_started':False}))
if __name__=='__main__':main()
