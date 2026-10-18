"""Source-layer composition QA only; no edits to painted PNGs, no Godot admission."""
from pathlib import Path
import cmath,hashlib,html,json,math,shutil,subprocess,time,sys
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];model_mode=len(sys.argv)>1 and sys.argv[1]=='--model'
if model_mode:
    model_path=Path(sys.argv[2]);B=json.loads(model_path.read_text(encoding='utf-8'));D=B['inputs'];candidate=B['candidate'];E=Path(sys.argv[3]);detail=len(sys.argv)>4 and sys.argv[4]=='detail';binding_path=model_path
    assert E.is_absolute() and not E.resolve().is_relative_to(R.resolve())
else:
    candidate=sys.argv[1] if len(sys.argv)>1 else 'rig_v2';assert candidate in ['rig_v2','rig_v3'];binding_path=Q/candidate/'prepared_binding.json'
    B=json.loads(binding_path.read_text());P=Path(B['project']);D=B['inputs'];detail=len(sys.argv)>2 and sys.argv[2]=='detail'
    E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019')/('browser_'+candidate+('_detail' if detail else ''))
(E/'images').mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for key,row in D['textures'].items():
    src=R/row['canonical_source'] if model_mode else P/row['file'];assert sha(src)==row['sha256'];shutil.copyfile(src,E/'images'/f'{key}.png')
def z(a):return complex(*a)
def dot(a,b):return (a*b.conjugate()).real
def arr(a):return [a.real,a.imag]
def xy(a):return f'{a.real:.5f},{a.imag:.5f}'
def plane(poly,at,n):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da,db=dot(a-at,n),dot(b-at,n)
        if da>=0:out.append(a)
        if (da>=0)!=(db>=0):out.append(a+(b-a)*da/(da-db))
    return out
