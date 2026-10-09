"""Seal full successful native check order for six faults and ordinary restart.

Source preparation only; no Godot process or execution admission.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'
GD=QA/'original19_natural_file_faults_candidate_v4/campaign_original19_natural_file_faults_v4.gd'
LEVEL=QA/'huangniganggang_unused'  # Assigned from fixed current full-source overlay.
IDENTITY_FIELDS=['content_version','rules_sha256','file_count','total_bytes','engine_binary_sha256','provider_sha256']
CASES=['bad_existing_cfg_load','existing_vanished_prior','write_failure','save_OK_fresh_load_failure','readback_semantic_mismatch','readback_SHA_changed']


def pin(path):
    raw=path.read_bytes(); return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def check_arguments(body):
    rows=[]
    for match in re.finditer(r'\bcheck\(',body):
        start=match.end();depth=0;quoted=False;escaped=False;parts=[];part=start
        for index in range(start,len(body)):
            char=body[index]
            if quoted:
                if escaped:escaped=False
                elif char=='\\':escaped=True
                elif char=='"':quoted=False
                continue
            if char=='"':quoted=True
            elif char in '([{':depth+=1
            elif char in ')]}':
                if char==')' and depth==0:
                    parts.append(body[part:index].strip());break
                depth-=1
            elif char==',' and depth==0:parts.append(body[part:index].strip());part=index+1
        assert len(parts) in [2,3],parts
        literal=re.match(r'"(?:[^"\\]|\\.)*"',parts[1]);assert literal,parts
        rows.append({'label_prefix':json.loads(literal.group()),'label_expression':parts[1],'check_expression':parts[0]})
    return rows


def build():
    text=GD.read_text(encoding='utf-8');assert pin(GD)['sha256']=='395ce698af1f6ac9c4eca892e5264b98c892cc1cd8cc8e8d93b14d380e642606'
    functions={part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',text)[1:]}
    inventory={name:check_arguments(body) for name,body in functions.items() if name!='check'}
    labels={name:[r['label_prefix'] for r in rows] for name,rows in inventory.items()}
    assert [len(labels[name]) for name in ['_run','_fresh','_restart','_seed_actual_cfg','_fault_ready','_exercise_actual_file_fault']]==[7,23,8,4,2,21]
    inputs=QA/'DURABLE_FULL_SOURCE_INPUTS_V7.json';data=json.loads(inputs.read_bytes())['spec']
    overlay=next(r for r in data['runtime_and_harness_overlays'] if r['runtime_path']=='scripts/levels/level1_huangnigang.gd')
    level=Path(overlay['path']);assert pin(level)=={k:overlay[k] for k in ['path','bytes','sha256']}
    level_text=level.read_text(encoding='utf-8')
    actors=ast.literal_eval(re.search(r'(?m)^const SEVEN := (\[[^\n]+\])',level_text).group(1))+['bai_sheng']
    assert actors==['chao_gai','wu_yong','gongsun_sheng','liu_tang','ruan_xiaoer','ruan_xiaowu','ruan_xiaoqi','bai_sheng']
    header=labels['_run'][:3]+[labels['_run'][3]+field for field in IDENTITY_FIELDS]+labels['_run'][4:]
    fresh=labels['_fresh'];action=labels['_action'];move=labels['_move'][1]
    def order(actor):return [move+actor]
    def act(actor,name):return [action[0]+name,*order(actor),action[1]+name]
    before_ready=header+fresh[:2]+labels['_seed_actual_cfg']+fresh[2:6]
    before_ready+=act('liu_tang','answer_yang')+[fresh[6]]+order('wu_yong')+order('bai_sheng')
    before_ready+=act('liu_tang','taste_wine')+[fresh[7]]+act('liu_tang','distract_yang')+fresh[8:10]
    for index,actor in enumerate(['liu_tang','ruan_xiaowu','ruan_xiaoqi']):
        before_ready+=act(actor,f'force_take_{index}_0')+act(actor,f'force_deliver_{index}_0')
    before_ready+=[fresh[10]];assert len(before_ready)==56
    prefix=before_ready+[fresh[11]]+labels['_fault_ready']
    for actor in actors:prefix+=order(actor)
    prefix+=[fresh[12]];assert len(prefix)==68
    branches={};fault=labels['_exercise_actual_file_fault']
    for case in CASES:
        prepared=case not in CASES[:2]
        middle=fault[:8]+[fault[8] if prepared else fault[9]]
        if prepared:middle+=[fault[10]]
        middle+=fault[11:14]
        if prepared:middle+=[fault[14]]
        middle+=fault[15:19]
        if prepared:middle+=[fault[19]]
        middle+=[fault[20]]
        branches[case]=prefix+middle+fresh[13:]
        assert len(branches[case])==(98 if prepared else 95)
    return {'schema':'campaign_original19_file_fault_full_label_contract_v1','GD':pin(GD),'level':pin(level),'full_source_inputs':pin(inputs),
            'builder':pin(Path(__file__)),'identity_fields_order':IDENTITY_FIELDS,'actors_order':actors,'case_ids':CASES,
            'literal_check_inventory':inventory,'header_labels':header,'preterminal_ready_labels':before_ready,
            'fresh_labels_by_case':branches,'restart_labels':header+labels['_restart'],
            'expected_player_orders':{'preterminal':11,'fresh_final':19,'restart':0},'native_started':False,'approved_stages':[],
            'scope':'Exact complete successful-path labels, including repeated ordinary orders/actions and branch-specific retained proposal checks; source only'}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',type=Path,required=True);args=parser.parse_args()
    value=build();assert len(value['restart_labels'])==20
    with args.write.open('x',encoding='utf-8',newline='\n') as stream:stream.write(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'source_only':True,'fresh_checks':{case:len(labels) for case,labels in value['fresh_labels_by_case'].items()},'restart_checks':20}))


if __name__=='__main__':main()
