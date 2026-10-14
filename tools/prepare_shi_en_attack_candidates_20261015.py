"""Read native four-facing attack atlases; preserve pixels, record sampling only."""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'assets/characters/shi_en_combat_20261015'
QA=ROOT/'qa/shi_en_combat_20261015'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p):return p.relative_to(ROOT).as_posix()
def measure():
    rows=[]
    for direction in ('se','sw','ne','nw'):
        path=FOLDER/f'attack_{direction}_v1_native.png';request=FOLDER/f'request_attack_{direction}_v1.json'
        spec=json.loads(request.read_text(encoding='utf-8'));assert spec['prompt'].strip()
        with Image.open(path) as image:
            assert image.mode=='RGBA' and min(image.size)>1000
            alpha=image.getchannel('A');binary=alpha.point(lambda v:255 if v>=16 else 0)
            assert alpha.histogram()[0]/(image.width*image.height)>.35
            # The genuine blank native gutters are slightly right/below the
            # geometric midpoint. Retain the complete clubs/upper-row boots;
            # there is no copying, painting, stretching or PNG output.
            xmid=image.width//2+round(image.width*.02);ymid=image.height//2+round(image.height*.025)
            regions=[(0,0,xmid,ymid),(xmid,0,image.width-xmid,ymid),
                (0,ymid,xmid,image.height-ymid),(xmid,ymid,image.width-xmid,image.height-ymid)]
            poses=[];covered=0
            for phase,(x,y,w,h) in zip(('windup','strike','followthrough','recover'),regions):
                box=(x,y,x+w,y+h);bbox=binary.crop(box).getbbox();assert bbox
                assert min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])>=8,(direction,phase,bbox)
                covered+=sum(alpha.crop(box).histogram()[16:])
                torso_y=round(bbox[1]+(bbox[3]-bbox[1])*.55)
                torso=binary.crop((x,y+torso_y,x+w,y+torso_y+1)).getbbox();assert torso
                poses.append({'phase':phase,'region':[x,y,w,h],'alpha_bbox_xyxy':list(bbox),
                    'candidate_pivot_native':[x+(torso[0]+torso[2])/2,y+bbox[3]],
                    'original_rgba_sha256':hashlib.sha256(image.crop(box).tobytes()).hexdigest()})
            assert covered==sum(alpha.histogram()[16:])
            assert len({p['original_rgba_sha256'] for p in poses})==4
            rows.append({'direction':direction,'path':rel(path),'sha256':sha(path),'native_size':list(image.size),
                'request':rel(request),'request_sha256':sha(request),
                'references':[{'path':p,'sha256':sha(ROOT/p)} for p in spec['references']],
                'alpha_zero_fraction':alpha.histogram()[0]/(image.width*image.height),'poses':poses})
    return {'scope':'Shi En native four-facing four-phase club attack SOURCE candidates only.',
        'sources':rows,'native_PNG_pixel_changes':False,'runtime_integrated':False,
        'original_combat_callback_qualified':False,'frame_continuity_qualified':False,'full_art_complete':False}
HTML='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>施恩四向攻击候选</title>
<style>body{margin:24px;background:#232b26;color:#eee;font:16px system-ui}h1{font-size:24px}.cards{display:flex;flex-wrap:wrap;gap:16px}.card{padding:12px;background:#46503d;border-radius:8px}canvas{width:240px;height:240px;background:linear-gradient(35deg,#596b42,#6e7151)}button{font-size:16px;margin-right:12px}</style>
<h1>施恩 · 四向短棒攻击候选</h1><p>原生采样预览，当前未接入游戏；跨帧身体/持棒衔接、攻击命中时序仍待原生验证。</p>
<button id="pause">暂停</button><button id="step">下一帧</button><div class="cards" id="cards"></div><p id="phase"></p>
<script>const manifest=__MANIFEST__;const labels={se:'右下 SE',sw:'左下 SW',ne:'右上 NE',nw:'左上 NW'};const phases=['蓄势','出手','收招','复位'];const images={},canvases={};let frame=0,paused=false,last=0;
const ready=Promise.all(manifest.sources.map(s=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{images[s.direction]=im;resolve()};im.onerror=reject;im.src='../../'+s.path;const card=document.createElement('div');card.className='card';card.innerHTML='<strong>'+labels[s.direction]+'</strong><br>';const c=document.createElement('canvas');c.width=300;c.height=300;card.append(c);document.querySelector('#cards').append(card);canvases[s.direction]=c})));
function draw(){for(const s of manifest.sources){const p=s.poses[frame%4],ctx=canvases[s.direction].getContext('2d');ctx.clearRect(0,0,300,300);const [x,y,w,h]=p.region;const scale=250/700;ctx.drawImage(images[s.direction],x,y,w,h,150+(x-p.candidate_pivot_native[0])*scale,263+(y-p.candidate_pivot_native[1])*scale,w*scale,h*scale)}document.querySelector('#phase').textContent=phases[frame%4]}
document.querySelector('#pause').onclick=()=>{paused=!paused;document.querySelector('#pause').textContent=paused?'继续':'暂停'};
document.querySelector('#step').onclick=()=>{paused=true;frame++;document.querySelector('#pause').textContent='继续';draw()};
ready.then(()=>{draw();requestAnimationFrame(function tick(t){if(!paused&&t-last>250){last=t;frame++;draw()}requestAnimationFrame(tick)})});</script></html>'''
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepare',action='store_true');ap.add_argument('--preview',action='store_true');args=ap.parse_args()
    manifest=measure();path=QA/'source_manifest.json'
    if args.prepare:
        QA.mkdir(exist_ok=False);path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    else:assert json.loads(path.read_text(encoding='utf-8'))==manifest
    if args.prepare or args.preview:(QA/'candidate_preview.html').write_text(HTML.replace('__MANIFEST__',json.dumps(manifest,ensure_ascii=False)),encoding='utf-8')
    print(json.dumps({'native_sources':4,'attack_keyposes':16,'source_bytes_and_regions_verified':True,
        'runtime_integrated':False,'game_combat_qualified':False}))
if __name__=='__main__':main()
