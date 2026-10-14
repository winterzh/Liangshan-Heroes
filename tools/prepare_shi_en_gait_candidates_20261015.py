"""Preserve native candidate bytes and preview authored atlas regions; no pixel edits."""
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/characters/shi_en_gait_20261015'
QA = ROOT / 'qa/shi_en_gait_20261015'
# Each independent native file uses one uniform virtual canvas scale. No
# per-pose stretching, reflection, repainting, chroma-keying or PNG output.
SPEC = {
    'idle_v1_native': (700, [('idle_se',0,0,627,627),('idle_sw',627,0,627,627),('idle_ne',0,627,627,627),('idle_nw',627,627,627,627)]),
    'walk_se_contacts_v3_native': (950,[('contact_a_se',0,0,887,887),('contact_b_se',887,0,887,887)]),
    'walk_se_passing_v3_native': (950,[('passing_a_se',0,0,887,887),('passing_b_se',887,0,887,887)]),
    'walk_sw_contacts_v4_native': (950,[('contact_a_sw',0,0,887,887),('contact_b_sw',887,0,887,887)]),
    'walk_sw_passing_v4_native': (950,[('passing_a_sw',0,0,887,887),('passing_b_sw',887,0,887,887)]),
    'walk_ne_contacts_v3_native': (950,[('contact_a_ne',0,0,887,887),('contact_b_ne',887,0,887,887)]),
    'walk_ne_passing_v3_native': (950,[('passing_a_ne',0,0,887,887)]),
    'walk_ne_passing_b_v4_native': (1035,[('passing_b_ne',0,0,1774,887)]),
    'walk_nw_contacts_v3_native': (950,[('contact_a_nw',0,0,887,887)]),
    'walk_nw_contact_b_v4_native': (1380,[('contact_b_nw',0,0,1261,1247)]),
    'walk_nw_passing_a_v4_native': (1380,[('passing_a_nw',0,0,1190,1322)]),
    'walk_nw_passing_b_v4_native': (1380,[('passing_b_nw',0,0,1189,1323)]),
}
REQUESTS = {
    'idle_v1_native':'request_idle_v1.json',
    'walk_se_contacts_v3_native':'request_walk_se_contacts_v3.json',
    'walk_se_passing_v3_native':'request_walk_se_passing_v3.json',
}
REFERENCES = {
    'idle_v1_native': [],
    'walk_se_contacts_v3_native':['idle_v1_native'],
    'walk_se_passing_v3_native':['walk_se_contacts_v3_native','idle_v1_native'],
    'walk_sw_contacts_v4_native':['idle_v1_native'],
    'walk_sw_passing_v4_native':['walk_sw_contacts_v4_native','idle_v1_native'],
    'walk_ne_contacts_v3_native':['idle_v1_native'],
    'walk_ne_passing_v3_native':['walk_ne_contacts_v3_native','idle_v1_native'],
    'walk_ne_passing_b_v4_native':['walk_ne_passing_v3_native'],
    'walk_nw_contacts_v3_native':['idle_v1_native'],
    'walk_nw_contact_b_v4_native':['walk_nw_contacts_v3_native','idle_v1_native'],
    'walk_nw_passing_a_v4_native':['walk_nw_contact_b_v4_native'],
    'walk_nw_passing_b_v4_native':['walk_nw_passing_a_v4_native'],
}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p): return p.relative_to(ROOT).as_posix()
def write(p,obj): p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def prepare(external):
    DEST.mkdir(exist_ok=False);QA.mkdir(exist_ok=False)
    (DEST/'.gdignore').write_text('# Unqualified native candidates; excluded from production import/export.\n',encoding='utf-8')
    manifest={'schema':'shi_en_native_gait_candidate_v1','character':'shi_en',
        'sources':{},'poses':{},'states':{'idle':['idle'],'walk':['contact_a','passing_a','contact_b','passing_b']},
        'pixel_edits':False,'runtime_integrated':False,'runtime_qualified':False,'full_character_actions_complete':False,
        'scope':'Four directional idle poses and four distinct gait keyposes per direction. Source candidates and browser preview only; no game, SDK, package or platform acceptance.'}
    for key,(canvas,selections) in SPEC.items():
        source=external/(key+'.png');target=DEST/source.name
        shutil.copyfile(source,target);assert sha(source)==sha(target)
        request_name=REQUESTS.get(key,'request_'+key+'.json')
        request=external/request_name;request_target=DEST/request_name
        shutil.copyfile(request,request_target)
        prompt=json.loads(request_target.read_text(encoding='utf-8'))['prompt'];assert prompt.strip()
        with Image.open(target) as image:
            assert image.mode=='RGBA'
            alpha=image.getchannel('A');binary=alpha.point(lambda value:255 if value>=16 else 0)
            bounds=[]
            for name,x,y,w,h in selections:
                assert x>=0 and y>=0 and x+w<=image.width and y+h<=image.height
                box=(x,y,x+w,y+h);part=binary.crop(box);bbox=part.getbbox();assert bbox
                assert min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])>=8, (key,name,bbox)
                # Torso centre plus actual planted-foot alpha bottom. These
                # authored candidate pivots still need temporal/runtime review.
                torso_y=round(bbox[1]+(bbox[3]-bbox[1])*.30)
                torso=part.crop((0,torso_y,w,torso_y+1)).getbbox();assert torso
                pivot=[x+(torso[0]+torso[2])/2,y+bbox[3]]
                rgba=image.crop(box).tobytes()
                manifest['poses'][name]={'source':key,'region':list((x,y,w,h)),
                    'alpha_bbox_xyxy':list(bbox),'pivot_native':pivot,'virtual_canvas':canvas,
                    'rgba_sha256':hashlib.sha256(rgba).hexdigest(),'pivot_qualified':False}
                bounds.append(box)
            unused=[]
            if key in ('walk_ne_passing_v3_native','walk_nw_contacts_v3_native'):
                unused=[{'region':[887,0,887,887],'reason':
                    'Repeated support leg; not the opposite passing phase.' if key.startswith('walk_ne') else 'Wrong northeast facing in northwest contact atlas.'}]
            manifest['sources'][key]={'path':rel(target),'sha256':sha(target),'native_size':list(image.size),
                'alpha_zero_fraction':alpha.histogram()[0]/(image.width*image.height),
                'request':rel(request_target),'request_sha256':sha(request_target),
                'reference_sources':REFERENCES[key],'uniform_virtual_canvas':canvas,'unused_regions':unused,
                'visual_selection':'Distinct candidate pose/facing checked in native source; animation and runtime still pending.'}
    write(QA/'source_manifest.json',manifest)
    return manifest

