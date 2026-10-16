"""Bind untouched Liu Tang merchant PNGs and corrected ordinary NE gait.

--prepare creates this versioned batch once; default verifies byte sources and
Godot resource text. Native qualification is recorded separately by full PCK QA.
No PNG pixel writes, cropping, resampling, mirroring or native launch occurs.
"""
import argparse,copy,json,math,shutil
from pathlib import Path
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
MERCHANT=ROOT/'assets/characters/liu_tang_merchant_20261016'
RAW=ROOT/'assets/characters/liu_tang_merchant_sources_20261016'
ORDINARY=ROOT/'assets/characters/liu_tang_ne_hold_20261016'
ORDINARY_RAW=ROOT/'assets/characters/liu_tang_ne_hold_sources_20261016'
MM=ROOT/'assets/direction4/level1_liu_tang_merchant_20261016.json'
OM=ROOT/'assets/direction4/ordinary_liu_tang_ne_hold_20261016.json'
MF='character_traits_v2_liu_tang_merchant'
OF='character_traits_v2_liu_tang_ne_hold'
MAP={'idle':'idle_posematch','attack_windup':'attack_windup_alpha_clear','walk_contact_b':'walk_contact_b_atlas','walk_contact_b_nw_final':'walk_contact_b_nw_waist','walk_passing_b_opposite':'walk_passing_b_atlas','walk_passing_b_ne_canon':'walk_passing_b_ne_waist','hurt_recoil_clear':'hurt_recoil','death_fall_clear':'death_fall_waist_clear','death_settle_directions':'death_settle_waist_clear','death_rest_directions':'death_rest_waist_clear','death_buckle':'death_buckle_waist_clear'}

def resources(family):return [f'assets/anim/{family}_{s}_{d}.tres' for s in base.STATES for d in base.DIRS]
def json_write(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def bind_source(src,dest,geo):
    assert not dest.exists();shutil.copyfile(src,dest);base.shared.import_descriptor(dest)
    return {'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':geo['size'],'imported_size':geo['size'],'geometry':geo,'import_dimensions_verified':False}
def pose(source,cell,intended,pivot=None):
    x,y,w,h=cell['region'];px,py=pivot or cell['measured_pivot'];dx,dy=px-x,py-y
    canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
    return {'source':source,'region':cell['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched builtin native PNG; Godot atlas sampling, transparent virtual margins and uniform scale only. No bitmap writes or mirror.'}
def prepare():
    assert not any(p.exists() for p in [MERCHANT,ORDINARY,MM,OM])
    old=json.loads(base.MANIFEST.read_text(encoding='utf-8'))
    # Measure the entire batch before creating runtime directories.
    keys={MAP.get(k,k) for k in old['sources']}
    measured={k:base.geometry(RAW/(k+'_native.png'),'nw' if k=='walk_contact_b_nw_waist' else 'ne' if k=='walk_passing_b_ne_waist' else False,not k.startswith(('death_fall','death_settle','death_rest'))) for k in keys}
    ordinary_geo={k:base.geometry(ORDINARY_RAW/(k+'_native.png'),'ne') for k in ['passing_a_ne','passing_b_ne']}
    ORDINARY.mkdir();ordinary=copy.deepcopy(old);ordinary.update(character=OF,resources=resources(OF),production_qualified=False,native_dimensions_verified=False)
    for key,phase in [('passing_a_ne','walk_passing_a'),('passing_b_ne','walk_passing_b')]:
        ordinary['sources'][key]=bind_source(ORDINARY_RAW/(key+'_native.png'),ORDINARY/(key+'.png'),ordinary_geo[key])
        c=ordinary_geo[key]['cells']['ne'];intended=math.ceil((c['measured_pivot'][1]-c['strong_bounds'][1])/.74)
        ordinary['poses'][phase+'_ne']=pose(key,c,intended)
    used={p['source'] for p in ordinary['poses'].values()};ordinary['sources']={k:v for k,v in ordinary['sources'].items() if k in used}
    base.calibrate_walk_roots(ordinary)
    ordinary['canon']+=' Ordinary NE low-held pu-dao now stays image-right in all four gait phases, matching idle; hand choice is animation design, not an original-text claim. Other poses and PNGs preserved.'
    MERCHANT.mkdir();sources={}
    for key in sorted(keys):sources[key]=bind_source(RAW/(key+'_native.png'),MERCHANT/(key+'.png'),measured[key])
    portrait=MERCHANT/'portrait.png';shutil.copyfile(RAW/'portrait_native.png',portrait);base.shared.import_descriptor(portrait)
    idle=sources['idle_posematch']['geometry']['cells'];scale={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74)/old['poses']['idle_'+d]['virtual_canvas_reference'] for d in base.DIRS}
    poses={}
    for name,previous in old['poses'].items():
        phase,d=name.rsplit('_',1);key=MAP.get(previous['source'],previous['source']);c=sources[key]['geometry']['cells'][d]
        intended=math.ceil(previous['virtual_canvas_reference']*scale[d]);pivot=None
        if phase in ['death_fall','death_settle','death_rest']:
            ix,iy,_,_=idle[d]['region'];x,y,_,_=c['region'];px,py=idle[d]['measured_pivot'];pivot=[x+px-ix,y+py-iy]
        if key in ['walk_contact_b_nw_waist','walk_passing_b_ne_waist']:intended=math.ceil((c['measured_pivot'][1]-c['strong_bounds'][1])/.74)
        poses[name]=pose(key,c,intended,pivot)
    merchant={'schema':old['schema'],'character':MF,'body_owner':'liu_tang','sources':sources,'poses':poses,'states':base.STATES,'resources':resources(MF),'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'candidate_origin':(RAW/'portrait_native.png').relative_to(ROOT).as_posix(),'sha256':base.sha(portrait)},'production_qualified':False,'native_dimensions_verified':False,'canon':'120-chapter Water Margin14: broad purplish-dark face, temple cinnabar birthmark with black/yellow hair and actual pu-dao combat. Chapter16: seven merchants strip to rest; Liu Tang first takes his pu-dao. Bare upper body only in explicit hn_liu_tang stage. Right temple, exact scarf/beard/trousers/shoes, hand choice, weapon dimensions and authored optional gameplay defeat are conservative art/game design, not new novel facts. No new plot or final fate.'}
    base.calibrate_walk_roots(merchant)
    for path,m in [(OM,ordinary),(MM,merchant)]:
        rendered=base.renderer().render(m)
        for name,text in rendered.items():
            dest=ROOT/name;assert not dest.exists();dest.write_bytes(text.encode())
        json_write(path,m)
    return ordinary,merchant
def verify(m):
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    for name,text in base.renderer().render(m).items():assert (ROOT/name).read_bytes()==text.encode()
    assert base.sha(ROOT/m['portrait']['path'])==base.sha(ROOT/m['portrait']['candidate_origin'])==m['portrait']['sha256']
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
    rows=prepare() if args.prepare else tuple(json.loads(p.read_text(encoding='utf-8')) for p in [OM,MM])
    for m in rows:verify(m)
    print(json.dumps({'manifests':2,'resources':sum(len(m['resources']) for m in rows),'poses':sum(len(m['poses']) for m in rows),'merchant_body_portrait':len(rows[1]['sources'])+1,'ordinary_new_png':2,'native_qualified':False}))
if __name__=='__main__':main()
