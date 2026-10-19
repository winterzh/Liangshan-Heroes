"""Render exact original sources and a translation-only hand-authored sole-reference preview."""
from pathlib import Path
import argparse,base64,hashlib,importlib.metadata,json,shutil,subprocess,sys
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--deps',required=True);p.add_argument('--output',required=True);p.add_argument('--browser-exe',required=True);a=p.parse_args()
sys.path.insert(0,str(Path(a.deps).resolve()))
from playwright.sync_api import sync_playwright
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path(a.output).resolve()
assert not E.exists() and not E.is_relative_to(R);E.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,data):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
paths={'v3':R/'qa/zou_run_canon_body_20261019/native_originals/idle_v3.png','portrait':R/'qa/li_yun_zou_run_portrait_refine_20261019/native_originals/zou_run_v2.png',**{f'v{i}':Q/f'native_originals/idle_v{i}.png' for i in [4,5,6,7]}}
data={k:'data:image/png;base64,'+base64.b64encode(v.read_bytes()).decode('ascii') for k,v in paths.items()}
refs=json.loads((Q/'sole_references.json').read_text(encoding='utf-8'));assert sha(Q/refs['source'])==refs['source_sha256']
frames=json.loads((Q/'frame_check_idle_v7.json').read_text(encoding='utf-8'));assert frames['frame_source_qualified']
model={'source_sha256':refs['source_sha256'],'frames':{f['direction']:f for f in frames['frames']},'sole_references':refs['directions'],'scales':{'large':0.45,'small':48.1/627},'preview_only':True}
def tile(k,x,y,s,region=None):
    region=region or [0,0,1254,1254]
    return f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="#30392c"/><svg x="{x}" y="{y}" width="{s}" height="{s}" viewBox="'+ ' '.join(map(str,region))+f'" overflow="hidden"><use href="#source_{k}"/></svg>'
def doc(title,h,keys,parts):
    defs=''.join(f'<image id="source_{k}" href="{data[k]}" width="1254" height="1254"/>' for k in keys)
    return '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>'+title+'</title><body style="margin:0;background:#171a14"><svg xmlns="http://www.w3.org/2000/svg" width="1800" height="'+str(h)+'"><defs>'+defs+'</defs><g fill="#eae0cc" font-family="Microsoft YaHei,sans-serif"><text x="25" y="40" font-size="26">'+title+'</text>'+''.join(parts)+'</g></svg></body></html>'
parts=[]
for k,x,label in [('v3',25,'旧v3：后脑仍像配件'),('v7',620,'新v7：高发髻、露后脑皮肤'),('portrait',1215,'既有头像参照')]:parts.append(f'<text x="{x}" y="80" font-size="23">{label}</text>'+tile(k,x,100,500))
for i,(d,head) in enumerate([('se',[285,85,140,140]),('sw',[850,85,140,140]),('ne',[285,680,140,140]),('nw',[845,680,140,140])]):
    x=25+i*440;parts.append(f'<text x="{x}" y="655" font-size="23">{d.upper()} · 原方格 / 头部局部</text>'+tile('v7',x,680,240,model['frames'][d]['cell'])+tile('v7',x+260,700,140,head)+tile('v7',x+265,860,64,head))
parts+=['<text x="25" y="990" font-size="22">后脑肤色轮廓比旧稿清楚，但仍偏球状；解剖表现与小尺寸身份识别未最终接受。</text>','<text x="25" y="1035" font-size="22">第49回人形、脑后肉瘤、短刀为依据；服饰、发式、刀形和站姿是美术解释。仅待机来源。</text>']
comparison=doc('邹润身体返修 · 原图与头部比较（候选，未游戏采用）',1080,['v3','v7','portrait'],parts)
parts=[]
for i,(k,label) in enumerate([('v4','v4：圆珠变发结，未接受'),('v5','v5：圆珠返回且跨格'),('v6','v6：独立构图，但跨格'),('v7','v7：补留白，原alpha取图通过')]):
    x=25+i*445;parts.append(f'<text x="{x}" y="80" font-size="20">{label}</text>'+tile(k,x,100,420)+f'<path d="M{x+210} 100V520 M{x} 310H{x+420}" stroke="#b19a61" fill="none"/>')
