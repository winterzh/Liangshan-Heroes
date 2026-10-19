"""Own-page browser QA through Playwright and pre-existing Edge, isolated from user profiles."""
from pathlib import Path
import argparse,base64,datetime,hashlib,importlib.metadata,json,shutil,subprocess,sys,time,urllib.request
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('--deps');parser.add_argument('--output',required=True);parser.add_argument('--browser-exe',required=True)
args=parser.parse_args()
if args.deps:sys.path.insert(0,str(Path(args.deps).resolve()))
from playwright.sync_api import sync_playwright,TimeoutError as PlaywrightTimeout
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(args.output).resolve()
assert not E.is_relative_to(R) and not E.exists();E.mkdir(parents=True)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name in ['viewer.html','fixture.json','viewer.js','viewer.template.html','build_preview.py','serve_preview.py','run_playwright.py','requirements.preview.txt']:
    shutil.copyfile(Q/name,E/name)
fixture=json.loads((E/'fixture.json').read_text(encoding='utf-8'));html=E/'viewer.html';ready=E/'server_ready.json';port=8769
flags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0
def profile_processes():
    literal=str(E/'profile').replace("'","''")
    command="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId,ParentProcessId,Name,CreationDate,CommandLine | ConvertTo-Json -Compress"
    raw=subprocess.check_output(['powershell','-NoProfile','-Command',command],creationflags=flags).decode('utf-8',errors='replace').strip()
    value=json.loads(raw) if raw else [];return value if isinstance(value,list) else [value]
server_command=[sys.executable,'-X','utf8','-B',str(E/'serve_preview.py'),'--html',str(html),'--ready',str(ready),'--build-id',fixture['buildId'],'--port',str(port),'--lifetime','180']
errors=[];report={};observed=[];dom_text='';browser_version='';raw_dom='';started=datetime.datetime.now(datetime.timezone.utc).isoformat();t0=time.monotonic()
with (E/'server_stdout.log').open('xb') as out,(E/'server_stderr.log').open('xb') as err:
    server=subprocess.Popen(server_command,stdout=out,stderr=err,creationflags=flags)
    deadline=time.monotonic()+5
    while not ready.exists() and time.monotonic()<deadline:
        assert server.poll() is None,'Owned result server exited before binding';time.sleep(.05)
    assert ready.exists();state=json.loads(ready.read_text(encoding='utf-8'))
    assert state['pid']==server.pid and state['html_sha256']==sha(html)
    try:
        with sync_playwright() as playwright:
            context=playwright.chromium.launch_persistent_context(user_data_dir=str(E/'profile'),executable_path=args.browser_exe,
                headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1100},device_scale_factor=1,
                args=['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows'])
            page=context.new_page();page.on('pageerror',lambda error:errors.append(str(error)))
            browser_version=context.browser.version if context.browser else 'persistent-context'
            observed=profile_processes()
            print(json.dumps({'server_pid':server.pid,'browser_pids':[p['ProcessId'] for p in observed],'browser_version':browser_version,'run':str(E)}),flush=True)
            response=page.goto(f'http://127.0.0.1:{port}/viewer.html?qa=1&nohold=1',wait_until='domcontentloaded')
            assert response and response.status==200
            while True:
                try:
                    page.wait_for_function("() => { const e=document.getElementById('qa-evidence'); if(!e)return false; const r=JSON.parse(e.textContent); return r.completed===true || r.status==='error'; }",timeout=10000)
                    break
                except PlaywrightTimeout:
                    print(json.dumps({'waiting_same_browser':True,'status':page.locator('#status').inner_text(),
                        'render_frames':page.locator('#framesValue').inner_text(),'browser_pids':[p['ProcessId'] for p in profile_processes()]}),flush=True)
                    if errors:break
            dom_text=page.locator('#qa-evidence').text_content() or '{}';report=json.loads(dom_text)
            page.screenshot(path=str(E/'final_page.png'),full_page=False)
            raw_dom=page.content();(E/'page_dom.html').write_text(raw_dom,encoding='utf-8')
            deadline=time.monotonic()+5
            while not (E/'posted_report.json').exists() and time.monotonic()<deadline:page.wait_for_timeout(50)
            context.close()
    finally:
        try:
            request=urllib.request.Request(f'http://127.0.0.1:{port}/stop',method='POST',headers={'X-Preview-Build':fixture['buildId']})
            with urllib.request.urlopen(request,timeout=3) as response:response.read()
        except OSError:pass
        server_code=server.wait()
