"""Bind unchanged native hurt/fall source bytes and authored candidate regions."""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/characters/shi_en_reaction_20261015'
QA=ROOT/'qa/shi_en_reaction_20261015'
FILES=['hurt_se_v1','hurt_sw_v2','hurt_ne_v1','hurt_nw_v1',
    'death_se_v1','death_sw_v1','death_ne_v1','death_nw_v1','death_ne_fall_v2']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p):return p.relative_to(ROOT).as_posix()
def measure():
    manifest={'schema':'shi_en_native_reactions_candidate_v1','character':'shi_en','sources':{},'poses':{},
        'states':{'hurt':['hurt_impact','hurt_recover'],'death':['death_stagger','death_kneel','death_fall','death_prone']},
        'native_PNG_pixel_changes':False,'runtime_integrated':False,'hurt_callback_qualified':False,
        'death_callback_qualified':False,'ground_pivots_qualified':False,'full_art_complete':False}
    for key in FILES:
        path=ART/(key+'_native.png');request=ART/('request_'+key+'.json')
        spec=json.loads(request.read_text(encoding='utf-8'));assert spec['prompt'].strip()
        with Image.open(path) as image:
            assert image.mode=='RGBA';alpha=image.getchannel('A');mask=alpha.point(lambda v:255 if v>=16 else 0)
            zero=alpha.histogram()[0]/(image.width*image.height);assert zero>.35
            width,height=image.size;direction=key.split('_')[1];unused=[]
            if key.startswith('hurt'):
                mid=width//2;regions=[(0,0,mid,height),(mid,0,width-mid,height)]
                names=['hurt_impact','hurt_recover'];canvas=round(height*1.05)
            elif key=='death_ne_fall_v2':
                regions=[(0,0,width,height)];names=['death_fall'];canvas=1400
            else:
                # Native gutter partitions, not bitmap alteration.
                xm=width//2+round(width*.01);ym=height//2+round(height*.025)
                regions=[(0,0,xm,ym),(xm,0,width-xm,ym),(0,ym,xm,height-ym),(xm,ym,width-xm,height-ym)]
                names=['death_stagger','death_kneel','death_fall','death_prone'];canvas=700
                if key=='death_ne_v1':
                    unused=[{'region':list(regions[2]),'reason':'Only one dropped club is visible in original fall pose; independent native replacement retained.'}]
            covered=0
            for name,region in zip(names,regions):
                x,y,w,h=region;box=(x,y,x+w,y+h)
                if key=='death_ne_v1' and name=='death_fall':continue
                bbox=mask.crop(box).getbbox();assert bbox
                assert min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])>=8,(key,name,bbox)
                covered+=sum(alpha.crop(box).histogram()[16:])
                # These are source-preview pivots only. Fallen body/weapon
                # geometry needs separate real Unit ground calibration.
                torso_y=round(bbox[1]+(bbox[3]-bbox[1])*.5)
                torso=mask.crop((x,y+torso_y,x+w,y+torso_y+1)).getbbox();assert torso
                pose_key=name+'_'+direction;assert pose_key not in manifest['poses']
                manifest['poses'][pose_key]={'source':key,'region':list(region),'alpha_bbox_xyxy':list(bbox),
                    'virtual_canvas':canvas,'candidate_pivot_native':[x+(torso[0]+torso[2])/2,y+bbox[3]],
                    'original_rgba_sha256':hashlib.sha256(image.crop(box).tobytes()).hexdigest()}
            for row in unused:
                x,y,w,h=row['region'];covered+=sum(alpha.crop((x,y,x+w,y+h)).histogram()[16:])
            assert covered==sum(alpha.histogram()[16:]),(key,'unaccounted foreground')
            manifest['sources'][key]={'path':rel(path),'sha256':sha(path),'native_size':[width,height],
                'request':rel(request),'request_sha256':sha(request),
                'references':[{'path':p,'sha256':sha(ROOT/p)} for p in spec['references']],
                'alpha_zero_fraction':zero,'unused_regions':unused,'uniform_virtual_canvas':canvas}
    assert len(manifest['poses'])==24 and len(manifest['sources'])==9
    for state,phases in manifest['states'].items():
        for d in ('se','sw','ne','nw'):
            hashes=[manifest['poses'][p+'_'+d]['original_rgba_sha256'] for p in phases]
            assert len(set(hashes))==len(phases) # Not a semantic-motion qualification.
    return manifest
