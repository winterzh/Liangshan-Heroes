"""Headless screenshot of our own localhost QA page, isolated from user browsers."""
from pathlib import Path
import datetime,hashlib,json,shutil,subprocess,time,uuid
Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/browser')
browser=Path('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe');assert browser.is_file()
shutil.copyfile(Q/'layer_preview.html',E/'index.html')
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
O=E/'captures'/stamp;O.mkdir(parents=True)
receipt={'complete':False,'scope':'Own localhost HTML canvas screenshots only, not native Godot/Unit/package acceptance. No PNG art source edits or user browser access.','browser':str(browser),'html_sha256':hashlib.sha256((E/'index.html').read_bytes()).hexdigest(),'steps':[]}
try:
    for mode in ['original', 'sheathed_idle', 'reach', 'draw_mid', 'point', 'drawn_recoil', 'drawn_recover', 'sheathed_recoil', 'sheathed_recover']:
        image=O/(mode+'.png');profile=O/('profile_'+mode)
        command=[str(browser),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--window-size=1440,900','--virtual-time-budget=3000','--user-data-dir='+str(profile),'--screenshot='+str(image),'http://127.0.0.1:18765/?mode='+mode]
        with (O/(mode+'.stdout.log')).open('xb') as out,(O/(mode+'.stderr.log')).open('xb') as err:
            child=subprocess.Popen(command,stdout=out,stderr=err)
            try:code=child.wait(timeout=50)
            except subprocess.TimeoutExpired:child.terminate();child.wait(timeout=10);raise
        dom=(O/(mode+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
        # Edge's launcher may exit before the owned headless renderer finishes.
        # Observe the same pending capture rather than restarting its command.
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            if image.is_file() and image.stat().st_size>100000:
                from PIL import Image
                try:
                    with Image.open(image) as png:png.verify()
                    break
                except (OSError,SyntaxError):pass
            time.sleep(.2)
        assert image.is_file() and image.stat().st_size>100000,(mode,code)
        receipt['steps'].append({'mode':mode,'command':command,'pid':child.pid,'exit_code':code,'screenshot':str(image),'screenshot_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'image_load_status_manual_review_required':True})
    receipt['complete']=True
except BaseException as error:receipt['error']=repr(error)
finally:
    (O/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (E/'latest_browser_capture.json').write_text(json.dumps({'receipt':str(O/'receipt.json')})+'\n',encoding='utf-8')
print(json.dumps({'complete':receipt['complete'],'output':str(O),'error':receipt.get('error')}));assert receipt['complete']
