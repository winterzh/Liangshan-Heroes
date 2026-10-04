from pathlib import Path
import subprocess,sys,json,hashlib
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
r=subprocess.run([sys.executable,'-X','utf8','-B',str(repo/'tools/character_art_lock_selftest.py')],cwd=repo,capture_output=True,text=True,encoding='utf-8')
assert r.returncode==0,r.stderr
record=json.loads(r.stdout);assert record['passed']
record['script_sha256']=hashlib.sha256((repo/'tools/character_art_lock_selftest.py').read_bytes()).hexdigest()
record['driver_sha256']=hashlib.sha256((repo/'tools/run_character_art_qa.py').read_bytes()).hexdigest()
out=repo/'qa/han_tao_captured_20261005/lock_selftest.json'
out.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'passed':record['passed'],'checks':len(record['checks'])}))
