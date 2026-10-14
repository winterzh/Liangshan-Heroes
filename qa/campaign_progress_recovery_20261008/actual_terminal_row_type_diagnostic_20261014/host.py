from pathlib import Path
import sys,json,hashlib
sys.path.insert(0,r'D:/AI项目/水浒/开发工程/tools')
from durable_campaign_full_runtime import OwnedSerialBatch,write_new,sha,no_links
root=Path(r'D:/AI项目/水浒/开发工程');q=root/'qa/campaign_progress_recovery_20261008/terminal_file_row_candidate_v1'
review=q/'TERMINAL_ROW_PRELIMINARY_REVIEW_V1.json';raw=review.read_bytes();assert hashlib.sha256(raw).hexdigest()=='ed19d6fd8c8842dd76d860464daee5d2b961efe5a7367696212bfa31a4792daa';d=json.loads(raw)
assert d['approved_stages']==['read_only_json_type_diagnostic'] and d['independent'] is True
pins=list(d['source_pins'].values())+[{'path':str(q/'SOURCE.json'),'bytes':1350,'sha256':d['source_manifest_sha256']},{'path':str(review),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}]
run=Path(r'D:/CodexTemp/lsh-terminal-row-type-probe-native-20261014');no_links(run);run.mkdir(exist_ok=False)
scratch=run/'empty_scratch';scratch.mkdir();assert not (scratch/'project.godot').exists()
class Frozen:
    project=scratch
    def check(self):
        assert not (scratch/'project.godot').exists()
        for p in pins:
            f=Path(p['path']);no_links(f);assert f.stat().st_size==p['bytes'] and sha(f)==p['sha256']
f=Frozen();receipt={'schema':'actual_terminal_row_type_diagnostic_v1','complete':False,'full_chain_qualified':False,'overall_goal_qualified':False,'source_pins':pins}
def persist():
    receipt['steps']=batch.steps
    (run/'checkpoint.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
batch=OwnedSerialBatch(run,f,Path(r'C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe'),'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00',persist,600)
def validate(step,out,nonce):
    log=(out/'native.log').read_text('utf-8');line=next(s for s in log.splitlines() if s.startswith('TERMINAL_ROW_TYPE_DIAGNOSTIC '));v=json.loads(line.split(' ',1)[1]);assert v=={'live_bytes_type':2,'JSON_bytes_type':3,'direct_dictionary_equal':False,'normalized_fields_equal':True};receipt['actual_observation']=v
try:
    batch.phase('json_type_diagnostic',batch.profile('json_type_diagnostic'),['--headless','--script',str(q/'json_file_row_type_probe_v1.gd')],{},validate,60)
    receipt['complete']=True
finally:
    batch.release();receipt['lock_released']=not batch.locked;persist();write_new(run/'receipt.json',receipt)
print(json.dumps({'complete':receipt['complete'],'run':str(run),'overall_goal_qualified':False}))
