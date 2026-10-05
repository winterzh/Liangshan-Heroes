from pathlib import Path
import sys,subprocess,json
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
p=repo/'.gitattributes'
addition=b'\n# Current eight registered chapters and original Zhu evacuation QA\ntools/current_campaign_art_qa.gd -text -whitespace\ntools/run_current_campaign_art_qa.py -text -whitespace\nqa/current_campaign_art_20261005/** -text -whitespace\n'
assert b'tools/current_campaign_art_qa.gd -text' not in p.read_bytes();p.write_bytes(p.read_bytes()+addition)
old=Path('E:/ChatGPT/qa-zhu-captives-bound-20261005/launch_when_idle.py').read_text(encoding='utf-8')
old=old.replace('run_zhu_captives_bound_qa.py','run_current_campaign_art_qa.py').replace('zhu_captives_bound=','current_campaign_art=')
old=old.replace('E:/ChatGPT/qa-shi-qian-bound-20261005/20261005_114753_cd5cab75','E:/ChatGPT/qa-zhu-captives-bound-20261005/20261005_124323_b66e6304')
(base/'launch_when_idle.py').write_text(old,encoding='utf-8')
args=[sys.executable,'-X','utf8','-B',str(repo/'tools/run_current_campaign_art_qa.py'),'--repo',str(repo),'--manifest','current_campaign_art=assets/direction4/bound_yang_lin_20261005.json','--work-root',str(base),'--cache-from','E:/ChatGPT/qa-zhu-captives-bound-20261005/20261005_124323_b66e6304','--shared-checks']
r=subprocess.run(args,cwd=repo,capture_output=True,text=True,encoding='utf-8')
(base/'preflight.log').write_text(r.stdout+r.stderr,encoding='utf-8');print(r.stdout+r.stderr);raise SystemExit(r.returncode)
