"""Four static browser poses of a two-leg rig; no native/continuous gait acceptance."""
from pathlib import Path
import hashlib,json,math,shutil,subprocess,sys,time
from PIL import Image
Q=Path(__file__).resolve().parent
E=Path(sys.argv[1]).resolve()
assert E.is_relative_to(Path('D:/CodexEvidence/shuihu/yang_lin_leg_rig_sources_20261019').resolve())
assert not E.exists();(E/'images').mkdir(parents=True)
binding=json.loads((Q/'preview_sources_v2.json').read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
source_map={r['key'].split('_v')[0]:r for r in binding['sources']}
for kind,source in source_map.items():
    path=Q/source['source'];assert sha(path)==source['sha256']
    shutil.copyfile(path,E/'images'/(kind+'.png'))
def add(a,b):return [a[0]+b[0],a[1]+b[1]]
def sub(a,b):return [a[0]-b[0],a[1]-b[1]]
def mul(a,s):return [a[0]*s,a[1]*s]
def length(a):return math.hypot(*a)
directions=['se','sw','ne','nw']
forward={'se':[math.sqrt(3)/2,.5],'sw':[-math.sqrt(3)/2,.5],
         'ne':[math.sqrt(3)/2,-.5],'nw':[-math.sqrt(3)/2,-.5]}
side={'se':[-math.sqrt(3)/2,.5],'sw':[-math.sqrt(3)/2,-.5],
      'ne':[math.sqrt(3)/2,.5],'nw':[math.sqrt(3)/2,-.5]}
torso_hip={'se':[334,455],'sw':[936,455],'ne':[340,1065],'nw':[935,1065]}
thigh_joints={'right':{'se':[[175,166],[145,546]],'sw':[[475,168],[479,548]],'ne':[[792,166],[789,546]],'nw':[[1097,167],[1092,551]]},
              'left':{'se':[[160,739],[165,1107]],'sw':[[473,736],[475,1110]],'ne':[[795,739],[793,1110]],'nw':[[1097,739],[1094,1109]]}}
shin_joints={'right':{'se':[[179,153],[179,548]],'sw':[[484,154],[486,546]],'ne':[[790,153],[790,545]],'nw':[[1095,153],[1096,546]]},
             'left':{'se':[[177,715],[178,1103]],'sw':[[480,713],[480,1104]],'ne':[[788,710],[788,1103]],'nw':[[1093,713],[1094,1103]]}}
boot_points={'right':{'se':{'ankle':[144,377],'sole':[167,475]},'sw':{'ankle':[510,377],'sole':[475,470]},'ne':{'ankle':[774,396],'sole':[805,446]},'nw':{'ankle':[1102,395],'sole':[1070.5,447.5]}},
             'left':{'se':{'ankle':[146,918],'sole':[167.5,1010.5]},'sw':{'ankle':[510,920],'sole':[478,1009.5]},'ne':{'ankle':[775,946],'sole':[805,994.5]},'nw':{'ankle':[1101,947],'sole':[1073.5,996]}}}
def region(kind,direction,leg=None):
    return next(r['region'] for r in source_map[kind]['regions'] if r['direction']==direction and r['leg']==leg)
def matrix_segment(s,e,a,b):
    sv=sub(e,s);dv=sub(b,a);scale=length(dv)/length(sv)
    angle=math.atan2(dv[1],dv[0])-math.atan2(sv[1],sv[0]);co=math.cos(angle)*scale;si=math.sin(angle)*scale
    return [co,si,-si,co,a[0]-co*s[0]+si*s[1],a[1]-si*s[0]-co*s[1]]
def image_markup(kind,rect,matrix,clip_id):
    x,y,w,h=rect;a,b,c,d,tx,ty=matrix
    return (f'<defs><clipPath id="{clip_id}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath></defs>'
            f'<g transform="matrix({a} {b} {c} {d} {tx} {ty})"><image href="images/{kind}.png" width="1254" height="1254" clip-path="url(#{clip_id})"/></g>')
def inverse_knee(hip,ankle,direction):
    v=sub(ankle,hip);d=length(v);assert 1<d<199.9,(direction,d)
    mid=mul(v,.5);n=[-v[1]/d,v[0]/d]
    sign=1 if n[0]*forward[direction][0]+n[1]*forward[direction][1]>=0 else -1
    return add(add(hip,mid),mul(n,sign*math.sqrt(10000-(d/2)**2)))
def pose(direction,phase):
    base=[313.5,430];bob=-abs(math.sin(2*math.pi*phase))*5
    center=add(base,[0,bob]);legs=[]
    for leg,offset in [('right',0),('left',.5)]:
        u=(phase+offset)%1
        if u<.6:
            stride=30-60*u/.6;lift=0;state='stance'
        else:
            t=(u-.6)/.4;stride=-30+60*t;lift=math.sin(math.pi*t)*35;state='swing'
        sign=1 if leg=='right' else -1
        hip=add(center,mul(side[direction],sign*17))
        sole=add(add(add(base,[0,195-lift]),mul(side[direction],sign*20)),mul(forward[direction],stride))
        bp=boot_points[leg][direction];ankle=sub(sole,mul(sub(bp['sole'],bp['ankle']),.28))
        knee=inverse_knee(hip,ankle,direction)
        legs.append({'leg':leg,'phase':u,'state':state,'hip':hip,'knee':knee,'ankle':ankle,'sole':sole,
                     'thigh_length':length(sub(knee,hip)),'shin_length':length(sub(ankle,knee))})
    return {'direction':direction,'phase':phase,'center':center,'legs':legs}
def render_pose(data,prefix):
    direction=data['direction'];center=data['center'];delta=sub(center,torso_hip[direction])
    matrix=[1,0,0,1,*delta];torso_region=region('torso',direction)
    parts=[]
    if direction in ['ne','nw']:
        x,y,w,h=torso_region;split=1150
        if y+h>split:parts.append(image_markup('torso',[x,split,w,y+h-split],matrix,prefix+'weapon_back'))
    for item in sorted(data['legs'],key=lambda r:r['sole'][1]):
        leg=item['leg'];tag=prefix+leg
        t1,t2=thigh_joints[leg][direction];s1,s2=shin_joints[leg][direction]
        parts.append(image_markup('thighs',region('thighs',direction,leg),matrix_segment(t1,t2,item['hip'],item['knee']),tag+'thigh'))
        parts.append(image_markup('shins',region('shins',direction,leg),matrix_segment(s1,s2,item['knee'],item['ankle']),tag+'shin'))
        bp=boot_points[leg][direction];translation=sub(item['ankle'],mul(bp['ankle'],.28))
        parts.append(image_markup('boots',region('boots',direction,leg),[.28,0,0,.28,*translation],tag+'boot'))
    if direction in ['ne','nw']:
        x,y,w,h=torso_region;torso_region=[x,y,w,min(y+h,1150)-y]
    parts.append(image_markup('torso',torso_region,matrix,prefix+'torso'))
    for item in data['legs']:
        px,py=item['sole'];color='#E4BC55' if item['leg']=='right' else '#6BC7D0'
        parts.append(f'<circle cx="{px}" cy="{py}" r="3.5" fill="{color}"/>')
    return ''.join(parts)
sample_checks=[]
for i in range(16):
    for direction in directions:
        data=pose(direction,i/16)
        for leg in data['legs']:
            assert abs(leg['thigh_length']-100)<1e-9 and abs(leg['shin_length']-100)<1e-9
            sample_checks.append({'direction':direction,'phase':i/16,'leg':leg['leg'],'state':leg['state'],
                                  'hip_to_ankle':length(sub(leg['ankle'],leg['hip']))})
frames=[]
for index,phase in enumerate([0,.25,.5,.75]):
    frame={'index':index,'phase':phase,'poses':[pose(direction,phase) for direction in directions]}
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1700" height="900"><rect width="1700" height="900" fill="#171916"/><g fill="#F0E8D8" font-family="Microsoft YaHei,sans-serif">',
           f'<text x="25" y="40" font-size="28">杨林双腿分层首轮 · 相位 {phase:.2f} · 浏览器静态骨架候选，非游戏画面</text>']
    for i,data in enumerate(frame['poses']):
        x=25+i*420
        parts += [f'<text x="{x}" y="90" font-size="25">{data["direction"].upper()}</text>',
                  f'<rect x="{x}" y="110" width="400" height="530" fill="#38413B"/>',
                  f'<svg x="{x}" y="110" width="400" height="530" viewBox="0 0 627 800" overflow="hidden">',
                  render_pose(data,f'f{index}d{i}'),'</svg>']
    parts += ['<text x="25" y="700" font-size="23">黄点：右腿靴底参照；青点：左腿。上身固定比例，两腿相差半周期；只做静态相位比较。</text>',
              '<text x="25" y="745" font-size="23">髋/膝/踝与靴底点为人工配准，非物理接触；原PNG不改像素，透明边缘杂点仍未通过。</text>',
              '<text x="25" y="790" font-size="23">来源部件/关节接缝/比例/遮挡仍需目检；不等于连续自然步态、原生Unit、动作链或包内验收。</text>',
              '<text x="25" y="835" font-size="23">原著第44回只据人形/浑铁笔管枪；分层与步态是美术实现，不新增剧情或武器。</text></g></svg>']
    svg=E/f'phase_{index:02d}.svg';svg.write_text(''.join(parts),encoding='utf-8')
    frame['svg']=svg.name;frames.append(frame)