parts+=['<text x="25" y="565" font-size="22">四份内置原PNG全部保留；分格线为浏览器叠加，未清洗、裁切或重编码原图。</text>']
history=doc('邹润 · 本轮四稿与失败原因',600,['v4','v5','v6','v7'],parts)
registration='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>邹润脚底参照配准候选</title><style>body{margin:0;background:#172017;color:#eee6cf;font:18px "Microsoft YaHei",sans-serif}h2,p{margin:12px 20px}button{font:inherit;margin:5px;padding:5px 18px}canvas{display:block}#state{margin-left:20px}</style><h2>邹润四向待机 · 仅平移配准，不逐方向缩放</h2><p>鞋底取样点为人工美术参照。白十字是参照中点；它不是物理接地或Godot验收。</p><div id="controls"></div><span id="state"></span><canvas id="c" width="1280" height="1200"></canvas><script>
const MODEL=__MODEL__, URL=__URL__;const dirs=['se','sw','ne','nw'];const canvas=document.querySelector('#c'),ctx=canvas.getContext('2d'),im=new Image();let selected='se';window.states=[];
function render(d){selected=d;const draws=[];ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#263425';ctx.fillRect(0,0,1280,1200);ctx.font='20px Microsoft YaHei';ctx.fillStyle='#eee6cf';ctx.fillText('上：统一方格原位置；中：人工鞋底参照中点配准；下：48.1px方格尺度参考',20,28);
function draw(dir,kind,x,y,scale){const f=MODEL.frames[dir],pts=MODEL.sole_references[dir];const anchor=kind==='raw'?[f.cell[0]+313.5,f.cell[1]+560]:[(pts[0][0]+pts[1][0])/2,(pts[0][1]+pts[1][1])/2];const r=f.sampling_region;
ctx.save();ctx.setTransform(scale,0,0,scale,x-scale*anchor[0],y-scale*anchor[1]);const m=ctx.getTransform();ctx.drawImage(im,r[0],r[1],r[2],r[3],r[0],r[1],r[2],r[3]);ctx.restore();
ctx.strokeStyle='#b8b8a5';ctx.beginPath();ctx.moveTo(x-95,y);ctx.lineTo(x+95,y);ctx.stroke();ctx.strokeStyle='#fff';ctx.beginPath();ctx.moveTo(x-6,y);ctx.lineTo(x+6,y);ctx.moveTo(x,y-6);ctx.lineTo(x,y+6);ctx.stroke();
if(kind!=='raw'){ctx.fillStyle='#9aee8c';for(const p of pts){ctx.beginPath();ctx.arc(m.a*p[0]+m.e,m.d*p[1]+m.f,kind==='small'?1.5:3,0,Math.PI*2);ctx.fill();}}
ctx.fillStyle=dir===selected?'#f2ca78':'#eee6cf';ctx.fillText(dir.toUpperCase()+' · '+kind,x-60,y+30);draws.push({direction:dir,kind,scale,anchor,target:[x,y],matrix:[m.a,m.b,m.c,m.d,m.e,m.f],sampling_region:r});}
for(let i=0;i<4;i++){draw(dirs[i],'raw',160+320*i,300,MODEL.scales.large);draw(dirs[i],'registered',160+320*i,660,MODEL.scales.large);draw(dirs[i],'small',160+320*i,810,MODEL.scales.small);}
ctx.fillStyle='#eee6cf';ctx.font='18px Microsoft YaHei';ctx.fillText('所选方向放大查看：'+d.toUpperCase()+'（同一尺度0.45）',20,890);draw(d,'selected',1010,1165,MODEL.scales.large);
document.querySelector('#state').textContent='所选方向 '+d.toUpperCase()+'；绿色点仅为鞋底参照，不是骨骼或接触解算。';window.currentReceipt={selected:d,draws,source_sha256:MODEL.source_sha256};window.states.push(window.currentReceipt);}
for(const d of dirs){const b=document.createElement('button');b.textContent=d.toUpperCase();b.dataset.direction=d;b.onclick=()=>render(d);document.querySelector('#controls').appendChild(b);}
window.ready=(async()=>{im.src=URL;await im.decode();const bytes=Uint8Array.from(atob(URL.split(',')[1]),c=>c.charCodeAt(0));const actual=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');if(actual!==MODEL.source_sha256)throw Error('Source hash mismatch');render('se');return {actual,naturalSize:[im.naturalWidth,im.naturalHeight]};})();</script></body></html>'''.replace('__MODEL__',json.dumps(model,ensure_ascii=False)).replace('__URL__',json.dumps(data['v7']))
pages=[('comparison',comparison,1800,1080,['v3','v7','portrait'],15),('history',history,1800,600,['v4','v5','v6','v7'],4),('registration',registration,1280,1400,['v7'],None)]
errors=[];results=[];shutil.copyfile(Path(__file__),E/'render_registered.py')
with sync_playwright() as pw:
    context=pw.chromium.launch_persistent_context(str(E/'profile'),executable_path=a.browser_exe,headless=True,chromium_sandbox=True,viewport={'width':1800,'height':1250},device_scale_factor=1);version=context.browser.version
    for name,html,width,height,keys,count in pages:
        path=E/(name+'.html');path.write_text(html,encoding='utf-8');page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.set_viewport_size({'width':width,'height':height});page.goto(path.as_uri(),wait_until='load');page.evaluate('document.fonts.ready')
        if name=='registration':
            decoded=page.evaluate('window.ready');assert decoded['actual']==sha(paths['v7']) and decoded['naturalSize']==[1254,1254]
            for d in ['se','sw','ne','nw']:page.locator('[data-direction="'+d+'"]').click();assert page.evaluate('window.currentReceipt.selected')==d
            save(E/'draw_receipts.json',page.evaluate('window.states'));save(E/'registration_model.json',model)
        else:
            hashes=page.evaluate("""async()=>await Promise.all([...document.querySelectorAll('image')].map(async n=>{let i=new Image();i.src=n.getAttribute('href');await i.decode();let b=Uint8Array.from(atob(i.src.split(',')[1]),c=>c.charCodeAt(0));return [...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(v=>v.toString(16).padStart(2,'0')).join('');}))""")
            assert set(hashes)=={sha(paths[k]) for k in keys};assert page.locator('use').count()==count
        capture=E/(name+'.png');page.screenshot(path=str(capture));page.close()
        with Image.open(capture) as im:assert im.size==(width,height)
        results.append({'page':name,'decoded_sources':keys,'svg_instances':count,'html_sha256':sha(path),'screenshot_sha256':sha(capture),'viewport':[width,height]})
    context.close()
assert not errors
literal=str(E/'profile').replace("'","''");cmd="Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedge.exe' -and $_.CommandLine -and $_.CommandLine.IndexOf('"+literal+"',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object ProcessId | ConvertTo-Json -Compress"
assert not subprocess.check_output(['powershell','-NoProfile','-Command',cmd],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()
save(E/'receipt.json',{'scope':'Static source comparison and translation-only manual art registration preview. No physical contact, motion, Godot, production or package acceptance.','browser_version':version,'playwright_version':importlib.metadata.version('playwright'),'sources':{k:{'path':p.relative_to(R).as_posix(),'sha256':sha(p)} for k,p in paths.items()},'pages':results,'page_errors':errors,'own_profile_processes_terminal':True,'production_adopted':False})
print(json.dumps({'pages':[r['page'] for r in results],'actual_direction_clicks':4,'own_profile_terminal':True}))
