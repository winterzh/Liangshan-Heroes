"""Compare current production portrait, first source, refined source and body without editing PNGs."""
from pathlib import Path
import argparse,base64,hashlib,importlib.metadata,json,shutil,subprocess,sys,time
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('--hero',choices=['li_yun','zou_run'],required=True);parser.add_argument('--deps',required=True);parser.add_argument('--output',required=True);parser.add_argument('--browser-exe',required=True);args=parser.parse_args()
sys.path.insert(0,str(Path(args.deps).resolve()));from playwright.sync_api import sync_playwright
Q=Path(__file__).resolve().parent;R=Q.parents[1];P=R/'qa/li_yun_zou_run_portraits_20261019';E=Path(args.output).resolve();assert not E.is_relative_to(R) and not E.exists();E.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
info={'li_yun':{'name':'李云','sheet':'portraits17.png','region':[781,400,419,377],'note':'帽冠对齐返修；赤须绿眼仍据第43回。帽型/衣甲细节为美术设计。'},
      'zou_run':{'name':'邹润','sheet':'portraits16.png','region':[777,800,423,400],'note':'脑后隆起与发髻/布结分离返修；大小、发式属美术设计。'}}[args.hero]
paths={'production':R/'assets'/info['sheet'],'first':P/'native_originals'/f'{args.hero}_v1.png','refined':Q/'native_originals'/f'{args.hero}_v2.png','body':R/f'assets/anim/{args.hero}_walk.png'}
spec={'production':(info['region'],1200,1200),'first':([0,0,1254,1254],1254,1254),'refined':([0,0,1254,1254],1254,1254),'body':([0,0,256,256],1024,256)}
images={name:'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode('ascii') for name,path in paths.items()}
def tile(name,x,y,size):
    view=' '.join(map(str,spec[name][0]));return f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#302820"/><svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><use href="#source_{name}"/></svg><rect x="{x}" y="{y}" width="{size}" height="{size}" fill="none" stroke="#a18a5c"/>'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1450"><rect width="1800" height="1450" fill="#171812"/>','<defs>'+''.join(f'<image id="source_{name}" href="{images[name]}" width="{spec[name][1]}" height="{spec[name][2]}"/>' for name in paths)+'</defs>',
    f'<g font-family="Microsoft YaHei,sans-serif" fill="#eee6cf"><text x="30" y="42" font-size="28">{info["name"]} · 首稿与返修稿 / 静态比较，尚未游戏采用</text>']
for name,x,label in [('production',30,'生产现用区域'),('first',470,'首稿 v1'),('refined',910,'返修 v2'),('body',1350,'生产走图首帧')]:svg.append(f'<text x="{x}" y="85" font-size="24">{label}</text>'+tile(name,x,108,400))
for name,y,label in [('refined',620,'返修 v2'),('first',1010,'首稿 v1')]:
    svg.append(f'<text x="30" y="{y-30}" font-size="24">{label} · 原图直接等比显示</text>');x=30
    for size in [256,128,96,64,32]:
        svg.append(tile(name,x,y,size)+f'<text x="{x}" y="{y+size+25}" font-size="20">{size}px</text>');x+=size+100
svg.append(f'<text x="30" y="1390" font-size="22">{info["note"]}</text><text x="30" y="1430" font-size="21">只比较原稿/取图与缩小阅读，不是Godot、真实HUD/图鉴、包内或性能验收。原PNG未改像素。</text></g></svg>')
html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>头像返修比较</title><body style="margin:0;background:#171812">'+''.join(svg)+'</body></html>'
(E/'review.html').write_text(html,encoding='utf-8');shutil.copyfile(Q/'render_comparison.py',E/'render_comparison.py');errors=[]
with sync_playwright() as playwright:
    context=playwright.chromium.launch_persistent_context(str(E/'profile'),executable_path=args.browser_exe,headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1450},device_scale_factor=1)
    page=context.new_page();page.on('pageerror',lambda error:errors.append(str(error)));page.goto((E/'review.html').as_uri(),wait_until='load')
    decoded=page.evaluate("""async()=>{await document.fonts.ready;return await Promise.all([...document.querySelectorAll('image')].map(async node=>{const i=new Image();i.src=node.getAttribute('href');await i.decode();const bytes=Uint8Array.from(atob(i.src.split(',')[1]),c=>c.charCodeAt(0)),hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');return {width:i.naturalWidth,height:i.naturalHeight,sha256:hash};}));}""")
    count=page.locator('use').count();assert count==14;version=context.browser.version;page.screenshot(path=str(E/'review.png'));context.close()
assert len(decoded)==4 and {row['sha256'] for row in decoded}=={sha(p) for p in paths.values()} and not errors
with Image.open(E/'review.png') as image:assert image.size==(1800,1450)
literal=str(E/'profile').replace("'","''");cmd="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId | ConvertTo-Json -Compress"
deadline=time.monotonic()+10
while True:
    remaining=subprocess.check_output(['powershell','-NoProfile','-Command',cmd],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()
    if not remaining:break
    assert time.monotonic()<deadline,'Own profile still live; inspect this handle before further browser work';time.sleep(.25)
receipt={'scope':'Static current/first/refined/body original PNG comparison only, no source pixel writes or native/game acceptance.','hero':args.hero,'browser_version':version,'playwright_version':importlib.metadata.version('playwright'),
    'source_files':{name:{'path':p.relative_to(R).as_posix(),'sha256':sha(p)} for name,p in paths.items()},'browser_decoded_source_hashes':decoded,'displayed_image_instances':count,'page_errors':errors,'own_profile_processes_terminal':True,
    'html_sha256':sha(E/'review.html'),'screenshot_sha256':sha(E/'review.png'),'production_adopted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'hero':args.hero,'decoded_images':len(decoded),'displayed_instances':count,'screenshot':str(E/'review.png'),'own_profile_terminal':True}))
