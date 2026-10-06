"""Geometry-first corrective requests; rejected native outputs remain intact."""
from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
def write(path,value):
    assert not path.exists();path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
failures=[]
for state,reason in [('walk_b_sw','IMAGE-LEFT boot still supports: repeats A instead of required image-right B support.'),
                     ('walk_b_sw2','Second edit still retains image-left support and image-right recovery; opposite B not achieved.'),
                     ('walk_b_nw','Body/head and toes face away-upper-right NE rather than requested away-upper-left NW.')]:
    path=ROOT/f'assets/characters/wu_song_traits_20261006/{state}_v5.png'
    job=HERE/f'jobs/wu_song_{state}_v5.json'
    failures.append({'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'job':job.relative_to(ROOT).as_posix(),'job_sha256':sha(job),'reason':reason})
write(ROOT/'qa/zhu_wounded_20261005/wu_contact_rejections_v5.json',{'scope':'Direct native static-image inspection, no motion qualification','rejected':failures,'production_qualified':False})
common=('Same mature broad muscular Wu Song: upright healthy upper back, head lifted and normal adult proportions, '
        'dark headcloth/tied long hair, charcoal robe with green-gray cloth belt and ragged layers, wooden beads, '
        'brown bracers, dark trousers, pale horizontal shin wraps and dark boots. Exactly one curved steel dao '
        'per hand low near own hip, gently angled out/down; no raised attack. Painterly historical RTS style. '
        'Natural restrained short armed walking contact, neither squat/hunch nor rigid parade/run/kick. '
        'Each leg attaches to own hip, no crossing. Single complete man on genuine transparent RGBA square '
        'PNG<=1536 with80px+ clear margins around head/hands/boots/blades; no background, ground, shadow, '
        'text/grid/colors/extra people or props. Both feet cannot be planted like idle. ')
args={'transparent_background':True,'referenced_image_paths':[
    str(HERE/'guides/qin_ming_walk_b_sw_geometry_v4.png'),
    str(ROOT/'assets/characters/wu_song_traits_20261006/idle_spacing_v4.png')],
    'prompt':('Create a NEW ordinary Wu Song CONTACT B in SW front-three-quarter facing DOWN-LEFT, not a leg-edit '
        'of the previous A. IMAGE1 is the mandatory LEG POSE and camera only: RED leg on IMAGE-RIGHT extends '
        'down to a FLAT support boot, heel and forefoot down; BLUE leg on IMAGE-LEFT bends with boot LOW '
        'raised near upper-left. This exact RIGHT support / LEFT recovery must be visible. Do not copy '
        'robot torso/proportions, colored legs, green floor or labels. IMAGE2 TOP-RIGHT SW man is ONLY '
        'identity/clothes/weapon/adult proportions, never its two-flat idle leg pose. Head, torso, pelvis '
        'and toe directions all DOWN-LEFT. '+common)}
write(HERE/'requests/wu_song_walk_b_sw3_v5.json',args)
args={'transparent_background':True,'referenced_image_paths':[
    str(HERE/'guides/qin_ming_walk_b_nw_geometry_v4.png'),
    str(ROOT/'assets/characters/wu_song_traits_20261006/walk_a_nw_v5.png')],
    'prompt':('Create ordinary Wu Song opposite CONTACT B, keeping the exact NW BACK-LEFT direction of IMAGE2. '
        'Image2 shows the back and a small LEFT-EDGE face profile: face/nose remains on the LEFT of the '
        'head, gaze and both boot toes AWAY-UPPER-LEFT. Never turn head/torso or boots to upper-right NE. '
        'IMAGE1 supplies ONLY new lower legs: RED IMAGE-RIGHT leg is flat planted support heel+forefoot; '
        'BLUE IMAGE-LEFT leg is a low raised recovery boot. This switches Image2 A legs while preserving '
        'its exact face/headcloth/hair/beads/robe/bracers and two low dao. No frontal chest or both eyes. '
        'Do not copy image1 robot anatomy, red/blue/green colors or labels. '+common)}
write(HERE/'requests/wu_song_walk_b_nw2_v5.json',args)
print(json.dumps({'rejected':len(failures),'corrective_requests':2,'submitted':False}))
