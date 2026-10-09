"""Record independently verified stable sync for the candidate checkpoint."""
from pathlib import Path
import hashlib,json,subprocess

ROOT=Path(__file__).resolve().parents[3]
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    source='e51422a73a2981c18838309a117ac2333bcc7801';branch='codex/sync-20260905-stable'
    assert git('rev-parse','HEAD')==source==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--name-only') and not git('diff','--cached','--name-only')
    review_path=ROOT.parent/'qa-ordinary-posture-20261006/wu_death_sync_review_v8.json'
    review=json.loads(review_path.read_text(encoding='utf-8'))
    for row in review['files']:
        assert sha(ROOT/row['path'])==row['sha256']
        assert git('rev-parse',source+':'+row['path'])==row['git_expected_blob']
    receipt={'repository':'https://github.com/winterzh/Liangshan-Heroes.git','branch':branch,
             'source_commit':source,'independently_read_remote_sha':source,'verified':True,
             'whitelisted_files':59,'bytes':review['bytes'],'review_receipt':str(review_path),'review_sha256':sha(review_path),
             'completed_skill_stage_checks':61,'completed_skill_stage_captures':8,
             'native_jobs':9,'selected_sources':5,'selected_poses':12,'resources':4,
             'production_scripts_changed':False,'whole_skill_death_pilot_complete':False,
             'wu_death_default_adopted':False,'platform_released':False,
             'scope':'Candidate native assets/lineage/import and completed Lin first-skill checkpoint. Executed failed fog fixture retained. Complete v8a skill/death QA continues; no full-goal completion.',
             'metadata_followup':'This receipt and document closure have a later metadata commit; source_commit identifies the reviewed source/resource checkpoint.'}
    p=ROOT/'qa/zhu_wounded_20261005/wu_death_candidate_source_sync_v8.json';assert not p.exists()
    p.write_bytes((json.dumps(receipt,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    text='2026-10-07同步收据：本轮59白名单文件（24,434,909字节）已提交并推送stable，独立回读远端e51422a73a2981c18838309a117ac2333bcc7801一致；qa/zhu_wounded_20261005/wu_death_candidate_source_sync_v8.json记录候选范围与实际资格。生产源码未改，新death仍未默认接入；完整技能/死亡批继续。文档收尾是后续元数据提交。\n\n'
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;old=p.read_text(encoding='utf-8');assert '本轮59白名单文件' not in old;p.write_bytes((text+old).encode('utf-8'))
    print(json.dumps({'verified_remote_sha':source,'files':59,'bytes':review['bytes']}))

if __name__=='__main__':main()