with (E/'model.json').open('x',encoding='utf-8') as stream:
    stream.write(json.dumps({'sources':binding,'torso_hip':torso_hip,'thigh_joints':thigh_joints,'shin_joints':shin_joints,
                'boot_points':boot_points,'thigh_length':100,'shin_length':100,'boot_scale':.28,
                'manual_uncertainty_source_pixels':15,'sample_checks':sample_checks,'frames':frames,
                'scope':'Static source rig only; alpha source qualification and full/native gait remain unaccepted.'},ensure_ascii=False,indent=2)+'\n')
browser='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';receipts=[]
for frame in frames:
    index=frame['index'];svg=E/frame['svg'];out=E/f'phase_{index:02d}.png'
    command=[browser,'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars',
             '--force-device-scale-factor=1','--window-size=1700,900','--virtual-time-budget=2000',
             '--user-data-dir='+str(E/f'profile_{index:02d}'),'--screenshot='+str(out),svg.as_uri()]
    with (E/f'phase_{index:02d}_stdout.log').open('xb') as stdout,(E/f'phase_{index:02d}_stderr.log').open('xb') as stderr:
        child=subprocess.Popen(command,stdout=stdout,stderr=stderr);code=child.wait(timeout=45)
    assert code==0
    deadline=time.monotonic()+30
    while time.monotonic()<deadline and not out.exists():time.sleep(.2)
    with Image.open(out) as im:assert im.size==(1700,900)
    receipts.append({'phase':frame['phase'],'command':command,'pid':child.pid,'exit_code':code,
                     'svg_sha256':sha(svg),'png_sha256':sha(out)})
archive=Q/'browser_rig_v1';archive.mkdir()
for path in E.iterdir():
    if path.is_file():shutil.copyfile(path,archive/path.name)
with (archive/'receipt.json').open('x',encoding='utf-8') as stream:
    stream.write(json.dumps({'scope':'Four static browser poses, not continuous animation or native qualification.',
                'executed_helper_sha256':sha(Path(__file__)),'binding_sha256':sha(Q/'preview_sources_v2.json'),
                'frames':receipts,'geometric_samples':len(sample_checks),'fixed_thigh_shin_lengths':[100,100],
                'production_adopted':False,'native_accepted':False,'visual_accepted':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'frames':len(receipts),'geometric_leg_samples':len(sample_checks),'archive':str(archive),
                  'production_adopted':False,'native_accepted':False}))
