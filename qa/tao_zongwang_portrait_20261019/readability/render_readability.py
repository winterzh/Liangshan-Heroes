"""Own-page static comparison of original PNGs, not a Godot/HUD capture or source image edit."""
from pathlib import Path
import argparse,base64,hashlib,importlib.metadata,json,shutil,subprocess,sys
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('--deps',required=True);parser.add_argument('--output',required=True);parser.add_argument('--browser-exe',required=True);args=parser.parse_args()
sys.path.insert(0,str(Path(args.deps).resolve()));from playwright.sync_api import sync_playwright
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(args.output).resolve();assert not E.is_relative_to(R) and not E.exists();E.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths={'old':R/'assets/portraits15.png','new':Q/'native_originals/portrait_v1.png','body':R/'assets/anim/tao_zongwang_walk.png'}
images={key:'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode('ascii') for key,path in paths.items()}
spec={'old':([786,401,414,377],1200,1200),'new':([0,0,1254,1254],1254,1254),'body':([0,0,256,256],1024,256)}
def tile(key,x,y,size):
    region,w,h=spec[key];view=' '.join(map(str,region))
    return f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#302820"/><svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><use href="#source_{key}"/></svg><rect x="{x}" y="{y}" width="{size}" height="{size}" fill="none" stroke="#a18a5c"/>'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1450"><rect width="1800" height="1450" fill="#171812"/><g font-family="Microsoft YaHei,sans-serif" fill="#eee6cf">','<text x="30" y="42" font-size="28">陶宗旺 · 铁锹头像候选 / 静态来源与小尺寸比较</text>']
for key,x,label in [('old',30,'现用头像区域'),('new',600,'新头像原稿'),('body',1170,'现用走路身体 · 首帧')]:
    svg.append(f'<text x="{x}" y="85" font-size="24">{label}</text>'+tile(key,x,108,512))
for key,y,label in [('new',710,'新候选'),('old',1080,'现用头像')]:
    svg.append(f'<text x="30" y="{y-30}" font-size="24">{label} · 原图直接等比显示</text>');x=30
    for size in [256,128,96,64,32]:
        svg.append(tile(key,x,y,size)+f'<text x="{x}" y="{y+size+25}" font-size="20">{size}px</text>');x+=size+100
svg.append('<text x="30" y="1400" font-size="22">第41回：庄家田户出身，惯使铁锹；须发衣色属美术解释。浏览器比较不是游戏HUD/原生验收。</text></g></svg>')
svg.insert(1,'<defs>'+''.join(f'<image id="source_{key}" href="{images[key]}" width="{spec[key][1]}" height="{spec[key][2]}"/>' for key in paths)+'</defs>')
html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>陶宗旺头像候选</title><body style="margin:0;background:#171812">'+''.join(svg)+'</body></html>'
(E/'review.html').write_text(html,encoding='utf-8');shutil.copyfile(Q/'render_readability.py',E/'render_readability.py')
errors=[]
with sync_playwright() as playwright:
    context=playwright.chromium.launch_persistent_context(str(E/'profile'),executable_path=args.browser_exe,headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1450},device_scale_factor=1)
    page=context.new_page();page.on('pageerror',lambda error:errors.append(str(error)));page.goto((E/'review.html').as_uri(),wait_until='load')
    status=page.evaluate("""async () => {await document.fonts.ready;const list=[...document.querySelectorAll('image')];return await Promise.all(list.map(async e=>{const img=new Image();img.src=e.getAttribute('href');await img.decode();const raw=Uint8Array.from(atob(img.src.split(',')[1]),c=>c.charCodeAt(0));const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',raw))].map(n=>n.toString(16).padStart(2,'0')).join('');return {width:img.naturalWidth,height:img.naturalHeight,sha256:hash};}));}""")
    version=context.browser.version;page.screenshot(path=str(E/'review.png'));context.close()
assert not errors and len(status)==3
expected={sha(p) for p in paths.values()};assert {row['sha256'] for row in status}==expected
with Image.open(E/'review.png') as image:assert image.size==(1800,1450)
literal=str(E/'profile').replace("'","''");cmd="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId | ConvertTo-Json -Compress"
remaining=subprocess.check_output(['powershell','-NoProfile','-Command',cmd],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip();assert not remaining
receipt={'scope':'Static own-page PNG source comparison at 256/128/96/64/32px, not native/HUD/game/model acceptance.',
    'browser_version':version,'playwright_version':importlib.metadata.version('playwright'),'source_files':{key:{'path':path.relative_to(R).as_posix(),'sha256':sha(path)} for key,path in paths.items()},
    'displayed_image_instances':13,'browser_decoded_source_hashes':status,'legacy_region':[786,401,414,377],'page_errors':errors,'own_profile_processes_terminal':True,
    'html_sha256':sha(E/'review.html'),'screenshot_sha256':sha(E/'review.png'),'production_adopted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'screenshot':str(E/'review.png'),'decoded_image_instances':len(status),'sources_hash_match':True,'own_profile_terminal':True}))
