"""Readability comparison, not an in-game HUD capture or PNG art edit."""
from pathlib import Path
import hashlib,json,shutil,subprocess,time
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path('D:/CodexEvidence/shuihu/deng_fei_portrait_20261019/readability');(E/'images').mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sources={'old':R/'assets/portraits13.png','new':Q/'native_originals/portrait_v1.png','body':R/'assets/characters/deng_fei_wounded_20261005/idle_v3.png'}
for name,src in sources.items():shutil.copyfile(src,E/'images'/f'{name}.png');assert sha(src)==sha(E/'images'/f'{name}.png')
def portrait(name,x,y,size):
    view='0 0 410 400' if name=='old' else '0 0 627 627' if name=='body' else '0 0 1254 1254';native=1200 if name=='old' else 1254
    return f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#3A2C20"/><svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}" preserveAspectRatio="xMidYMid meet" overflow="hidden"><image href="images/{name}.png" width="{native}" height="{native}"/></svg><rect x="{x}" y="{y}" width="{size}" height="{size}" fill="none" stroke="#88704A"/>'
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1500"><rect width="1800" height="1500" fill="#17130F"/><g fill="#EFE7D3" font-family="Microsoft YaHei, sans-serif">','<text x="30" y="42" font-size="28">邓飞头像候选 · 来源与小尺寸阅读检查（浏览器，非游戏界面）</text>']
for name,x,label in [('old',30,'现用九宫图集区域'),('new',600,'新独立头像候选'),('body',1170,'现用身体参考 · SE')]:
    parts.append(f'<text x="{x}" y="84" font-size="24">{label}</text>');parts.append(portrait(name,x,106,512))
for name,y,label in [('new',705,'新候选'),('old',1050,'现用区域')]:
    parts.append(f'<text x="30" y="{y-30}" font-size="24">{label} · 原图直接等比显示</text>')
    x=30
    for size in [256,128,96,64,32]:
        parts.append(portrait(name,x,y,size));parts.append(f'<text x="{x}" y="{y+size+28}" font-size="22">{size}px</text>');x+=size+100
parts.append('<text x="30" y="1430" font-size="23">原著第44回：双睛赤、能使一条铁链；五官、发式、甲饰与褐色配色为既有模型/美术解释。</text><text x="30" y="1470" font-size="23">仅检查静态来源与缩小阅读；未接入Godot、图鉴、战斗HUD或编译包。原PNG不改像素。</text></g></svg>')
svg=E/'review.svg';svg.write_text(''.join(parts),encoding='utf-8');out=E/'review.png';browser=Path('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
cmd=[str(browser),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--force-device-scale-factor=1','--window-size=1800,1500','--virtual-time-budget=2000','--user-data-dir='+str(E/'profile'),'--screenshot='+str(out),svg.as_uri()]
with (E/'stdout.log').open('xb') as stdout,(E/'stderr.log').open('xb') as stderr:
    child=subprocess.Popen(cmd,stdout=stdout,stderr=stderr);code=child.wait(timeout=45)
deadline=time.monotonic()+30
while time.monotonic()<deadline:
    if out.exists() and out.stat().st_size>100000:
        try:
            with Image.open(out) as im:im.verify()
            break
        except (OSError,SyntaxError):pass
    time.sleep(.2)
assert out.exists();shutil.copyfile(svg,Q/'readability.svg');shutil.copyfile(out,Q/'readability.png')
receipt={'scope':'Isolated browser static source comparison and 256/128/96/64/32px display; not Godot/UI/Unit/package acceptance. No painted PNG source edits.','command':cmd,'pid':child.pid,'exit_code':code,'sources':{name:{'path':str(src),'sha256':sha(src)} for name,src in sources.items()},'legacy_region':[0,0,410,400],'svg_sha256':sha(svg),'png_sha256':sha(out),'production_adopted':False}
with (Q/'readability_receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'browser_capture':str(Q/'readability.png'),'sizes':[256,128,96,64,32],'native_tested':False}))