HTML='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>施恩步态候选</title>
<style>body{margin:24px;background:#232b26;color:#eee;font:16px system-ui}h1{font-size:24px}.cards{display:flex;flex-wrap:wrap;gap:16px}.card{background:#46503d;padding:12px;border-radius:8px}canvas{width:240px;height:240px;background:linear-gradient(35deg,#596b42,#6e7151)}button,input{font-size:16px}p{max-width:850px}button{margin-right:12px}pre{font-size:13px}</style>
<h1>施恩 · 四向待机与行走候选</h1><p>原生图像仅按采样框等比显示；脚点仍待游戏内验证。此预览未接入游戏，不表示攻击、受击、死亡动作已完成。</p>
<button id="pause">暂停</button><button id="step">下一帧</button><button id="mode">切换待机</button><label>每秒帧数 <input id="fps" type="range" min="1" max="12" value="4"><span id="speed">4</span></label>
<div class="cards" id="cards"></div><p id="phase"></p><script>
const manifest=__MANIFEST__;const names={se:'右下 SE',sw:'左下 SW',ne:'右上 NE',nw:'左上 NW'};
const pictures={};const canvases={};let paused=false,idle=false,index=0,last=0;
const ready=Promise.all(Object.entries(manifest.sources).map(([key,s])=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{pictures[key]=im;resolve()};im.onerror=reject;im.src='../../'+s.path})));
for(const d of Object.keys(names)){const card=document.createElement('div');card.className='card';card.innerHTML='<strong>'+names[d]+'</strong><br>';const c=document.createElement('canvas');c.width=300;c.height=300;canvases[d]=c;card.append(c);document.querySelector('#cards').append(card)}
function paint(){const order=idle?manifest.states.idle:manifest.states.walk;for(const [d,c] of Object.entries(canvases)){const p=manifest.poses[order[index%order.length]+'_'+d],im=pictures[p.source],ctx=c.getContext('2d');ctx.clearRect(0,0,300,300);const [x,y,w,h]=p.region;const scale=250/p.virtual_canvas;ctx.drawImage(im,x,y,w,h,150+(x-p.pivot_native[0])*scale,263+(y-p.pivot_native[1])*scale,w*scale,h*scale);ctx.strokeStyle='#d8d5a766';ctx.beginPath();ctx.moveTo(136,263);ctx.lineTo(164,263);ctx.stroke()}document.querySelector('#phase').textContent=(idle?'待机':'行走')+'：'+order[index%order.length]}
document.querySelector('#pause').onclick=()=>{paused=!paused;document.querySelector('#pause').textContent=paused?'继续':'暂停'};
document.querySelector('#step').onclick=()=>{paused=true;document.querySelector('#pause').textContent='继续';index++;paint()};
document.querySelector('#mode').onclick=()=>{idle=!idle;index=0;paint();document.querySelector('#mode').textContent=idle?'切换行走':'切换待机'};
document.querySelector('#fps').oninput=e=>document.querySelector('#speed').textContent=e.target.value;
ready.then(()=>{paint();requestAnimationFrame(function tick(t){if(!paused&&t-last>1000/Number(document.querySelector('#fps').value)){index++;last=t;paint()}requestAnimationFrame(tick)})});
</script></html>'''

def verify(manifest):
    assert len(manifest['poses'])==20 and len(manifest['sources'])==12
    assert not manifest['runtime_integrated'] and (DEST/'.gdignore').is_file()
    for key,source in manifest['sources'].items():
        p=ROOT/source['path'];assert sha(p)==source['sha256'];assert sha(ROOT/source['request'])==source['request_sha256']
        assert all(ref in manifest['sources'] for ref in source['reference_sources'])
        with Image.open(p) as image:
            assert image.mode=='RGBA' and list(image.size)==source['native_size']
            assert source['alpha_zero_fraction']>.35
            seen=set();alpha=image.getchannel('A');covered=0
            for name,pose in manifest['poses'].items():
                if pose['source']!=key:continue
                x,y,w,h=pose['region'];box=(x,y,x+w,y+h)
                assert box not in seen;seen.add(box)
                assert hashlib.sha256(image.crop(box).tobytes()).hexdigest()==pose['rgba_sha256']
                assert pose['virtual_canvas']==source['uniform_virtual_canvas']
                covered+=sum(alpha.crop(box).histogram()[16:])
            for unused in source['unused_regions']:
                x,y,w,h=unused['region'];box=(x,y,x+w,y+h)
                assert unused['reason'] and box not in seen;seen.add(box)
                covered+=sum(alpha.crop(box).histogram()[16:])
            assert covered==sum(alpha.histogram()[16:]), (key,'unaccounted source foreground')
    for direction in ('se','sw','ne','nw'):
        hashes=[manifest['poses'][phase+'_'+direction]['rgba_sha256'] for phase in manifest['states']['walk']]
        assert len(set(hashes))==4 # Distinct pixels alone do not prove gait quality.
    print(json.dumps({'source_bytes_preserved':True,'sources':12,'idle_poses':4,'walk_keyposes':16,
        'PNG_pixel_edits':False,'runtime_integrated':False,'native_game_qualified':False}))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--intake',type=Path);parser.add_argument('--preview',action='store_true');parser.add_argument('--normalize-source-scales',action='store_true');args=parser.parse_args()
    manifest=prepare(args.intake) if args.intake else json.loads((QA/'source_manifest.json').read_text(encoding='utf-8'))
    if args.normalize_source_scales:
        for key,(canvas,_) in SPEC.items():
            manifest['sources'][key]['uniform_virtual_canvas']=canvas
            for pose in manifest['poses'].values():
                if pose['source']==key:pose['virtual_canvas']=canvas
        write(QA/'source_manifest.json',manifest)
    verify(manifest)
    if args.intake or args.preview or args.normalize_source_scales:(QA/'candidate_preview.html').write_text(HTML.replace('__MANIFEST__',json.dumps(manifest,ensure_ascii=False)),encoding='utf-8')
if __name__=='__main__':main()
