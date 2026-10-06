"""Derive real original-actor counterhit QA for the corrected standing Lin SW hurt."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'qa/zhu_wounded_20261005/harness'
def once(text,old,new):assert text.count(old)==1,old[:100];return text.replace(old,new)

def main():
    gd=(HERE/'ordinary_chapter_combat_production_v7.gd').read_text(encoding='utf-8')
    gd=gd.replace('ordinary_chapter_combat_production_v7','ordinary_hurt_pilot_v13')
    gd=gd.replace('ordinary_preintegration_query_baselines.json','ordinary_predeath_query_baselines.json')
    gd=once(gd,'old_poses=row.baseline','old_poses=row.current')
    needle='\t\t\t\telse:\n\t\t\t\t\tcheck(poses==old_poses,"existing action untouched "+key+" "+state+" "+direction)'
    gd=once(gd,needle,'''				elif key=="lin_chong" and state=="hurt" and direction=="sw":
					check(proposed.size()==1,"corrected Lin SW living hurt single standing pose")
					check(_texture_source(proposed[0]).ends_with("death_sw2_v10.png") and art.unit_anim_uses_directional_source(key,state,direction),"corrected Lin SW living hurt source/direction")
					check(proposed[0] is AtlasTexture and proposed[0].has_meta("draw_scale"),"corrected standing hurt anatomy metadata")
				else:
					check(poses==old_poses,"qualified other action untouched "+key+" "+state+" "+direction)''')
    py=(HERE/'run_ordinary_death_pilot_v10a.py').read_text(encoding='utf-8')
    py=py.replace('ordinary_death_pilot_v10a','ordinary_hurt_pilot_v13')
    py=once(py,"assert set(pilot['results'])=={'skills_'+str(i) for i in range(8)}|{'death'}\n    assert all(row['passed'] and row['engine_time_scale']==1.0 for row in pilot['results'].values())",
            "assert pilot['result']['passed'] and pilot['result']['checks']==346 and len(pilot['result']['screenshots'])==32")
    py=once(py,"assert not review['passed'] and review['wu_death_sampled_qualified'] and not review['lin_sw_death_qualified'] and review['skills_mechanical_passed']",
            "assert review['passed'] and review['death_qualified']")
    py=py.replace('ordinary_lin_chong_20261007_death_v10.json','ordinary_lin_chong_20261007_hurt_v12.json')
    py=once(py,"len(manifest['poses'])==4","len(manifest['poses'])==1")
    old="""    prior_path=Path(pilot['prior_receipt']);prior=read(prior_path)
    assert sha(prior_path)==pilot['prior_receipt_sha256'] and prior['complete']
    baseline=prior['result']['resources'];assert len(baseline)==48"""
    py=once(py,old,"    baseline=pilot['result']['resources'];assert len(baseline)==48")
    py=once(py,".replace(lin,lin+', \"death\": \"character_traits_v10_lin_chong_death\"')",
            ".replace(lin,lin+', \"death\": \"character_traits_v10_lin_chong_death\", \"hurt\": \"character_traits_v12_lin_chong_hurt\"')")
    py=py.replace('len(result[\'screenshots\'])==32','len(result[\'screenshots\'])==48')
    py=py.replace('candidate_death_routes_verified=True','candidate_hurt_routes_verified=True')
    scope='Private ArtDB death lookups retained from qualified v10a plus corrected standing Lin SW hurt; other scripts copied unchanged. Original Lin/Zhu and Wu/Daming actors, actual orders/melee/counterhit phases and HUD/portraits with legal original stats. Contact placement, frozen nonparticipants, fog/zoom and exact physics-phase freezes are fixtures. Other ordinary/death and explicit story resource routes guarded. No Unit/HP/damage/timing/ability edits. Not death replay here, continuous animation/full chapter/save/performance/export/platform qualification.'
    py,n=re.subn(r"             'scope':'.*'}", "             'scope':'"+scope+"'}",py);assert n==1
    py=py.replace('Wu ordinary death and Lin death family lookup only; Lin three other resources exact unchanged aliases. No gameplay patches.',
                  'Qualified Wu/Lin death lookups plus corrected Lin hurt lookup; other three Lin hurt resources exact aliases. No gameplay patches.')
    py=py.replace('Pilot Wu death and corrected Lin southwest death; verify actual shadow release.',
                  'Original actor normal melee/counterhit pilot for corrected Lin southwest standing hurt.')
    for name,text in [('ordinary_hurt_pilot_v13.gd',gd),('run_ordinary_hurt_pilot_v13.py',py)]:
        p=HERE/name;assert not p.exists();p.write_bytes(text.encode('utf-8'))
    print('Prepared original-actor hurt/counterhit sibling; qualification pending.')

if __name__=='__main__':main()
