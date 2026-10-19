"""Run owned HTML in pre-existing isolated headless Edge; retain DOM, logs and captures."""
from pathlib import Path
import base64,datetime,hashlib,json,shutil,subprocess,sys,time
from bs4 import BeautifulSoup
from PIL import Image
Q=Path(__file__).resolve().parent
E=Path(sys.argv[1]).resolve()
assert E.is_relative_to(Path('D:/CodexEvidence/shuihu/yang_lin_continuous_preview_20261019').resolve()) and not E.exists()
E.mkdir(parents=True)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name in ['viewer.html','fixture.json','viewer.js','viewer.template.html','build_preview.py','serve_preview.py','run_preview.py']:
    shutil.copyfile(Q/name,E/name)
html=E/'viewer.html';ready=E/'server_ready.json';port=8769
server_command=[sys.executable,'-X','utf8','-B',str(E/'serve_preview.py'),'--html',str(html),'--ready',str(ready),'--port',str(port)]
creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0
with (E/'server_stdout.log').open('xb') as stdout,(E/'server_stderr.log').open('xb') as stderr:
    server=subprocess.Popen(server_command,stdout=stdout,stderr=stderr,creationflags=creationflags)
    deadline=time.monotonic()+5
    while not ready.exists() and time.monotonic()<deadline:
        assert server.poll() is None, 'Owned preview server exited before binding'
        time.sleep(.05)
    assert ready.exists();state=json.loads(ready.read_text(encoding='utf-8'))
    assert state['pid']==server.pid and state['html_sha256']==sha(html)
    command=['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--disable-background-timer-throttling','--disable-renderer-backgrounding','--hide-scrollbars','--force-device-scale-factor=1','--window-size=1800,1100','--timeout=22000','--dump-dom','--user-data-dir='+str(E/'profile'),'--screenshot='+str(E/'final_page.png'),f'http://127.0.0.1:{port}/viewer.html?qa=1']
    started=datetime.datetime.now(datetime.timezone.utc).isoformat();t0=time.monotonic()
    with (E/'page_dom.html').open('xb') as out,(E/'browser_stderr.log').open('xb') as err:
        browser=subprocess.Popen(command,stdout=out,stderr=err,creationflags=creationflags)
        print(json.dumps({'browser_pid':browser.pid,'server_pid':server.pid,'run':str(E)}),flush=True)
        code=browser.wait()
    duration=time.monotonic()-t0
    server_code=server.wait()
dom=(E/'page_dom.html').read_text(encoding='utf-8',errors='replace');soup=BeautifulSoup(dom,'html.parser');node=soup.find('script',id='qa-evidence')
report=json.loads(node.get_text()) if node else {'completed':False,'status':'missing_evidence'}
captures=report.pop('captures',[]);trace=report.pop('trace',[]);capture_rows=[]
for index,row in enumerate(captures):
    raw=base64.b64decode(row.pop('dataURL').split(',',1)[1],validate=True);path=E/f'capture_{index:02d}_{row["name"]}.png'
    with path.open('xb') as stream:stream.write(raw)
    with Image.open(path) as im:assert im.size==(1600,520)
    capture_rows.append({**row,'file':path.name,'sha256':sha(path),'bytes':len(raw)})
with (E/'trace.json').open('x',encoding='utf-8') as f:f.write(json.dumps(trace,separators=(',',':'))+'\n')
with (E/'browser_report.json').open('x',encoding='utf-8') as f:f.write(json.dumps({**report,'captures':capture_rows,'trace_file':'trace.json'},ensure_ascii=False,indent=2)+'\n')
receipt={'scope':'Owned continuous browser candidate, no Godot/Unit/native qualification.',
         'started_utc':started,'wall_seconds':duration,'command':command,'browser_pid':browser.pid,'browser_exit_code':code,
         'server_command':server_command,'server_pid':server.pid,'server_exit_code':server_code,
         'html_sha256':sha(html),'fixture_sha256':sha(E/'fixture.json'),'dom_sha256':sha(E/'page_dom.html'),
         'production_adopted':False,'native_accepted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'browser_exit_code':code,'server_exit_code':server_code,'wall_seconds':duration,
                  'completed':report.get('completed'),'render_frames':report.get('renderFrames'),
                  'simulated_seconds':report.get('simulatedSeconds'),'browser_checks_passed':report.get('browserChecksPassed'),
                  'captures':len(capture_rows),'trace_rows':len(trace),'status':report.get('status'),'error':report.get('error')}),flush=True)
assert code==0 and server_code==0 and report.get('completed') and report.get('browserChecksPassed') and len(capture_rows)==8
assert sha(html)==sha(Q/'viewer.html')
