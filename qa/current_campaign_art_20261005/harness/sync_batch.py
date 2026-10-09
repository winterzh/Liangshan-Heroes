"""Whitelist stage reviewed current-campaign evidence, verify exact bytes, push stable/read back."""
from pathlib import Path
import hashlib,json,subprocess,sys,re
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;qa=repo/'qa/current_campaign_art_20261005'
branch='codex/sync-20260905-stable';baseline='5eb48b108e66ed129dddd982984df535d0226b8f';main='6085f89f6c0c840e45228f68af6acc1d6ca6a5ed'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=repo,text=True,encoding='utf-8').strip()
def call(*args):
    r=subprocess.run(['git',*args],cwd=repo,text=True,encoding='utf-8',capture_output=True)
    assert r.returncode==0,r.stdout+'\n'+r.stderr
    return r.stdout
assert git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git' and git('branch','--show-current')==branch
assert git('rev-parse','HEAD')==git('ls-remote','origin','refs/heads/'+branch).split()[0]==baseline
assert git('ls-remote','origin','refs/heads/main').split()[0]==main and not git('diff','--cached','--name-only')
r=json.loads((qa/'final/receipt.json').read_text(encoding='utf-8'));v=json.loads((qa/'visual_review.json').read_text(encoding='utf-8'));clean=json.loads((qa/'cleanup.json').read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and v['complete'] and v['passed'] and len(v['screenshots'])==12 and clean['complete'] and clean['protected_sha_unchanged']
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as driver
assert not driver.source_changes(repo,r['source_files'])
assert sha(repo/'tools/current_campaign_art_qa.gd')==r['qa_sha256'] and sha(repo/'tools/run_character_art_qa.py')==r['driver_sha256']
for a in r['artifacts']:assert sha(qa/'final'/a['path'])==a['sha256']
for a in json.loads((qa/'artifact_index.json').read_text(encoding='utf-8'))['artifacts']:assert sha(qa/a['path'])==a['sha256']
paths=['.gitattributes','tools/current_campaign_art_qa.gd','tools/run_current_campaign_art_qa.py']
paths+=[p.relative_to(repo).as_posix() for p in (repo/'tools/contracts/current_campaign_opening_20261005').rglob('*') if p.is_file()]
paths+=['docs/'+name for name in ['WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','ART_COMPLETION_20260926.md','CAMPAIGN_ART.md','CAMPAIGN_ART_REQUIREMENTS_20260902.md','CURRENT_CAMPAIGN_ART_20261005.md']]
paths+=[p.relative_to(repo).as_posix() for p in qa.rglob('*') if p.is_file()]
paths=sorted(set(paths));audit=[]
for name in paths:
    p=repo/name
    assert p.stat().st_size<50*1024*1024 and not any(x in {'.git','.godot','profiles','__pycache__'} for x in p.relative_to(repo).parts)
    if p.suffix!='.png':
        assert not re.search(r'(?im)^-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:ghp_|github_pat_|sk-proj-)[A-Za-z0-9_-]{20,}',p.read_text(encoding='utf-8')),name
    audit.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p)})
for i in range(0,len(paths),40):call('add','-f','--',*paths[i:i+40])
assert set(git('diff','--cached','--name-only').splitlines())==set(paths)
call('diff','--cached','--check')
for row in audit:
    # In particular all runtime/QA inputs must remain exactly as verified.
    blob=subprocess.check_output(['git','show',':'+row['path']],cwd=repo)
    row['staged_sha256']=hashlib.sha256(blob).hexdigest()
    if row['path'].startswith(('assets/','scripts/','tools/','qa/')):
        assert row['staged_sha256']==row['sha256'],row['path']
    else:
        assert blob==(repo/row['path']).read_bytes() or blob==(repo/row['path']).read_bytes().replace(b'\r\n',b'\n'),row['path']
(base/'staging_audit.json').write_text(json.dumps({'complete':True,'baseline':baseline,'branch':branch,'files':audit,'exact_runtime_and_qa_bytes_preserved':True,'documentation_line_endings_only_may_follow_git_text_filter':True},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
call('commit','-m','Inventory current campaign openings and verify original seven prisoner evacuation')
commit=git('rev-parse','HEAD');assert git('ls-remote','origin','refs/heads/'+branch).split()[0]==baseline
call('push','origin','HEAD:'+branch)
remote=git('ls-remote','origin','refs/heads/'+branch).split()[0]
assert remote==commit and git('ls-remote','origin','refs/heads/main').split()[0]==main
status=git('status','--short')
report=json.loads((qa/'final/current_campaign_art/report.json').read_text(encoding='utf-8'))
result={'complete':True,'branch':branch,'local_commit':commit,'remote_commit':remote,'main_unchanged':True,'working_tree_clean':not status,'remaining_status':status,'files':len(paths),'bytes':sum(x['bytes'] for x in audit),'qa_checks':report['checks'],'routing_checks':8,'screens_reviewed':12,'frozen_inputs':len(r['source_files']),'cleanup_removed_files':clean['removed_files'],'cleanup_removed_bytes':clean['removed_bytes'],'packages_or_platform_published':False,'goal_complete':False}
(base/'sync_receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,ensure_ascii=False))
