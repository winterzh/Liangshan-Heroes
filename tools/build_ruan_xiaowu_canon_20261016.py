"""Bind untouched builtin Ruan Xiaowu native sprites and icons; never paint PNGs.

--prepare creates this versioned batch once. Default verifies source hashes and
exact Godot resources; full native qualification is a separate packed QA gate.
"""
import argparse,json,math,shutil
from pathlib import Path
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/ruan_xiaowu_canon_sources_20261016'
RUNTIME=ROOT/'assets/characters/ruan_xiaowu_canon_20261016'
ICONS=ROOT/'assets/ui/ruan_xiaowu_skills_20261016'
MANIFEST=ROOT/'assets/direction4/ordinary_ruan_xiaowu_canon_20261016.json'
FAMILY='character_traits_v2_ruan_xiaowu_canon'
ALIASES={'hurt_recoil':'hurt_recoil_clear','death_fall':'death_fall_clear'}
SINGLES={'walk_contact_b_nw':'nw','walk_passing_b_nw':'nw','walk_contact_b_ne':'ne','walk_passing_b_ne_clear':'ne'}
def source(key):return RAW/(key+'_native.png')
def pose(key,d):
    if key=='walk_contact_b' and d in ['nw','ne']:return key+'_'+d
    if key=='walk_passing_b' and d=='nw':return key+'_'+d
    if key=='walk_passing_b' and d=='ne':return 'walk_passing_b_ne_clear'
    return ALIASES.get(key,key)
def prepare():
    assert not any(p.exists() for p in [RUNTIME,ICONS,MANIFEST])
    keys={pose(k,d) for phases in base.STATES.values() for k in phases for d in base.DIRS}
    geometry={k:base.geometry(source(k),SINGLES.get(k,False),not k.startswith(('death_fall','death_settle','death_rest'))) for k in keys}
    # All measurements finish before any runtime directory is created.
    RUNTIME.mkdir();ICONS.mkdir();sources={}
    for k in sorted(keys):
        dest=RUNTIME/(k+'.png');shutil.copyfile(source(k),dest);base.shared.import_descriptor(dest)
        sources[k]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':source(k).relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':geometry[k]['size'],'imported_size':geometry[k]['size'],'geometry':geometry[k],'import_dimensions_verified':False}
    portrait=RUNTIME/'portrait.png';shutil.copyfile(source('portrait'),portrait);base.shared.import_descriptor(portrait)
    for s in 'qwer':
        dest=ICONS/('ruan_xiaowu_'+s+'.png');shutil.copyfile(source('ruan_xiaowu_'+s),dest);base.shared.import_descriptor(dest)
    idle=geometry['idle']['cells'];reference=json.loads(base.MANIFEST.read_text(encoding='utf-8'))
    scale={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74)/reference['poses']['idle_'+d]['virtual_canvas_reference'] for d in base.DIRS}
    poses={}
    for phase in dict.fromkeys(k for phases in base.STATES.values() for k in phases):
        for d in base.DIRS:
            k=pose(phase,d);c=geometry[k]['cells'][d];x,y,w,h=c['region']
            intended=math.ceil(reference['poses'][phase+'_'+d]['virtual_canvas_reference']*scale[d])
            px,py=c['measured_pivot'] or idle[d]['measured_pivot']
            if phase in ['death_fall','death_settle','death_rest']:
                ix,iy,_,_=idle[d]['region'];px,py=idle[d]['measured_pivot'];px+=x-ix;py+=y-iy
            if k in SINGLES:intended=math.ceil((py-c['strong_bounds'][1])/.74)
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            poses[phase+'_'+d]={'source':k,'region':c['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched native builtin PNG. Godot AtlasTexture region, virtual transparent margins and uniform scale only; no bitmap writes, crop or mirror.'}
    m={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'ruan_xiaowu','sources':sources,'poses':poses,'states':base.STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in base.STATES for d in base.DIRS],'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'candidate_origin':source('portrait').relative_to(ROOT).as_posix(),'sha256':base.sha(portrait)},'production_qualified':False,'native_dimensions_verified':False,'canon':'120-chapter Water Margin15: powerful hands/large eyes, tilted worn headcloth, temple pomegranate flower, old shirt and one blue-green leopard chest tattoo, bound trousers and striped/checkered waist cloth. Chapter16 merchants carry pu-dao. Right flower side, exact face/beard/colors/shoes/weapon dimensions and game moves are conservative art/game design. Ordinary generic defeat is not novel final fate; hn_ruan_xiaowu merchant body and boat/carry stages remain separate.'}
    base.calibrate_walk_roots(m)
    for name,text in base.renderer().render(m).items():
        p=ROOT/name;assert not p.exists();p.write_bytes(text.encode())
    MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n');return m
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
    m=prepare() if args.prepare else json.loads(MANIFEST.read_text(encoding='utf-8'))
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    for name,text in base.renderer().render(m).items():assert (ROOT/name).read_bytes()==text.encode()
    assert base.sha(ROOT/m['portrait']['path'])==base.sha(source('portrait'))==m['portrait']['sha256']
    for s in 'qwer':assert base.sha(ICONS/('ruan_xiaowu_'+s+'.png'))==base.sha(source('ruan_xiaowu_'+s))
    print(json.dumps({'body_portrait':len(m['sources'])+1,'icons':4,'poses':len(m['poses']),'resources':len(m['resources']),'native_qualified':False}))
if __name__=='__main__':main()
