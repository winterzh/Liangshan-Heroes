"""Measure untouched Zhang Tuanlian native PNGs and bind versioned SpriteFrames.

Pillow/NumPy only read pixels. PNGs are copied byte for byte; Godot samples atlas
regions with transparent margins and uniform display scale. No painting/mirror.
"""
import argparse, hashlib, importlib.util, json, math, shutil, subprocess
from pathlib import Path
import build_shi_en_canon_20261015 as geometry

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/zhang_tuanlian_officer_sources_20261015'
RUNTIME=ROOT/'assets/characters/zhang_tuanlian_officer_20261015'
MANIFEST=ROOT/'assets/direction4/ordinary_zhang_tuanlian_officer_20261015.json'
FAMILY='character_traits_v2_zhang_tuanlian_officer'
DIRS=('se','sw','ne','nw')
STATES={'idle':['idle'],'walk':['walk_contact_a','walk_passing_a','walk_contact_b','walk_passing_b'],
        'attack':['attack_windup','attack_windup','attack_strike','attack_strike','attack_strike','attack_recover','attack_recover','idle'],
        'hurt':['hurt_recoil','hurt_recover'],'death':['death_buckle','death_fall','death_settle','death_rest']}
ALIASES={'walk_contact_a':'walk_contact_a_posefix','walk_passing_a':'walk_passing_a_posefix','walk_passing_b':'walk_passing_b_posefix'}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())

def prepare(revise=False):
    if revise:
        tracked=subprocess.run(['git','ls-files','--error-unmatch','--',MANIFEST.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True)
        assert tracked.returncode!=0 and MANIFEST.exists() and RUNTIME.exists(),'Only uncommitted candidate geometry may be revised'
    else:assert not MANIFEST.exists() and not RUNTIME.exists(),'Never overwrite adopted resources'
    RUNTIME.mkdir(parents=True,exist_ok=revise)
    keys=[ALIASES.get(k,k) for k in dict.fromkeys(p for state in STATES.values() for p in state) if k!='walk_contact_b']
    keys+=['walk_contact_b_posefix','walk_contact_b_nw']
    sources={}
    for key in keys:
        src=SOURCE/(key+'_native.png');dest=RUNTIME/(key+'.png')
        if not revise:shutil.copyfile(src,dest);geometry.import_descriptor(dest)
        assert sha(src)==sha(dest)
        single=key=='walk_contact_b_nw'
        g=geometry.image_geometry(dest,single)
        if single:g['cells']={key[-2:]:g['cells']['nw']}
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest),'candidate_origin':src.relative_to(ROOT).as_posix(),
                      'native_size':g['size'],'imported_size':g['size'],'import_dimensions_verified':False,'geometry':g}
    portrait=RUNTIME/'portrait.png'
    if not revise:shutil.copyfile(SOURCE/'portrait_native.png',portrait);geometry.import_descriptor(portrait)
    assert sha(portrait)==sha(SOURCE/'portrait_native.png')
    idle=sources['idle']['geometry']['cells']
    base={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74) for d in DIRS}
    poses={}
    for pose in dict.fromkeys(k for order in STATES.values() for k in order):
        for direction in DIRS:
            source=('walk_contact_b_nw' if direction=='nw' else 'walk_contact_b_posefix') if pose=='walk_contact_b' else ALIASES.get(pose,pose)
            cell=sources[source]['geometry']['cells'][direction];x,y,w,h=cell['region'];px,py=cell['measured_pivot']
            intended=base[direction]
            if pose in ('death_fall','death_settle','death_rest'):px,py=idle[direction]['measured_pivot']
            elif pose=='walk_contact_b' and direction=='nw':intended=math.ceil((py-cell['strong_bounds'][1])/.74)
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            left=canvas*.5-dx;top=canvas*.82-dy
            assert min(left,top,canvas-w,canvas-h)>=0 and left+w<=canvas+.0001 and top+h<=canvas+.0001
            poses[pose+'_'+direction]={'source':source,'region':cell['region'],'margin':[left,top,canvas-w,canvas-h],
                'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],
                'operations':'Untouched PNG; native atlas sampling, virtual transparent margin, uniform scale. No paint, mirror or re-encode.'}
    manifest={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'zhang_tuanlian','production_qualified':False,
              'sources':sources,'poses':poses,'states':STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for d in DIRS for s in STATES],
              'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'sha256':sha(portrait)},'native_dimensions_verified':False,
              'canon':'120-chapter Water Margin 29–31: military officer, conspiracy, drunken chair resistance in ch31. Ordinary face, soft cap, russet cloth and plain spear are conservative free-game design; no implemented chair/banquet scene or novel death reenactment.',
              'qualification_note':'Authoring-stage expected geometry only; separate actual native adoption receipt required.'}
    write(MANIFEST,manifest)
    spec=importlib.util.spec_from_file_location('zhang_frame_builder',ROOT/'tools/build_directional_spriteframes.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    for name,text in module.render(manifest).items():
        path=ROOT/name;assert revise or not path.exists();path.write_bytes(text.encode())
    return manifest

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--revise-geometry',action='store_true');args=parser.parse_args()
    assert not (args.prepare and args.revise_geometry)
    if args.prepare or args.revise_geometry:manifest=prepare(args.revise_geometry)
    else:
        manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
        spec=importlib.util.spec_from_file_location('zhang_frame_builder',ROOT/'tools/build_directional_spriteframes.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        for name,text in module.render(manifest).items():assert (ROOT/name).read_bytes()==text.encode()
        for row in manifest['sources'].values():assert sha(ROOT/row['path'])==sha(ROOT/row['candidate_origin'])==row['sha256']
    print(json.dumps({'textures':len(manifest['sources'])+1,'poses':len(manifest['poses']),'resources':len(manifest['resources']),'png_pixels_edited':False,'native_qualified':False}))
if __name__=='__main__':main()
