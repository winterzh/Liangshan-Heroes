from pathlib import Path
import sys,json,subprocess
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
s=Path('E:/ChatGPT/qa-shi-qian-bound-20261005/launch_when_idle.py').read_text(encoding='utf-8')
s=s.replace('run_shi_qian_bound_qa.py','run_zhu_captives_bound_qa.py').replace('bound_shi_qian=assets/direction4/bound_shi_qian_20261005.json','zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json').replace('E:/ChatGPT/qa-qin-ming-bound-20261005/20261005_105513_18f269d0','E:/ChatGPT/qa-shi-qian-bound-20261005/20261005_114753_cd5cab75')
(base/'launch_when_idle.py').write_text(s,encoding='utf-8')
r=subprocess.run([sys.executable,'-X','utf8','-B',str(repo/'tools/run_zhu_captives_bound_qa.py'),'--repo',str(repo),'--work-root',str(base),'--manifest','zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json','--shared-checks'],capture_output=True,text=True,encoding='utf-8')
(base/'preflight.log').write_text(r.stdout+r.stderr,encoding='utf-8');assert r.returncode==0,r.stdout+r.stderr
print(r.stdout[-1000:])