remaining=profile_processes();exit_deadline=time.monotonic()+20
while remaining and time.monotonic()<exit_deadline:time.sleep(.5);remaining=profile_processes()
duration=time.monotonic()-t0
with (E/'profile_processes_observed.json').open('x',encoding='utf-8') as f:f.write(json.dumps(observed,ensure_ascii=False,indent=2)+'\n')
with (E/'profile_processes_after.json').open('x',encoding='utf-8') as f:f.write(json.dumps(remaining,ensure_ascii=False,indent=2)+'\n')
posted=E/'posted_report.json';post_matches=False
if posted.exists():
    posted_text=posted.read_text(encoding='utf-8');post_matches=posted_text==dom_text
    assert json.loads(posted_text).get('buildId')==fixture['buildId']
video_data=report.pop('videoDataURL',None);video=None
if video_data:
    assert video_data.startswith('data:video/webm')
    raw=base64.b64decode(video_data.split(',',1)[1],validate=True);video_path=E/'continuous_canvas.webm'
    with video_path.open('xb') as f:f.write(raw)
    video={'file':video_path.name,'bytes':len(raw),'sha256':sha(video_path),'scope':'Only own preview canvas, no desktop/audio capture.'}
captures=report.pop('captures',[]);trace=report.pop('trace',[]);capture_rows=[]
for index,row in enumerate(captures):
    assert row['name'] in ['normal','half','stopped_first','resumed','fast','stopped_second','resumed_half','final_settled']
    raw=base64.b64decode(row.pop('dataURL').split(',',1)[1],validate=True);path=E/f'capture_{index:02d}_{row["name"]}.png'
    with path.open('xb') as f:f.write(raw)
    with Image.open(path) as im:assert im.size==(1600,520)
    capture_rows.append({**row,'file':path.name,'bytes':len(raw),'sha256':sha(path)})
with (E/'trace.json').open('x',encoding='utf-8') as f:f.write(json.dumps(trace,separators=(',',':'))+'\n')
with (E/'browser_report.json').open('x',encoding='utf-8') as f:f.write(json.dumps({**report,'captures':capture_rows,'video':video,'trace_file':'trace.json'},ensure_ascii=False,indent=2)+'\n')
receipt={'scope':'Own-page continuous Canvas2D browser candidate, not Godot/Unit/native/physical acceptance.',
    'started_utc':started,'wall_seconds':duration,'browser_executable':str(Path(args.browser_exe).resolve()),'browser_version':browser_version,
    'playwright_version':importlib.metadata.version('playwright'),'observed_browser_processes':observed,'profile_processes_terminal':not remaining,
    'server_command':server_command,'server_pid':server.pid,'server_exit_code':server_code,'page_errors':errors,
    'result_channel':'DOM plus own loopback POST','dom_and_post_identical':post_matches,'html_sha256':sha(html),'fixture_sha256':sha(E/'fixture.json'),
    'production_adopted':False,'native_accepted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'completed':report.get('completed'),'render_frames':report.get('renderFrames'),'simulated_seconds':report.get('simulatedSeconds'),
    'browser_checks_passed':report.get('browserChecksPassed'),'captures':len(capture_rows),'trace_rows':len(trace),'video_bytes':video['bytes'] if video else 0,
    'dom_and_post_identical':post_matches,'profile_processes_terminal':not remaining,'errors':errors,'stats':report.get('stats')}),flush=True)
assert report.get('completed') and report.get('browserChecksPassed') and len(capture_rows)==8 and video and observed and not remaining and not errors and post_matches
assert sha(html)==sha(Q/'viewer.html')