def compose(t):
    defs=''.join(f'<image id="tex_{key}" href="images/{key}.png" width="1254" height="1254"/>' for key in D['textures']);parts=[];clip_id=0
    def place(key,d,at,source_at,mx,my=None,clip=None,tint=False):
        nonlocal defs,clip_id
        if my is None:my=1j*mx
        offset=at-source_at.real*mx-source_at.imag*my
        clip_attr=''
        if clip:
            poly=plane([offset,offset+627*mx,offset+627*(mx+my),offset+627*my],*clip)
            if len(poly)<3:return
            clip_id+=1;defs+=f'<clipPath id="c{clip_id}"><polygon points="'+ ' '.join(xy(p) for p in poly)+'"/></clipPath>';clip_attr=f' clip-path="url(#c{clip_id})"'
        cellx,celly=d%2*627,d//2*627
        matrix=f'{mx.real:.7f} {mx.imag:.7f} {my.real:.7f} {my.imag:.7f} {offset.real:.7f} {offset.imag:.7f}'
        parts.append(f'<g{clip_attr}><g transform="matrix({matrix})"'+(' opacity=".79"' if tint else '')+f'><svg width="627" height="627" viewBox="{cellx} {celly} 627 627" overflow="hidden"><use href="#tex_{key}"/></svg></g></g>')
    def link(key,d,a,b,anchors,width=1,tint=False):
        s0,s1=map(z,anchors);su=(s1-s0)/abs(s1-s0);sn=1j*su;du=(b-a)/abs(b-a);dn=1j*du;factor=abs(b-a)/abs(s1-s0)
        place(key,d,a,s0,factor*(du*su.real+dn*sn.real*width),factor*(du*su.imag+dn*sn.imag*width),tint=tint)
    def horse(d):
        row=D['views'][d];sgn=1 if d%2==0 else -1;axis=complex(.866*sgn,.5 if d<2 else -.5);axis/=abs(axis);legs=[]
        for i in range(4):
            fore=i<2;near=i%2==0;side=row['near_side'] if near else ('L' if row['near_side']=='R' else 'R');identity=side+('F' if fore else 'H');p=0 if identity in ['LF','RH'] else .5
            support=p<.46;travel=48*(.5-p/.46) if support else 48*(-.5+(p-.46)/.54);lift=0 if support else math.sin((p-.46)/.54*math.pi)*38
            root=z(row['fore_root'] if fore else row['hind_root'])+(0 if near else complex(sgn*24,-12));rest=complex(root.real+sgn*(12 if fore else -15),row['floor_y']-(0 if near else 18));foot=rest+axis*travel-1j*lift;root+=2j
            h=D['hoof_anchors'][d];sole=(z(h['left'])+z(h['right']))/2;angle=0 if support else sgn*.22*math.sin((p-.46)/.54*math.pi);rot=angle-cmath.phase(z(h['right'])-z(h['left']));ankle=foot+(z(h['attach'])-sole)*cmath.exp(1j*rot)*D['hoof_scale']
            upper,lower=(120 if fore else 130),95;delta=ankle-root;length=abs(delta);u=delta/length;along=(upper**2-lower**2+length**2)/(2*length);height=math.sqrt(max(0,upper**2-along**2));joint=root+u*along+1j*u*height*(-sgn if fore else sgn)
            legs.append((fore,near,root,joint,ankle,foot,sole,rot))
        place('tail',d,2j,0j,1)
        for i in [1,3,0,2]:
            fore,near,root,joint,ankle,foot,sole,rot=legs[i];prefix='fore' if fore else 'hind';place('hoof',d,foot,sole,D['hoof_scale']*cmath.exp(1j*rot),tint=not near);link(prefix+'_lower',d,joint,ankle,D['anchors'][prefix+'_lower'][d],tint=not near);link(prefix+'_upper',d,root,joint,D['anchors'][prefix+'_upper'][d],tint=not near)
        place('body',d,2j,0j,1)
    for d,row in enumerate(D['arm_views']):
        clock=t/0.8%11;idx=int(clock);u=clock-idx;u=u*u*(3-2*u);a,b=row['keys'][idx],row['keys'][(idx+1)%11];guard=z(a['guard'])*(1-u)+z(b['guard'])*u
        diff=(b['angle']-a['angle']+math.pi)%(2*math.pi)-math.pi;angle=a['angle']+diff*u;sw=row['sword'];srcg=z(sw['guard']);srct=z(sw['tip']);factor=D['blade_length']/abs(srct-srcg);rot=angle-cmath.phase(srct-srcg);grip=guard+(z(sw['grip'])-srcg)*cmath.exp(1j*rot)*factor;palm=grip
        if idx==0:palm=z(row['rest_hand'])*(1-u)**2+z(row['hand_approach_control'])*2*(1-u)*u+grip*u*u if 'hand_approach_control' in row else z(row['rest_hand'])*(1-u)+grip*u
        elif idx==9:palm=grip*(1-u)**2+z(row['hand_approach_control'])*2*(1-u)*u+z(row['rest_hand'])*u*u if 'hand_approach_control' in row else grip*(1-u)+z(row['rest_hand'])*u
        elif idx==10:palm=z(row['rest_hand'])
        hand_angle=angle+math.pi/2;h=row['hand'];wrist=palm-(z(h['grip'])-z(h['wrist']))*cmath.exp(1j*hand_angle)*D['hand_scale'];root=z(row['shoulder']);delta=wrist-root;distance=abs(delta);direction=delta/distance;along=(D['upper_length']**2-D['fore_length']**2+distance**2)/(2*distance);height=math.sqrt(max(0,D['upper_length']**2-along**2));elbow=root+direction*along+1j*direction*height*(1 if d%2==0 else -1)
        for debug in [False,True]:
            panel=complex(d%2*1280,d//2*650);origin=panel+complex(55 if not debug else 690,140)
            parts.append(f'<text x="{panel.real+20}" y="{panel.imag+32}" fill="white" font-size="24">{row["direction"].upper()} / browser source QA / {html.escape(a["label"])} / t={t}</text>' if not debug else '')
            parts.append(f'<g transform="translate({origin.real} {origin.imag}) scale(.7)">');horse(d)
            shift=2j;offset=z(row['waist_target'])-z(row['body_waist'])*D['torso_scale']+shift;place('torso',d,offset,0j,D['torso_scale'])
            clip=(z(row['mouth'])+shift,z(row['out'])) if idx in [0,1,2,7,8,9,10] else None
            place('sword',d,guard+shift,srcg,factor*cmath.exp(1j*rot),clip=clip)
            sc=row['scabbard'];source_axis=z(sc['tip'])-z(sc['mouth']);place('scabbard',d,z(row['mouth'])+shift,z(sc['mouth']),D['scabbard_length']/abs(source_axis)*cmath.exp(1j*(cmath.phase(-z(row['out']))-cmath.phase(source_axis))))
            link('upper_arm',d,root+shift,elbow+shift,row['upper_arm'],.60);link('forearm',d,elbow+shift,wrist+shift,row['forearm'],.67);place('hand',d,palm+shift,z(h['grip']),D['hand_scale']*cmath.exp(1j*hand_angle))
            if debug:
                parts.append(f'<polyline points="{xy(root+shift)} {xy(elbow+shift)} {xy(wrist+shift)}" fill="none" stroke="#9cdbc9" stroke-width="2"/>')
                for p in [z(row['mouth']),grip,guard+(srct-srcg)*factor*cmath.exp(1j*rot)]:parts.append(f'<circle cx="{p.real}" cy="{p.imag+2}" r="3" fill="#edbc82"/>')
            parts.append('</g>')
    return '<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440"><rect width="2560" height="1440" fill="#292923"/><defs>'+defs+'</defs>'+''.join(parts)+'<text x="20" y="1360" fill="white" font-size="24">Browser source-layer geometry mirror only: static horse, no reins, no native/Unit/animation acceptance.</text></svg>'
shutil.copyfile(Path(__file__),E/'renderer_executed.py')
receipt={'scope':'Own isolated headless browser SVG source-layer composition QA; static horse, no reins; not native, Unit, continuous animation or production art. Original painted PNGs unchanged.','renderer_sha256':sha(E/'renderer_executed.py'),'source_binding_sha256':sha(binding_path),'standalone_model_mode':model_mode,'source_images':[{'file':f'images/{key}.png','sha256':sha(E/'images'/f'{key}.png')} for key in D['textures']],'steps':[]}
browser=Path('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
samples=[('approach',.4),('sweep',2.8),('release',7.6)] if detail else [('idle',0),('clear',2.4),('point',4.0)]
for label,t in samples:
    svg=E/(label+'.svg');svg.write_text(compose(t),encoding='utf-8');out=E/(label+'.png');cmd=[str(browser),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--window-size=2560,1440','--virtual-time-budget=2000','--user-data-dir='+str(E/('profile_'+label)),'--screenshot='+str(out),svg.as_uri()]
    with (E/(label+'.stdout.log')).open('xb') as stdout,(E/(label+'.stderr.log')).open('xb') as stderr:
        child=subprocess.Popen(cmd,stdout=stdout,stderr=stderr);code=child.wait(timeout=45)
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        if out.exists() and out.stat().st_size>100000:
            try:
                with Image.open(out) as im:im.verify()
                break
            except (OSError,SyntaxError):pass
        time.sleep(.2)
    assert out.exists() and out.stat().st_size>100000
    receipt['steps'].append({'label':label,'command':cmd,'pid':child.pid,'exit_code':code,'svg_sha256':sha(svg),'png_sha256':sha(out)})
with (E/'receipt.json').open('x',encoding='utf-8') as f:f.write(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'captures':3,'folder':str(E),'native':False}))
