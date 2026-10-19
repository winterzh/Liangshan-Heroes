"""Read-only SW four-pose source comparison. Does not qualify motion or edit source PNGs."""
from pathlib import Path
import argparse,base64,hashlib,importlib.metadata,json,shutil,subprocess,sys
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--deps',required=True);p.add_argument('--output',required=True);p.add_argument('--browser-exe',required=True);a=p.parse_args();sys.path.insert(0,str(Path(a.deps).resolve()))
from playwright.sync_api import sync_playwright
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(a.output).resolve();assert not E.exists() and not E.is_relative_to(R);E.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths={'v1':Q/'native_originals/attack_sw_v1.png','v2':Q/'native_originals/attack_sw_v2.png','idle':R/'qa/zou_run_canon_body_refine_20261019/native_originals/idle_v7.png'};sizes={}
for k,p in paths.items():
    with Image.open(p) as im:sizes[k]=list(im.size)
check=json.loads((Q/'frame_check_attack_sw_v2.json').read_text(encoding='utf-8'));assert check['frame_source_qualified']
urls={k:'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode('ascii') for k,p in paths.items()};defs=''.join(f'<image id="source_{k}" width="{sizes[k][0]}" height="{sizes[k][1]}" href="{urls[k]}"/>' for k in paths)
def tile(k,x,y,s,region=None):
    region=region or [0,0,*sizes[k]];return f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="#303b2d"/><svg x="{x}" y="{y}" width="{s}" height="{s}" viewBox="'+ ' '.join(map(str,region))+f'" preserveAspectRatio="xMidYMid meet" overflow="hidden"><use href="#source_{k}"/></svg>'
parts=[]
for k,x,label,region in [('v1',25,'v1：1388×1133，画布规格未过',None),('v2',620,'v2：1254方图，完整取图通过',None),('idle',1215,'既有SW待机参照（非采用证明）',[627,0,627,627])]:parts.append(f'<text x="{x}" y="82" font-size="22">{label}</text>'+tile(k,x,105,500,region))
for i,row in enumerate(check['frames']):
    x=25+i*440;parts.append(f'<text x="{x}" y="658" font-size="24">SW · {row["phase"]}</text>'+tile('v2',x,685,300,row['cell'])+tile('v2',x+325,870,48.1,row['cell']))
parts+=['<text x="25" y="1040" font-size="22">仅四主姿势，缺过渡/方向连续/自然动作；65px留白请求未在所有格实现，取图通过只限完整采样。</text>','<text x="25" y="1088" font-size="22">未本地镜像或改PNG；同一条手臂持短刀、另一手空，握持/解剖和真实Unit仍未验收。</text>']
html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><body style="margin:0;background:#182118"><svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1140"><defs>'+defs+'</defs><g fill="#eee7cf" font-family="Microsoft YaHei,sans-serif"><text x="25" y="40" font-size="28">邹润 · SW朝左短刀四主姿势候选</text>'+''.join(parts)+'</g></svg></body></html>'
(E/'sw.html').write_text(html,encoding='utf-8');shutil.copyfile(Path(__file__),E/'render_sw_intake.py');errors=[]
with sync_playwright() as pw:
    context=pw.chromium.launch_persistent_context(str(E/'profile'),executable_path=a.browser_exe,headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1140},device_scale_factor=1);version=context.browser.version;page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.goto((E/'sw.html').as_uri(),wait_until='load');page.evaluate('document.fonts.ready')
    hashes=page.evaluate("""async()=>await Promise.all([...document.querySelectorAll('image')].map(async n=>{const i=new Image();i.src=n.getAttribute('href');await i.decode();const b=Uint8Array.from(atob(i.src.split(',')[1]),c=>c.charCodeAt(0));return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(v=>v.toString(16).padStart(2,'0')).join('');}))""");assert set(hashes)=={sha(p) for p in paths.values()};assert page.locator('use').count()==11;page.screenshot(path=str(E/'sw.png'));page.close();context.close()
assert not errors
literal=str(E/'profile').replace("'","''");cmd="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId | ConvertTo-Json -Compress";assert not subprocess.check_output(['powershell','-NoProfile','-Command',cmd],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()
receipt={'scope':'Static exact-source SW intake only; no motion, physical handedness, Unit or production acceptance.','sources':{k:{'path':p.relative_to(R).as_posix(),'sha256':sha(p),'size':sizes[k]} for k,p in paths.items()},'decoded_hashes':hashes,'displayed_instances':11,'html_sha256':sha(E/'sw.html'),'screenshot_sha256':sha(E/'sw.png'),'browser_version':version,'playwright_version':importlib.metadata.version('playwright'),'page_errors':errors,'own_profile_processes_terminal':True,'production_adopted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'displayed_instances':11,'source_hashes_match':True,'own_profile_terminal':True}))
