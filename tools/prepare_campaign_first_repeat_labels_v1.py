"""Prepare complete successful-path first/repeat labels, without native execution."""
import argparse,ast,hashlib,json,re
from pathlib import Path
from prepare_campaign_file_fault_labels_v3 import check_arguments,IDENTITY_FIELDS

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'
GD=QA/'original19_first_repeat_candidate_v1/campaign_original19_first_repeat_v1.gd'

def pin(path):
    raw=path.read_bytes();return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}

def build():
    text=GD.read_text(encoding='utf-8')
    functions={part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',text)[1:]}
    inventory={name:check_arguments(body) for name,body in functions.items() if name!='check'}
    labels={name:[row['label_prefix'] for row in rows] for name,rows in inventory.items()}
    assert [len(labels[n]) for n in ['_run','_fresh','_restart','_read_actual_prior','_observe_actual_seal']]==[7,24,9,6,2]
    inputs=QA/'DURABLE_FULL_SOURCE_INPUTS_V7.json';data=json.loads(inputs.read_bytes())['spec']
    overlay=next(row for row in data['runtime_and_harness_overlays'] if row['runtime_path']=='scripts/levels/level1_huangnigang.gd')
    level=Path(overlay['path']);assert pin(level)=={k:overlay[k] for k in ['path','bytes','sha256']}
    actors=ast.literal_eval(re.search(r'(?m)^const SEVEN := (\[[^\n]+\])',level.read_text(encoding='utf-8')).group(1))+['bai_sheng']
    assert actors==['chao_gai','wu_yong','gongsun_sheng','liu_tang','ruan_xiaoer','ruan_xiaowu','ruan_xiaoqi','bai_sheng']
    header=labels['_run'][:3]+[labels['_run'][3]+field for field in IDENTITY_FIELDS]+labels['_run'][4:]
    fresh=labels['_fresh'];action=labels['_action'];move=labels['_move'][1]
    def order(actor):return [move+actor]
    def act(actor,name):return [action[0]+name,*order(actor),action[1]+name]
    results={};ready={}
    for mode in ['first','repeat']:
        prefix=header+([fresh[0]] if mode=='first' else labels['_read_actual_prior'])+fresh[1:6]
        prefix+=act('liu_tang','answer_yang')+[fresh[6]]+order('wu_yong')+order('bai_sheng')
        prefix+=act('liu_tang','taste_wine')+[fresh[7]]+act('liu_tang','distract_yang')+fresh[8:10]
        for index,actor in enumerate(['liu_tang','ruan_xiaowu','ruan_xiaoqi']):
            prefix+=act(actor,f'force_take_{index}_0')+act(actor,f'force_deliver_{index}_0')
        prefix+=[fresh[10]];ready[mode]=prefix.copy()
        prefix+=[fresh[11]]
        for actor in actors:prefix+=order(actor)
        prefix+=fresh[12:17]+labels['_observe_actual_seal']+fresh[17:20]
        if mode=='repeat':prefix+=[fresh[20]]
        results[mode]=prefix+fresh[21:]
    assert len(results['first'])==74 and len(results['repeat'])==80 and len(ready['first'])==52 and len(ready['repeat'])==57
    restart=header+labels['_restart'];assert len(restart)==21
    return {'schema':'original19_first_repeat_complete_label_contract_v1','GD':pin(GD),'builder':pin(Path(__file__)),'parser':pin(ROOT/'tools/prepare_campaign_file_fault_labels_v3.py'),'full_source_inputs':pin(inputs),'level':pin(level),'identity_fields_order':IDENTITY_FIELDS,'actors_order':actors,'literal_check_inventory':inventory,'header_labels':header,'complete_labels_by_mode':{**results,'restart_first':restart,'restart_repeat':restart},'preterminal_ready_labels_by_mode':ready,'expected_player_orders':{'preterminal':11,'fresh_final':19,'restart':0},'native_started':False,'approved_stages':[],'scope':'All ordered successful-route checks, including original first bytes and actual HUD, without claiming parser/native or producer qualification'}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',type=Path,required=True);args=parser.parse_args();value=build()
    with args.write.open('x',encoding='utf-8',newline='\n') as stream:json.dump(value,stream,ensure_ascii=False,indent=2);stream.write('\n')
    print(json.dumps({'source_only':True,'complete_check_counts':{k:len(v) for k,v in value['complete_labels_by_mode'].items()},'native_started':False}))

if __name__=='__main__':main()