HTML='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>施恩受击与倒地候选</title>
<style>body{margin:24px;background:#232b26;color:#eee;font:16px system-ui}h1{font-size:24px}.cards{display:flex;flex-wrap:wrap;gap:16px}.card{padding:12px;background:#46503d;border-radius:8px}canvas{width:240px;height:240px;background:linear-gradient(35deg,#596b42,#6e7151)}button{font-size:16px;margin-right:12px}</style>
<h1>施恩 · 四向受击与倒地候选</h1><p>只显示原生候选采样。当前未接入游戏；倒地枢轴、身体/武器衔接和真实回调仍待原生验证。</p>
<button id="pause">暂停</button><button id="step">下一帧</button><button id="mode">切换倒地</button><div class="cards" id="cards"></div><p id="phase"></p>
<script>const manifest=__MANIFEST__;const labels={se:'右下 SE',sw:'左下 SW',ne:'右上 NE',nw:'左上 NW'};const images={},canvases={};let frame=0,paused=false,last=0,mode='hurt';
const ready=Promise.all(Object.entries(manifest.sources).map(([key,s])=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{images[key]=im;resolve()};im.onerror=reject;im.src='../../'+s.path})));
for(const d of Object.keys(labels)){const card=document.createElement('div');card.className='card';card.innerHTML='<strong>'+labels[d]+'</strong><br>';const c=document.createElement('canvas');c.width=300;c.height=300;card.append(c);document.querySelector('#cards').append(card);canvases[d]=c}
function draw(){const phases=manifest.states[mode];for(const d of Object.keys(labels)){const p=manifest.poses[phases[frame%phases.length]+'_'+d],ctx=canvases[d].getContext('2d');ctx.clearRect(0,0,300,300);const [x,y,w,h]=p.region;const s=250/p.virtual_canvas;ctx.drawImage(images[p.source],x,y,w,h,150+(x-p.candidate_pivot_native[0])*s,263+(y-p.candidate_pivot_native[1])*s,w*s,h*s)}document.querySelector('#phase').textContent=phases[frame%phases.length]}
document.querySelector('#pause').onclick=()=>{paused=!paused;document.querySelector('#pause').textContent=paused?'继续':'暂停'};
document.querySelector('#step').onclick=()=>{paused=true;frame++;document.querySelector('#pause').textContent='继续';draw()};
document.querySelector('#mode').onclick=()=>{mode=mode==='hurt'?'death':'hurt';frame=0;document.querySelector('#mode').textContent=mode==='hurt'?'切换倒地':'切换受击';draw()};
ready.then(()=>{draw();requestAnimationFrame(function tick(t){if(!paused&&t-last>400){last=t;frame++;draw()}requestAnimationFrame(tick)})});</script></html>'''
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepare',action='store_true');ap.add_argument('--preview',action='store_true');args=ap.parse_args()
    manifest=measure();path=QA/'source_manifest.json'
    if args.prepare:
        QA.mkdir(exist_ok=False);path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    else:assert json.loads(path.read_text(encoding='utf-8'))==manifest
    if args.prepare or args.preview:(QA/'candidate_preview.html').write_text(HTML.replace('__MANIFEST__',json.dumps(manifest,ensure_ascii=False)),encoding='utf-8')
    print(json.dumps({'native_sources':9,'hurt_keyposes':8,'fall_keyposes':16,'source_integrity_and_foreground_accounting_verified':True,
        'native_PNG_pixel_changes':False,'game_callback_qualified':False,'runtime_integrated':False}))
if __name__=='__main__':main()
