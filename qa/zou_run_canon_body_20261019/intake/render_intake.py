"""Read-only browser intake of raw four-direction source sheets; no source PNG writes."""
from pathlib import Path
import argparse,base64,hashlib,importlib.metadata,json,shutil,subprocess,sys
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('--deps',required=True);parser.add_argument('--output',required=True);parser.add_argument('--browser-exe',required=True);args=parser.parse_args();sys.path.insert(0,str(Path(args.deps).resolve()))
from playwright.sync_api import sync_playwright
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(args.output).resolve();assert not E.exists() and not E.is_relative_to(R);E.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths={'legacy':R/'assets/anim/zou_run_walk.png','portrait':R/'qa/li_yun_zou_run_portrait_refine_20261019/native_originals/zou_run_v2.png',**{'v'+str(i):Q/f'native_originals/idle_v{i}.png' for i in [1,2,3]}}
encoded={key:'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode('ascii') for key,p in paths.items()}
def tile(key,x,y,size,region=None):
    region=region or ([0,0,256,256] if key=='legacy' else [0,0,1254,1254]);w,h=(1024,256) if key=='legacy' else (1254,1254);view=' '.join(map(str,region))
    return f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#2d352b"/><svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><use href="#source_{key}"/></svg><rect x="{x}" y="{y}" width="{size}" height="{size}" fill="none" stroke="#9d8c62"/>'
def document(title,height,keys,parts):
    defs=''.join(f'<image id="source_{key}" href="{encoded[key]}" width="{1024 if key=="legacy" else 1254}" height="{256 if key=="legacy" else 1254}"/>' for key in keys)
    return '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>'+title+'</title><body style="margin:0;background:#171812"><svg xmlns="http://www.w3.org/2000/svg" width="1800" height="'+str(height)+'"><rect width="1800" height="'+str(height)+'" fill="#171812"/><defs>'+defs+'</defs><g fill="#eee6cf" font-family="Microsoft YaHei,sans-serif"><text x="30" y="43" font-size="28">'+title+'</text>'+''.join(parts)+'</g></svg></body></html>'
parts=[]
for key,x,label in [('legacy',30,'现用走图首帧'),('v3',620,'v3原图全幅（四向待机）'),('portrait',1210,'既有头像v2参考')]:parts.append(f'<text x="{x}" y="85" font-size="24">{label}</text>'+tile(key,x,108,500))
cells=[[0,0,627,627],[627,0,627,627],[0,627,627,627],[627,627,627,627]]
for index,(direction,cell) in enumerate(zip(['SE','SW','NE','NW'],cells)):
    x=30+index*440;parts.append(f'<text x="{x}" y="680" font-size="25">{direction} · 同一627方格</text>'+tile('v3',x,705,300,cell)+tile('v3',x+325,850,48.1,cell))
parts+=['<text x="30" y="1060" font-size="22">右侧小图固定48.1像素方框，仅按现用radius×3.7参考；没有逐方向包围盒缩放或脚底配准。</text>',
        '<text x="30" y="1105" font-size="22">后脑仍偏圆珠状、方向间脚底基准有差异；未接受解剖/接地/完整造型。短刀与无额前尖角可作后继比较。</text>',
        '<text x="30" y="1150" font-size="22">第49回人形/脑后肉瘤/短刀为依据，服饰与待机为解释；浏览器来源比较不是Godot、Unit或包内验收。</text>']
main=document('邹润 · 四向短刀待机来源候选（未游戏采用）',1200,['legacy','v3','portrait'],parts)
parts=[]
for key,x,label in [('v1',30,'v1：跨分格，未通过'),('v2',620,'v2：留白修正，后脑像圆珠'),('v3',1210,'v3：颜色修正，解剖仍未接受')]:
    parts.append(f'<text x="{x}" y="85" font-size="22">{label}</text>'+tile(key,x,110,500))
    parts.append(f'<path d="M{x+250} 110V610 M{x} 360H{x+500}" fill="none" stroke="#c79559" stroke-width="1"/>')
parts+=['<text x="30" y="660" font-size="22">分格线仅为QA叠加；三份原PNG均未改像素，不用后继结果补签首稿。</text>']
history=document('邹润 · 三轮原稿与分格历史',710,['v1','v2','v3'],parts)
pages=[('intake',main,1200,['legacy','v3','portrait'],11),('history',history,710,['v1','v2','v3'],3)];errors=[];results=[]
shutil.copyfile(Q/'render_intake.py',E/'render_intake.py')
with sync_playwright() as playwright:
    context=playwright.chromium.launch_persistent_context(str(E/'profile'),executable_path=args.browser_exe,headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1200},device_scale_factor=1);version=context.browser.version
    for name,html,height,keys,expected_count in pages:
        path=E/(name+'.html');path.write_text(html,encoding='utf-8');page=context.new_page();page.on('pageerror',lambda error:errors.append(str(error)));page.set_viewport_size({'width':1800,'height':height});page.goto(path.as_uri(),wait_until='load')
        decoded=page.evaluate("""async()=>{await document.fonts.ready;return await Promise.all([...document.querySelectorAll('image')].map(async n=>{const i=new Image();i.src=n.getAttribute('href');await i.decode();const bytes=Uint8Array.from(atob(i.src.split(',')[1]),c=>c.charCodeAt(0));return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');}));}""")
        assert set(decoded)=={sha(paths[key]) for key in keys};count=page.locator('use').count();assert count==expected_count;out=E/(name+'.png');page.screenshot(path=str(out));page.close()
        with Image.open(out) as image:assert image.size==(1800,height)
        results.append({'page':name,'decoded_source_hashes':decoded,'displayed_instances':count,'html_sha256':sha(path),'screenshot_sha256':sha(out)})
    context.close()
assert not errors
literal=str(E/'profile').replace("'","''");cmd="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId | ConvertTo-Json -Compress"
assert not subprocess.check_output(['powershell','-NoProfile','-Command',cmd],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()
receipt={'scope':'Raw source/static fixed-frame browser comparison only. Frame checks do not qualify anatomy, ground contact, natural gait or production/native/game acceptance.','browser_version':version,'playwright_version':importlib.metadata.version('playwright'),
    'source_files':{key:{'path':p.relative_to(R).as_posix(),'sha256':sha(p)} for key,p in paths.items()},'pages':results,'page_errors':errors,'own_profile_processes_terminal':True,'production_adopted':False}
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'pages':[row['page'] for row in results],'decoded_hashes_match':True,'own_profile_terminal':True}))
